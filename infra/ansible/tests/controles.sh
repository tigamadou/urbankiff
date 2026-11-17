#!/bin/sh
# Contrôles statiques de `make infra-lint`, lancés dans le conteneur Ansible (dossier infra/ansible).
set -u
echec=0
verifier() { # fichier motif
    grep -q -- "$2" "$1" || { echo "ECHEC $1 : '$2' absent"; echec=1; }
}

gabarit=roles/k3s/templates/config-serveur.yaml.j2
if [ -f "$gabarit" ]; then
    verifier "$gabarit" '^secrets-encryption: true$'
    verifier "$gabarit" '^flannel-backend: wireguard-native$'
    verifier "$gabarit" '^write-kubeconfig-mode: "0600"$'
    verifier "$gabarit" '^  - nodeport-addresses=127.0.0.0/8$'
else
    echo "ECHEC $gabarit absent"; echec=1
fi
grep -q -- '^  - nodeport-addresses=127.0.0.0/8$' roles/k3s/templates/config-agent.yaml.j2 \
    || { echo "ECHEC config-agent.yaml.j2 : nodeport-addresses absent"; echec=1; }

# Manifestes vendus : versions de group_vars/all.yml et sommes SHA-256
version() { sed -n "s/^$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *\$/\1/p" group_vars/all.yml; }
files=roles/plateforme/files
for couple in "cert-manager-$(version cert_manager_version).yaml" "cloudnative-pg-$(version cnpg_version).yaml" "plugin-barman-cloud-$(version barman_plugin_version).yaml"; do
    [ -s "$files/$couple" ] || { echo "ECHEC $files/$couple absent (make infra-vendre)"; echec=1; }
    grep -q " $couple\$" "$files/SHA256SUMS" 2>/dev/null || { echo "ECHEC $couple absent de SHA256SUMS"; echec=1; }
done
(cd "$files" && sha256sum -c SHA256SUMS >/dev/null) || { echo "ECHEC sommes SHA-256 des manifestes"; echec=1; }
[ "$(ls "$files"/*.yaml | wc -l)" -eq 3 ] || { echo "ECHEC fichiers de versions anciennes dans $files"; echec=1; }

# Role du compte deploy : helm --wait lit les ReplicaSets des Deployments
grep -q 'resources: \[replicasets\]' roles/deploiement/defaults/main.yml \
    || { echo "ECHEC roles/deploiement/defaults/main.yml : lecture des replicasets absente"; echec=1; }

# Role du compte deploy : middlewares Traefik du chart urbankiff-donnees, jamais pods/exec
defaults=roles/deploiement/defaults/main.yml
grep -A2 'apiGroups: \[traefik.io\]' "$defaults" | grep -q 'resources: \[middlewares\]' \
    && grep -A2 'apiGroups: \[traefik.io\]' "$defaults" | grep -q 'verbs: "{{ deploiement_verbes_ecriture }}"' \
    || { echo "ECHEC $defaults : règle traefik.io middlewares en écriture absente"; echec=1; }
if grep -q 'pods/exec' "$defaults"; then echo "ECHEC $defaults : pods/exec interdit"; echec=1; fi

# Bucket de la copie preprod : variable, gabarit (prod seulement), cohérence avec la preprod
grep -q '^bucket_copie_preprod: ' group_vars/all.yml \
    || { echo "ECHEC group_vars/all.yml : bucket_copie_preprod absent"; echec=1; }
gabarit_env=roles/deploiement/templates/deploy.env.j2
verifier "$gabarit_env" "item.key == 'prod'"
verifier "$gabarit_env" 'BUCKET_COPIE_PREPROD={{ bucket_copie_preprod }}'
variables_preprod=../../scripts/secrets/variables-preprod.txt
if [ -f "$variables_preprod" ]; then
    bucket_serveur=$(sed -n 's/^bucket_copie_preprod: *\([^ #]*\).*$/\1/p' group_vars/all.yml)
    bucket_preprod=$(sed -n 's/^WASABI_BUCKET=\(.*\)$/\1/p' "$variables_preprod")
    [ -n "$bucket_serveur" ] && [ "$bucket_serveur" = "$bucket_preprod" ] \
        || { echo "ECHEC bucket_copie_preprod ('$bucket_serveur') diffère de WASABI_BUCKET ('$bucket_preprod') de variables-preprod.txt"; echec=1; }
else
    echo "ECHEC $variables_preprod absent"; echec=1
fi

grep -q '^preprod_quota_memoire_limites: 3Gi$' group_vars/all.yml \
    || { echo "ECHEC group_vars/all.yml : quota de preprod différent de infra/helm/tests-transverses/controle.rb (3Gi)"; echec=1; }

exit $echec
