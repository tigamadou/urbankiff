#!/usr/bin/env bats

load aide

setup_file() {
  source "$BATS_TEST_DIRNAME/aide.bash"
  export RAPPORTS_DIR="$BATS_FILE_TMPDIR/rapports"
  dump_piege
  dump_vide
  bash "$RESTAURATION_DIR/repeter-sauvegarde.sh" "$DUMP_PIEGE" > "$BATS_FILE_TMPDIR/sortie-piege" 2> /dev/null
  echo $? > "$BATS_FILE_TMPDIR/code-piege"
}

setup() {
  charger_lib
}

@test "mauvais usage : code 2" {
  run bash "$RESTAURATION_DIR/repeter-sauvegarde.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "dump absent : échec propre" {
  run bash "$RESTAURATION_DIR/repeter-sauvegarde.sh" /nexiste/pas.dump
  [ "$status" -eq 1 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "dump plus récent que la version épinglée : échec avec message clair" {
  PG_MAJEURE_MAX=14 run bash "$RESTAURATION_DIR/repeter-sauvegarde.sh" "$DUMP_PIEGE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plus récent"* ]]
}

@test "dump piégé : décomptes égaux, code 0, message final" {
  [ "$(cat "$BATS_FILE_TMPDIR/code-piege")" -eq 0 ]
  grep -q 'Restauration répétée : décomptes égaux' "$BATS_FILE_TMPDIR/sortie-piege"
  aucun_conteneur_restant
}

@test "rapport : toutes les tables de public comparées, schémas hors périmètre à part" {
  rapport=$(sed -n 's/^Rapport : //p' "$BATS_FILE_TMPDIR/sortie-piege")
  grep -q '^| public.post_post | 5 | 5 | oui |' "$rapport"
  grep -q '^| public.file_file | 5 | 5 | oui |' "$rapport"
  grep -q '^| public.django_migrations | 167 | 167 | oui |' "$rapport"
  ! grep -q '| NON |' "$rapport"
  grep -q '^| cron.job | 1 |' "$rapport"
  ! grep -q '^| cron.job | 1 | 1 |' "$rapport"
  grep -q -- '--no-owner --no-privileges --schema=public' "$rapport"
  ! grep -q 'SENTINELLE' "$rapport"
}

@test "dump sans table dans public : échec" {
  run bash "$RESTAURATION_DIR/repeter-sauvegarde.sh" "$DUMP_VIDE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aucune table"* ]]
  aucun_conteneur_restant
}
