#!/usr/bin/env bats

load aide

setup_file() {
  source "$BATS_TEST_DIRNAME/aide.bash"
  export RAPPORTS_DIR="$BATS_FILE_TMPDIR/rapports"
  dump_piege
  dump_vide
  bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_PIEGE" > "$BATS_FILE_TMPDIR/sortie-piege" 2> "$BATS_FILE_TMPDIR/erreur-piege"
  RAPPORT_PIEGE=$(sed -n 's/^Rapport : //p' "$BATS_FILE_TMPDIR/sortie-piege")
  export RAPPORT_PIEGE
  bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_VIDE" > "$BATS_FILE_TMPDIR/sortie-vide" 2> /dev/null
  RAPPORT_VIDE=$(sed -n 's/^Rapport : //p' "$BATS_FILE_TMPDIR/sortie-vide")
  export RAPPORT_VIDE
}

setup() {
  charger_lib
}

@test "mauvais usage : code 2" {
  run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "dump absent : échec propre" {
  run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" /nexiste/pas.dump
  [ "$status" -eq 1 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "dump illisible : échec propre, rien ne reste" {
  echo "pas un dump" > "$BATS_TEST_TMPDIR/faux.dump"
  run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$BATS_TEST_TMPDIR/faux.dump"
  [ "$status" -eq 1 ]
  [[ "$output" == *"illisible"* ]]
  aucun_conteneur_restant
}

@test "dump plus récent que la version épinglée : échec avec message clair" {
  PG_MAJEURE_MAX=14 run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_PIEGE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plus récent"* ]]
  aucun_conteneur_restant
}

@test "le rapport existe et rien ne reste après l'inspection" {
  [ -s "$RAPPORT_PIEGE" ]
  aucun_conteneur_restant
}

@test "version : détectée et image jetable signalée" {
  grep -q '^## Version' "$RAPPORT_PIEGE"
  grep -qE 'Version PostgreSQL du dump : 15\.' "$RAPPORT_PIEGE"
  grep -q 'postgres:15' "$RAPPORT_PIEGE"
  grep -q 'urbankiff-donnees' "$RAPPORT_PIEGE"
}

@test "tables et décomptes exacts" {
  grep -q '^| public.post_post | 5 |' "$RAPPORT_PIEGE"
  grep -q '^| public.file_file | 5 |' "$RAPPORT_PIEGE"
  grep -q '^| public.user_user | 1 |' "$RAPPORT_PIEGE"
  grep -q '^| cron.job | 1 |' "$RAPPORT_PIEGE"
}

@test "rôle du dump signalé avec ses objets" {
  grep -q '^| piege_role | 1 | 1 | 0 |' "$RAPPORT_PIEGE"
}

@test "fonctions : langage non sûr ou SECURITY DEFINER marqués suspects" {
  grep -q '^| public | piege_definer | sql | oui | SUSPECT (SECURITY DEFINER) |' "$RAPPORT_PIEGE"
  grep -q '^| public | piege_copy | plpgsql | non |  |' "$RAPPORT_PIEGE"
}

@test "extensions" {
  grep -q '^| pg_trgm |' "$RAPPORT_PIEGE"
}

@test "déclencheurs non internes" {
  grep -q '^| public.post_post | piege_declencheur | piege_trigger |' "$RAPPORT_PIEGE"
}

@test "objets suspects : COPY PROGRAM et tâches planifiées" {
  grep -qE 'COPY .* PROGRAM.* : 1$' "$RAPPORT_PIEGE"
  grep -q 'Table `cron.job` : présente, 1 tâche' "$RAPPORT_PIEGE"
  grep -q 'Extension `pg_cron` : absente' "$RAPPORT_PIEGE"
  grep -q "historique des commandes" "$RAPPORT_PIEGE"
}

@test "préfixes d'URL : à réécrire, attendu, différent, hors URL" {
  grep -q '^| https://s3.example.test/bucket | 1 | à réécrire ou à valider |' "$RAPPORT_PIEGE"
  grep -q '^| https://s30.example.test/bucket | 1 | à réécrire ou à valider |' "$RAPPORT_PIEGE"
  grep -q "^| https://api.example.test/file | 2 | différent de l'attendu |" "$RAPPORT_PIEGE"
  grep -q '^| (autre : pas une URL) | 1 |' "$RAPPORT_PIEGE"
  for libelle in 'File.url' 'Post.image' 'banner.Media.file' 'Scrapper.image'; do
    grep -q "$libelle" "$RAPPORT_PIEGE"
  done
}

@test "le préfixe attendu est reconnu quand il correspond" {
  RAPPORTS_DIR="$BATS_TEST_TMPDIR/r2" PREFIXE_ATTENDU=https://api.example.test/file run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_PIEGE"
  [ "$status" -eq 0 ]
  grep -q '^| https://api.example.test/file | 2 | attendu |' "${output##*Rapport : }"
}

@test "aucune donnée de ligne dans le rapport" {
  ! grep -q 'SENTINELLE' "$RAPPORT_PIEGE"
  ! grep -qE 'a\.png|b\.png|c\.png|d\.png|image-sans-schema' "$RAPPORT_PIEGE"
  ! grep -q 'example.test/p/' "$RAPPORT_PIEGE"
}

@test "bucket non fourni : non inspecté" {
  grep -q 'non inspecté' "$RAPPORT_PIEGE"
}

@test "dump sans piège : sections vides et tables absentes" {
  grep -q 'Aucun\.' "$RAPPORT_VIDE"
  grep -q 'absente du dump' "$RAPPORT_VIDE"
  grep -q 'Extension `pg_cron` : absente' "$RAPPORT_VIDE"
  grep -q 'Table `cron.job` : absente' "$RAPPORT_VIDE"
  grep -qE 'COPY .* PROGRAM.* : 0$' "$RAPPORT_VIDE"
}
