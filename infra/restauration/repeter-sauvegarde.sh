#!/usr/bin/env bash
# Répète la restauration d'une sauvegarde dans des bases jetables : une base de référence (restauration complète) et une
# base cible restaurée comme le fera le Job du chart (pg_restore --no-owner --no-privileges --schema=public), puis compare
# le décompte exact de chaque table du schéma public. Le rapport (noms de tables et décomptes) est écrit dans
# infra/restauration/rapports/ (dossier ignoré par git).
# Usage : repeter-sauvegarde.sh <dump>
# Codes : 0 décomptes égaux, 1 écart ou échec, 2 mauvais usage.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ $# -ne 1 ]; then
  echo "Usage : repeter-sauvegarde.sh <dump>" >&2
  exit 2
fi
dump="$1"

version=$(version_pg_du_dump "$dump")
verifier_version_supportee "$version"
majeure="${version%%.*}"

tmp=$(mktemp -d)
trap 'nettoyer; rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM
echo "Version PostgreSQL du dump : $version ; bases jetables postgres:$majeure" >&2

demarrer_base_jetable "$majeure" reference
demarrer_base_jetable "$majeure" cible

if ! restaurer_dump reference "$dump" --no-owner --no-privileges > /dev/null; then
  erreur "la restauration de référence a échoué"
  exit 1
fi
if ! restaurer_dump cible "$dump" --no-owner --no-privileges --schema=public > /dev/null; then
  erreur "la restauration répétée (--schema=public) a échoué"
  exit 1
fi

decomptes_tables reference > "$tmp/reference-tout"
grep '^public\.' "$tmp/reference-tout" > "$tmp/source" || true
grep -v '^public\.' "$tmp/reference-tout" > "$tmp/hors-perimetre" || true
decomptes_tables cible public > "$tmp/cible"

code=0
conclusion=$(conclure_comparaison "$tmp/source" "$tmp/cible") || code=1

chemin=$({
  echo "# Répétition de la restauration"
  echo
  echo "Rapport généré le $(date +%F). Version PostgreSQL du dump : $version (base jetable \`postgres:$majeure\`)."
  echo
  echo "Restauration cible : \`pg_restore --no-owner --no-privileges --schema=public\` (options du Job du chart)."
  echo
  echo "## Décomptes exacts du schéma public"
  echo
  tableau_comparaison "$tmp/source" "$tmp/cible"
  echo
  echo "## Hors périmètre (autres schémas, non restaurés par le Job)"
  echo
  tableau Table Lignes < "$tmp/hors-perimetre"
  echo
  echo "## Conclusion"
  echo
  echo "$conclusion"
} | ecrire_rapport "repetition-$(basename "$dump" .dump)")
echo "Rapport : $chemin"
echo "$conclusion"
exit "$code"
