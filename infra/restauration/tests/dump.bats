#!/usr/bin/env bats

load aide

setup() {
  charger_lib
}

lister() {
  docker run --rm -i --network none "${PG_CLIENT_IMAGE:-postgres:17.2}" pg_restore -l < "$1"
}

@test "fabriquer-dump : le dump piégé est lisible et contient chaque piège" {
  dump_piege
  run lister "$DUMP_PIEGE"
  [ "$status" -eq 0 ]
  for attendu in "TABLE public file_file" "TABLE public post_post" "TABLE public banner_media" "TABLE public scrapper_scrapper" \
    "FUNCTION public piege_copy" "FUNCTION public piege_definer" "TRIGGER public post_post piege_declencheur" \
    "EXTENSION - pg_trgm" "TABLE cron job" "TABLE public piege_table"; do
    [[ "$output" == *"$attendu"* ]] || { echo "manque : $attendu" >&2; false; }
  done
  aucun_conteneur_restant
}

@test "fabriquer-dump : le dump vide ne contient aucune table" {
  dump_vide
  run lister "$DUMP_VIDE"
  [ "$status" -eq 0 ]
  [[ "$output" != *" TABLE "* ]]
  aucun_conteneur_restant
}

@test "fabriquer-dump : le dump piégé annonce la version 15" {
  dump_piege
  run version_pg_du_dump "$DUMP_PIEGE"
  [ "$status" -eq 0 ]
  [[ "$output" == 15.* ]]
}
