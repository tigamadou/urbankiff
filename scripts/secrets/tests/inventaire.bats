#!/usr/bin/env bats
# Cohérence entre les listes du script et l'inventaire, et absence de valeur dans la documentation d'infra.

setup() {
  RACINE="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  INVENTAIRE="$RACINE/docs/v1/infra/secrets.md"
}

@test "chaque nom de secrets.txt et des fichiers de variables figure dans docs/v1/infra/secrets.md" {
  [ -f "$INVENTAIRE" ]
  manquants=""
  noms="$(grep -vh '^#' "$RACINE"/scripts/secrets/secrets.txt | awk 'NF{print $1}'; grep -vh '^#' "$RACINE"/scripts/secrets/variables-*.txt | sed -n 's/^\([A-Z_0-9]*\)=.*/\1/p')"
  for n in $noms; do grep -q "\`$n\`" "$INVENTAIRE" || manquants="$manquants $n"; done
  [ -z "$manquants" ] || { echo "absents de l'inventaire :$manquants"; false; }
}

@test "aucune valeur ne figure dans les docs" {
  [ -d "$RACINE/docs/v1/infra" ]
  ! grep -rnE '^[[:space:]]*(export[[:space:]]+)?[A-Z][A-Z0-9_]*=[^[:space:]<]' "$RACINE/docs/v1/infra" || false
}
