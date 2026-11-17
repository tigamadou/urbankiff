#!/usr/bin/env bash
# restauration-deposer.sh <env> <dump> <dossier-fichiers|""> <date> : dépose la sauvegarde dans Wasabi sous
# restauration/<date>/ (base.dump et, si donné, fichiers/) avec rclone en conteneur, puis contrôle la taille du dump.
# Les identifiants Wasabi viennent de l'environnement du shell (WASABI_ACCESS_KEY_ID, WASABI_SECRET_ACCESS_KEY) ou d'une
# saisie masquée (SECRETS_TTY remplace /dev/tty) ; ils ne passent jamais en argument (`docker run -e NOM`).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

env="${1:-}"; dump="${2:-}"; fichiers="${3:-}"; date="${4:-}"
aide="make restauration-deposer ENV=<prod|preprod> DUMP=<fichier> [FICHIERS=<dossier>] DATE=<AAAA-MM-JJ>"
case "$env" in prod|preprod) ;; *) usage "$aide" ;; esac
[ -f "$dump" ] || usage "$aide (DUMP doit être un fichier existant)"
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage "$aide"
[ -z "$fichiers" ] || [ -d "$fichiers" ] || usage "$aide (FICHIERS doit être un dossier)"
: "${RCLONE_IMAGE:?}"

bucket="$(variable_github "$env" WASABI_BUCKET)" || true
region="$(variable_github "$env" WASABI_REGION)" || true
[[ "$bucket" =~ ^[A-Za-z0-9.-]+$ ]] || die "variable WASABI_BUCKET absente ou invalide dans l'environnement $env"
[[ "$region" =~ ^[A-Za-z0-9.-]+$ ]] || die "variable WASABI_REGION absente ou invalide dans l'environnement $env"

if [ -z "${WASABI_ACCESS_KEY_ID:-}" ] || [ -z "${WASABI_SECRET_ACCESS_KEY:-}" ]; then
  exec 7< "${SECRETS_TTY:-/dev/tty}"
  printf 'WASABI_ACCESS_KEY_ID : ' >&2
  IFS= read -rs WASABI_ACCESS_KEY_ID <&7 || WASABI_ACCESS_KEY_ID=""
  echo >&2
  printf 'WASABI_SECRET_ACCESS_KEY : ' >&2
  IFS= read -rs WASABI_SECRET_ACCESS_KEY <&7 || WASABI_SECRET_ACCESS_KEY=""
  echo >&2
fi
[ -n "$WASABI_ACCESS_KEY_ID" ] && [ -n "$WASABI_SECRET_ACCESS_KEY" ] || die "identifiants Wasabi vides : rien n'est déposé"
export RCLONE_CONFIG_WASABI_ACCESS_KEY_ID="$WASABI_ACCESS_KEY_ID" RCLONE_CONFIG_WASABI_SECRET_ACCESS_KEY="$WASABI_SECRET_ACCESS_KEY"

rclone_wasabi() { # <montages...> -- <arguments rclone>
  local montages=()
  while [ "$1" != -- ]; do montages+=("$1"); shift; done
  shift
  docker run --rm "${montages[@]}" \
    -e RCLONE_CONFIG_WASABI_TYPE=s3 -e RCLONE_CONFIG_WASABI_PROVIDER=Wasabi \
    -e "RCLONE_CONFIG_WASABI_ENDPOINT=s3.$region.wasabisys.com" -e "RCLONE_CONFIG_WASABI_REGION=$region" \
    -e RCLONE_CONFIG_WASABI_SERVER_SIDE_ENCRYPTION=AES256 \
    -e RCLONE_CONFIG_WASABI_ACCESS_KEY_ID -e RCLONE_CONFIG_WASABI_SECRET_ACCESS_KEY \
    "$RCLONE_IMAGE" "$@"
}

depot="wasabi:$bucket/restauration/$date"
rclone_wasabi -v "$(dirname "$dump"):/depot:ro" -- copyto "/depot/$(basename "$dump")" "$depot/base.dump"
if [ -n "$fichiers" ]; then
  rclone_wasabi -v "$fichiers:/fichiers:ro" -- copy /fichiers "$depot/fichiers/"
fi

attendu="$(wc -c < "$dump" | tr -d ' ')"
mesure="$(rclone_wasabi -- size --json "$depot/base.dump" | sed -nE 's/.*"bytes": *([0-9]+).*/\1/p')"
[ "$mesure" = "$attendu" ] || die "taille déposée ($mesure octets) différente de celle du dump ($attendu octets)"
echo "Déposé : $depot/ (base.dump $attendu octets)" >&2
