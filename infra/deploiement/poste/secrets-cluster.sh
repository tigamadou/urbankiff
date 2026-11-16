#!/usr/bin/env bash
# secrets-cluster.sh <env> <version> : saisie masquée des secrets, puis `deploy <version>` avec secrets et variables sur
# l'entrée standard de SSH. Les valeurs vivent dans une variable du shell et un tube : ni fichier, ni export, ni argument.
# SECRETS_TTY remplace /dev/tty (tests).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

env="${1:-}"; version="${2:-}"
case "$env" in prod|preprod) ;; *) usage "make secrets-cluster ENV=<prod|preprod> VERSION=<x.y.z>" ;; esac
[[ "$version" =~ $SEMVER ]] || usage "make secrets-cluster ENV=<prod|preprod> VERSION=<x.y.z>"
TTY="${SECRETS_TTY:-/dev/tty}"
DOSSIER_SECRETS="$RACINE/scripts/secrets"

variables="$(variables_github "$env")"
charge=""
exec 7< "$TTY"
while IFS= read -r nom; do
  printf '%s (%s, vide = omis) : ' "$nom" "$env" >&2
  if ! IFS= read -rs valeur <&7; then
    echo >&2
    die "saisie interrompue sur $nom : rien n'est envoyé"
  fi
  echo >&2
  [ -z "$valeur" ] || charge+="$nom=$valeur"$'\n'
done < <(noms_fichier "$DOSSIER_SECRETS/secrets.txt")
unset valeur

while IFS= read -r nom; do
  ligne="$(printf '%s\n' "$variables" | grep -m1 "^$nom=" || true)"
  [ -z "$ligne" ] || charge+="$ligne"$'\n'
done < <(noms_fichier "$DOSSIER_SECRETS/variables-$env.txt")

printf '%s' "$charge" | ssh_deploy "$env" "deploy $version"
