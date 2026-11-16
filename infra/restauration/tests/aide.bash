# Aides communes des tests bats de la restauration (chargées avec `load aide`).

RESTAURATION_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
DUMP_PIEGE=/tmp/restauration-tests/piege.dump
DUMP_VIDE=/tmp/restauration-tests/vide.dump

charger_lib() {
  # shellcheck disable=SC1091
  . "$RESTAURATION_DIR/lib.sh"
  export RAPPORTS_DIR="$BATS_TEST_TMPDIR/rapports"
}

# Fabrique (une fois par exécution) le dump piégé ou le dump vide ; l'image de l'api vient de API_IMAGE.
dump_piege() {
  [ -s "$DUMP_PIEGE" ] || { mkdir -p "$(dirname "$DUMP_PIEGE")" && bash "$RESTAURATION_DIR/tests/fabriquer-dump.sh" "$DUMP_PIEGE" >&2; }
}

dump_vide() {
  [ -s "$DUMP_VIDE" ] || { mkdir -p "$(dirname "$DUMP_VIDE")" && bash "$RESTAURATION_DIR/tests/fabriquer-dump.sh" "$DUMP_VIDE" vide >&2; }
}

aucun_conteneur_restant() {
  [ -z "$(docker ps -aq --filter label=urbankiff.restauration)" ]
  [ -z "$(docker network ls -q --filter label=urbankiff.restauration)" ]
}
