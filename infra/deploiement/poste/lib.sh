#!/usr/bin/env bash
# Fonctions communes des cibles du poste (sourcé). Variables attendues : DEPOT_GITHUB, PROPRIETAIRE_GHCR.

: "${DEPOT_GITHUB:?}" "${PROPRIETAIRE_GHCR:?}"
# shellcheck disable=SC2034
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC2034
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'

usage() { echo "usage : $1" >&2; exit 2; }
die() { echo "erreur : $*" >&2; exit 1; }

variables_github() { # <env> : « NOM=valeur » par ligne
  gh variable list --env "$1" --repo "$DEPOT_GITHUB" --json name,value -q '.[] | "\(.name)=\(.value)"'
}

variable_github() { # <env> <nom>
  gh variable get "$2" --env "$1" --repo "$DEPOT_GITHUB"
}

noms_fichier() { grep -vE '^(#|$)' "$1" | sed -E 's/[ =].*//'; }

# Se connecte au compte deploy : la clé vient de l'agent SSH, l'hôte et son empreinte des variables de l'environnement.
# L'entrée standard est transmise telle quelle à la commande distante.
ssh_deploy() { # <env> <commande>
  local hote hotes_connus identite dossier statut=0
  hote="$(variable_github "$1" DEPLOY_HOST)" || true
  [[ "$hote" =~ ^[A-Za-z0-9.-]+$ ]] || die "variable DEPLOY_HOST absente ou invalide dans l'environnement $1"
  hotes_connus="$(variable_github "$1" DEPLOY_KNOWN_HOSTS)" || true
  [ -n "$hotes_connus" ] || die "variable DEPLOY_KNOWN_HOSTS absente de l'environnement $1"
  identite="${DEPLOY_IDENTITE:-$HOME/.ssh/urbankiff-deploy-$1.pub}"
  dossier="$(mktemp -d)"
  printf '%s\n' "$hotes_connus" > "$dossier/known_hosts"
  ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$dossier/known_hosts" \
    -i "$identite" "deploy@$hote" "$2" || statut=$?
  rm -rf "$dossier"
  return "$statut"
}
