#!/usr/bin/env bash
# copie-prod-preprod.sh [date] : exporte la base de la prod en version anonymisée, puis la restaure dans la preprod.
# La saisie du mot `prod` est exigée (CONFIRMATION_TTY remplace /dev/tty, tests). Le premier échec arrête la copie.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

date="${1:-$(date -u +%F)}"
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage "make copie-prod-preprod [DATE=<AAAA-MM-JJ>]"

printf 'Copie anonymisée de la PROD vers la preprod (%s) : la base de la preprod sera remplacée. Saisir "prod" pour confirmer : ' "$date" >&2
IFS= read -r confirmation < "${CONFIRMATION_TTY:-/dev/tty}" || confirmation=""
[ "$confirmation" = prod ] || die "confirmation absente : rien n'est lancé"

ssh_deploy prod "exporter-anonyme $date" < /dev/null
ssh_deploy preprod "restaurer restauration/$date-prod-anonyme/" < /dev/null
echo "Copie terminée : restauration/$date-prod-anonyme/ restauré dans la preprod." >&2
