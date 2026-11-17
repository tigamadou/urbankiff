#!/usr/bin/env bash
# restauration-lancer.sh <env> <prefixe> : lance `restaurer <prefixe>` sur le serveur, sans entrée standard.
# En prod, la saisie du mot `prod` est exigée ; CONFIRMATION_TTY remplace /dev/tty (tests).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

env="${1:-}"; prefixe="${2:-}"
aide="make restauration-lancer ENV=<prod|preprod> PREFIXE=restauration/<AAAA-MM-JJ>[-prod-anonyme]/"
case "$env" in prod|preprod) ;; *) usage "$aide" ;; esac
[[ "$prefixe" =~ ^restauration/[0-9]{4}-[0-9]{2}-[0-9]{2}(-prod-anonyme)?/$ ]] || usage "$aide"
if [ "$env" = prod ] && [[ "$prefixe" == *-prod-anonyme/ ]]; then
  usage "un export anonymisé ne se charge jamais en prod"
fi

if [ "$env" = prod ]; then
  printf 'Restauration de %s dans la PROD : la base actuelle sera remplacée. Saisir "prod" pour confirmer : ' "$prefixe" >&2
  IFS= read -r confirmation < "${CONFIRMATION_TTY:-/dev/tty}" || confirmation=""
  [ "$confirmation" = prod ] || die "confirmation absente : rien n'est lancé"
fi

ssh_deploy "$env" "restaurer $prefixe" < /dev/null
