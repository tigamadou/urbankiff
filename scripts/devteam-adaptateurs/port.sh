#!/usr/bin/env bash
# Adaptateur d'exemple devteam : un port hôte par lot dans une plage. Copier dans scripts/devteam-adaptateurs/ et
# ajuster. Ressource : port:<min>-<max> (ex. port:4100-4109). Variable écrite : AGENT_PORT (à publier sur 127.0.0.1 dans
# compose.agent.yml). Variables lues : DEVTEAM_ENVS_ACTIFS et DEVTEAM_ENV_LOT (fournies par le moteur).
set -euo pipefail

action="${1:-}" lot="${2:-}" plage="${3:-}"
EX_PAS_DE_PLACE=75

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <min>-<max>" >&2; exit 2 ;; esac
[[ "$plage" =~ ^[0-9]+-[0-9]+$ ]] || { echo "port : plage invalide « $plage » (attendu : <min>-<max>)" >&2; exit 1; }
min="${plage%-*}" max="${plage#*-}"
[ "$min" -le "$max" ] || { echo "port : plage vide « $plage »" >&2; exit 1; }

port_de() { [ -f "$1" ] && sed -n 's/^export AGENT_PORT=//p' "$1" | awk 'NR == 1'; return 0; }

[ "$action" = variables ] || exit 0
pris=" "
while IFS= read -r f; do
  [ -n "$f" ] || continue
  pris="$pris$(port_de "$f") "
done <<< "${DEVTEAM_ENVS_ACTIFS:-}"
precedent="$(port_de "${DEVTEAM_ENV_LOT:-}")"
if [ -n "$precedent" ] && [ "$precedent" -ge "$min" ] && [ "$precedent" -le "$max" ]; then
  case "$pris" in *" $precedent "*) ;; *) echo "export AGENT_PORT=$precedent"; exit 0 ;; esac
fi
p="$min"
while [ "$p" -le "$max" ]; do
  case "$pris" in *" $p "*) ;; *) echo "export AGENT_PORT=$p"; exit 0 ;; esac
  p=$((p + 1))
done
echo "port : plage $plage pleine" >&2
exit "$EX_PAS_DE_PLACE"
