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
else
    echo "ECHEC $gabarit absent"; echec=1
fi

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

exit $echec
