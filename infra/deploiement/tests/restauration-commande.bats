#!/usr/bin/env bats
# Commandes restaurer et exporter-anonyme : analyse, refus, configuration, verrou (urbankiff-deploy.sh).

load aide

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  mkdir -p "$FAKE_STATE"
  : > "$FAKE_LOG"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export URBANKIFF_CONFIG_DIR="$BATS_TEST_TMPDIR/etc"
  export URBANKIFF_LOCK_FILE="$BATS_TEST_TMPDIR/verrou"
  mkdir -p "$URBANKIFF_CONFIG_DIR"
  ecrire_config preprod
  ecrire_config prod
  echo 'BUCKET_COPIE_PREPROD=bucket-preprod' >> "$URBANKIFF_CONFIG_DIR/deploy.prod.env"
}

ecrire_config() {
  printf 'URBANKIFF_ENV=%s\nGHCR_OWNER=tigamadou\nNAMESPACE=%s\nAPI_SERVER_CIDR=203.0.113.10/32\n' "$1" "$1" > "$URBANKIFF_CONFIG_DIR/deploy.$1.env"
}

lancer() { # <env> <commande>
  SSH_ORIGINAL_COMMAND="$2" run bash "$SCRIPT" "$1" < /dev/null
}

@test "restaurer : préfixes mal formés refusés (code 2), aucun appel" {
  for c in "restaurer" "restaurer restauration/2026-11-17" "restaurer restauration/../2026-11-17/" "restaurer /restauration/2026-11-17/" \
    "restaurer restauration/2026-11-17/x/" "restaurer restauration/2026-1-17/" "restaurer restauration/2026-11-17-prod-anonymes/" \
    "restaurer restauration/2026-11-17/ extra" "restaurer restauration/2026-11-17-prod/" "restaurer autre/2026-11-17/"; do
    lancer preprod "$c"
    [ "$status" -eq 2 ] || { echo "accepté : [$c]"; return 1; }
  done
  lancer preprod $'restaurer restauration/2026-11-17/\nid'
  [ "$status" -eq 2 ]
  lancer preprod $'restaurer restauration/2026-11-17/\n'
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "restaurer : préfixe accepté dans les deux formes, en preprod" {
  lancer preprod "restaurer restauration/2026-11-17/"
  [ "$status" -ne 2 ]
  [[ "$output" == *"commande restaurer"* ]]
  lancer preprod "restaurer restauration/2026-11-17-prod-anonyme/"
  [ "$status" -ne 2 ]
  [[ "$output" == *"commande restaurer"* ]]
}

@test "restaurer : préfixe de prod accepté en prod" {
  lancer prod "restaurer restauration/2026-11-17/"
  [ "$status" -ne 2 ]
  [[ "$output" == *"commande restaurer"* ]]
}

@test "restaurer d'un préfixe anonymisé en prod : refusé (code 2) avant tout appel" {
  lancer prod "restaurer restauration/2026-11-17-prod-anonyme/"
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "exporter-anonyme : dates mal formées refusées" {
  for c in "exporter-anonyme" "exporter-anonyme 2026-1-17" "exporter-anonyme 2026-11-17 extra" "exporter-anonyme 20261117" 'exporter-anonyme $(id)' "exporter-anonyme 2026-11-17;id"; do
    lancer prod "$c"
    [ "$status" -eq 2 ] || { echo "accepté : [$c]"; return 1; }
  done
  [ ! -s "$FAKE_LOG" ]
}

@test "exporter-anonyme en preprod : refus code 2 avant tout appel" {
  lancer preprod "exporter-anonyme 2026-11-17"
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "exporter-anonyme en prod : accepté" {
  lancer prod "exporter-anonyme 2026-11-17"
  [ "$status" -eq 0 ]
}

@test "BUCKET_COPIE_PREPROD : accepté dans deploy.prod.env, valeurs invalides refusées" {
  for valeur in "a;b" "" 'a b' '$(id)'; do
    ecrire_config prod
    echo "BUCKET_COPIE_PREPROD=$valeur" >> "$URBANKIFF_CONFIG_DIR/deploy.prod.env"
    lancer prod "exporter-anonyme 2026-11-17"
    [ "$status" -eq 1 ] || { echo "accepté : [$valeur]"; return 1; }
    [[ "$output" == *"BUCKET_COPIE_PREPROD"* ]]
  done
}

@test "BUCKET_COPIE_PREPROD : clé inconnue dans deploy.preprod.env" {
  echo 'BUCKET_COPIE_PREPROD=bucket-preprod' >> "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "restaurer restauration/2026-11-17/"
  [ "$status" -eq 1 ]
  [[ "$output" == *"clé inconnue"* ]]
}

@test "BUCKET_COPIE_PREPROD absent de prod : deploy et restaurer démarrent, exporter-anonyme répond en erreur" {
  ecrire_config prod
  lancer prod "deploy 1.2.3"
  [[ "$output" == *"version 1.2.3"* ]]
  lancer prod "restaurer restauration/2026-11-17/"
  [ "$status" -ne 2 ]
  [[ "$output" == *"commande restaurer"* ]]
  : > "$FAKE_LOG"
  lancer prod "exporter-anonyme 2026-11-17"
  [ "$status" -eq 1 ]
  [[ "$output" == *"configuration : BUCKET_COPIE_PREPROD absent"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "verrou déjà pris : un déploiement est déjà en cours, pour les deux commandes" {
  FAKE_FLOCK_ECHEC=1 lancer prod "restaurer restauration/2026-11-17/"
  [ "$status" -eq 1 ]
  [[ "$output" == *"un déploiement est déjà en cours"* ]]
  FAKE_FLOCK_ECHEC=1 lancer prod "exporter-anonyme 2026-11-17"
  [ "$status" -eq 1 ]
  [[ "$output" == *"un déploiement est déjà en cours"* ]]
}
