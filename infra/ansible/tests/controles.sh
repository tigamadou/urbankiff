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

exit $echec
