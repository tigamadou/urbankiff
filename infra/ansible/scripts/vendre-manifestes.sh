#!/bin/sh
# Télécharge les manifestes officiels aux versions de group_vars/all.yml dans roles/plateforme/files/ et écrit SHA256SUMS.
# Seul endroit qui connaît des URL distantes : le rôle n'applique que des fichiers locaux.
# Lancé par `make infra-vendre` dans un conteneur alpine (curl installé à la volée).
set -eu
cd "$(dirname "$0")/.."

version() { sed -n "s/^$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *\$/\1/p" group_vars/all.yml; }
cert_manager=$(version cert_manager_version)
cnpg=$(version cnpg_version)
barman=$(version barman_plugin_version)
for v in "$cert_manager" "$cnpg" "$barman"; do
    [ -n "$v" ] || { echo "Version introuvable dans group_vars/all.yml" >&2; exit 1; }
done

dossier=roles/plateforme/files
mkdir -p "$dossier"
rm -f "$dossier"/cert-manager-*.yaml "$dossier"/cloudnative-pg-*.yaml "$dossier"/plugin-barman-cloud-*.yaml "$dossier"/SHA256SUMS

telecharger() { # url fichier
    curl -fsSL --retry 0 -o "$dossier/$2" "$1"
    [ -s "$dossier/$2" ] || { echo "$2 vide" >&2; exit 1; }
}

telecharger "https://github.com/cert-manager/cert-manager/releases/download/$cert_manager/cert-manager.yaml" "cert-manager-$cert_manager.yaml"
telecharger "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${cnpg%.*}/releases/cnpg-$cnpg.yaml" "cloudnative-pg-$cnpg.yaml"
telecharger "https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/$barman/manifest.yaml" "plugin-barman-cloud-$barman.yaml"

(cd "$dossier" && sha256sum cert-manager-*.yaml cloudnative-pg-*.yaml plugin-barman-cloud-*.yaml > SHA256SUMS)
echo "Manifestes vendus : relire le diff (git diff --stat) avant de commiter."
