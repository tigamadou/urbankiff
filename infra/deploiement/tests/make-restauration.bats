#!/usr/bin/env bats
# Cibles du poste de make/restauration.mk avec de faux docker, gh et ssh.

load aide

ID_REPERE='Valeur-Repere-Id-4kz'  # gitleaks:allow
SECRET_REPERE='Valeur-Repere-Secret-9qw'  # gitleaks:allow

setup() {
  RACINE="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_STATE" "$TMPDIR" "$HOME"
  : > "$FAKE_LOG"
  for e in prod preprod; do
    {
      printf 'WASABI_REGION=eu-central-1\nWASABI_BUCKET=bucket-test\n'
      echo "DEPLOY_HOST=serveur.test.example"
      printf 'DEPLOY_KNOWN_HOSTS=serveur.test.example ssh-ed25519 AAAAhote\n'
    } > "$FAKE_STATE/variables-$e.txt"
  done
  export SECRETS_TTY="$BATS_TEST_TMPDIR/saisie"
  export CONFIRMATION_TTY="$BATS_TEST_TMPDIR/confirmation"
  DEPOT_TEST="$BATS_TEST_TMPDIR/depot"
  mkdir -p "$DEPOT_TEST/fichiers"
  printf 'contenu du dump' > "$DEPOT_TEST/base.dump"
  OCTETS="$(wc -c < "$DEPOT_TEST/base.dump" | tr -d ' ')"
  cd "$RACINE"
}

mk() { run make -s -f make/restauration.mk -f make/deploiement.mk "$@"; }

@test "restauration-lancer : usage invalide, code 2 sans appel aux faux" {
  mk restauration-lancer ENV=staging PREFIXE=restauration/2026-11-17/
  [ "$status" -eq 2 ]
  for p in "" "restauration/2026-11-17" "restauration/../2026-11-17/" "/restauration/2026-11-17/" "restauration/2026-11-17/x/" "restauration/2026-1-17/" "restauration/2026-11-17-autre/"; do
    mk restauration-lancer ENV=preprod PREFIXE="$p"
    [ "$status" -eq 2 ] || { echo "accepté : [$p]"; return 1; }
  done
  [ ! -s "$FAKE_LOG" ]
}

@test "restauration-lancer : un export anonymisé ne se charge pas en prod (code 2)" {
  echo prod > "$CONFIRMATION_TTY"
  mk restauration-lancer ENV=prod PREFIXE=restauration/2026-11-17-prod-anonyme/
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "restauration-lancer en preprod : commande exacte, entrée de ssh vide, environnement preprod" {
  mk restauration-lancer ENV=preprod PREFIXE=restauration/2026-11-17/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q ' deploy@serveur.test.example restaurer restauration/2026-11-17/$' "$FAKE_LOG"
  grep -q '^STDIN ssh 0$' "$FAKE_LOG"
  grep -q -- '--env preprod' "$FAKE_LOG"
  grep -q 'urbankiff-deploy-preprod' "$FAKE_LOG"
}

@test "restauration-lancer en preprod : le préfixe anonymisé est accepté" {
  mk restauration-lancer ENV=preprod PREFIXE=restauration/2026-11-17-prod-anonyme/
  [ "$status" -eq 0 ]
  grep -q ' deploy@serveur.test.example restaurer restauration/2026-11-17-prod-anonyme/$' "$FAKE_LOG"
}

@test "restauration-lancer en prod : sans confirmation, rien n'est lancé" {
  : > "$CONFIRMATION_TTY"
  mk restauration-lancer ENV=prod PREFIXE=restauration/2026-11-17/
  [ "$status" -ne 0 ]
  [[ "$output" == *"confirmation absente"* ]]
  absent -q '^ssh ' "$FAKE_LOG"
}

@test "restauration-lancer en prod : un autre mot que prod, code 1 sans ssh" {
  echo oui > "$CONFIRMATION_TTY"
  mk restauration-lancer ENV=prod PREFIXE=restauration/2026-11-17/
  [ "$status" -ne 0 ]
  absent -q '^ssh ' "$FAKE_LOG"
}

@test "restauration-lancer en prod : le mot prod saisi lance la restauration" {
  echo prod > "$CONFIRMATION_TTY"
  mk restauration-lancer ENV=prod PREFIXE=restauration/2026-11-17/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q ' deploy@serveur.test.example restaurer restauration/2026-11-17/$' "$FAKE_LOG"
  grep -q -- '--env prod' "$FAKE_LOG"
}

@test "restauration-deposer : usage invalide, code 2 sans appel aux faux" {
  mk restauration-deposer ENV=staging DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -eq 2 ]
  mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-1-17
  [ "$status" -eq 2 ]
  mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/absent.dump" DATE=2026-11-17
  [ "$status" -eq 2 ]
  mk restauration-deposer ENV=preprod DATE=2026-11-17
  [ "$status" -eq 2 ]
  mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" FICHIERS="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

depose() { # arguments make supplémentaires
  WASABI_ACCESS_KEY_ID="$ID_REPERE" WASABI_SECRET_ACCESS_KEY="$SECRET_REPERE" FAKE_RCLONE_OCTETS="$OCTETS" \
    mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17 "$@"
}

@test "restauration-deposer : chemin heureux avec dossier de fichiers, identifiants par l'environnement seulement par nom" {
  depose FICHIERS="$DEPOT_TEST/fichiers"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(grep -c '^docker run' "$FAKE_LOG")" -eq 3 ]
  grep -q '^docker run --rm -v .*/depot:/depot:ro -e RCLONE_CONFIG_WASABI_TYPE=s3 -e RCLONE_CONFIG_WASABI_PROVIDER=Wasabi -e RCLONE_CONFIG_WASABI_ENDPOINT=s3.eu-central-1.wasabisys.com -e RCLONE_CONFIG_WASABI_REGION=eu-central-1 -e RCLONE_CONFIG_WASABI_SERVER_SIDE_ENCRYPTION=AES256 -e RCLONE_CONFIG_WASABI_ACCESS_KEY_ID -e RCLONE_CONFIG_WASABI_SECRET_ACCESS_KEY rclone/rclone:[0-9.]* copyto /depot/base.dump wasabi:bucket-test/restauration/2026-11-17/base.dump$' "$FAKE_LOG"
  grep -q ' copy /fichiers wasabi:bucket-test/restauration/2026-11-17/fichiers/$' "$FAKE_LOG"
  grep -q ' size --json wasabi:bucket-test/restauration/2026-11-17/base.dump$' "$FAKE_LOG"
  grep -q -- ':/fichiers:ro' "$FAKE_LOG"
  absent -q 'Valeur-Repere' "$FAKE_LOG"
  [[ "$output" != *Valeur-Repere* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "restauration-deposer : sans FICHIERS, un seul docker de copie" {
  depose
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(grep -c ' copyto \| copy ' "$FAKE_LOG")" -eq 1 ]
  absent -q ' copy /fichiers' "$FAKE_LOG"
}

@test "restauration-deposer : taille différente, code 1 avec message" {
  WASABI_ACCESS_KEY_ID="$ID_REPERE" WASABI_SECRET_ACCESS_KEY="$SECRET_REPERE" FAKE_RCLONE_OCTETS=3 \
    mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -ne 0 ]
  [[ "$output" == *"taille déposée (3 octets) différente de celle du dump ($OCTETS octets)"* ]]
}

@test "restauration-deposer : saisie masquée sur SECRETS_TTY quand les variables sont absentes" {
  printf '%s\n%s\n' "$ID_REPERE" "$SECRET_REPERE" > "$SECRETS_TTY"
  FAKE_RCLONE_OCTETS="$OCTETS" mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  absent -q 'Valeur-Repere' "$FAKE_LOG"
  [[ "$output" != *Valeur-Repere* ]]
}

@test "restauration-deposer : saisie vide, erreur sans appel à docker" {
  printf '\n\n' > "$SECRETS_TTY"
  FAKE_RCLONE_OCTETS="$OCTETS" mk restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -ne 0 ]
  [[ "$output" == *"identifiants Wasabi vides"* ]]
  absent -q '^docker' "$FAKE_LOG"
}

@test "restauration-deposer : variables GitHub absentes, erreur sans appel à docker" {
  : > "$FAKE_STATE/variables-preprod.txt"
  depose
  [ "$status" -ne 0 ]
  absent -q '^docker' "$FAKE_LOG"
}

@test "make -n : les deux cibles s'expandent" {
  mk -n restauration-lancer ENV=preprod PREFIXE=restauration/2026-11-17/
  [ "$status" -eq 0 ]
  [[ "$output" == *"restauration-lancer.sh"* ]]
  mk -n restauration-deposer ENV=preprod DUMP="$DEPOT_TEST/base.dump" DATE=2026-11-17
  [ "$status" -eq 0 ]
  [[ "$output" == *"restauration-deposer.sh"* ]]
}

@test "copie-prod-preprod : sans confirmation, ni ssh ni gh" {
  : > "$CONFIRMATION_TTY"
  mk copie-prod-preprod DATE=2026-11-17
  [ "$status" -ne 0 ]
  [[ "$output" == *"confirmation absente"* ]]
  [ ! -s "$FAKE_LOG" ]
  echo preprod > "$CONFIRMATION_TTY"
  mk copie-prod-preprod DATE=2026-11-17
  [ "$status" -ne 0 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "copie-prod-preprod : deux ssh dans l'ordre, commandes exactes, entrées vides" {
  echo prod > "$CONFIRMATION_TTY"
  mk copie-prod-preprod DATE=2026-11-17
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(grep -c '^ssh ' "$FAKE_LOG")" -eq 2 ]
  [ "$(grep -c '^STDIN ssh 0$' "$FAKE_LOG")" -eq 2 ]
  premier="$(grep '^ssh ' "$FAKE_LOG" | sed -n 1p)"
  second="$(grep '^ssh ' "$FAKE_LOG" | sed -n 2p)"
  [[ "$premier" == *"urbankiff-deploy-prod"*" deploy@serveur.test.example exporter-anonyme 2026-11-17" ]]
  [[ "$second" == *"urbankiff-deploy-preprod"*" deploy@serveur.test.example restaurer restauration/2026-11-17-prod-anonyme/" ]]
}

@test "copie-prod-preprod : la date par défaut est le jour UTC" {
  echo prod > "$CONFIRMATION_TTY"
  mk copie-prod-preprod
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q " exporter-anonyme $(date -u +%F)\$" "$FAKE_LOG"
}

@test "copie-prod-preprod : l'échec du premier ssh arrête la copie" {
  echo prod > "$CONFIRMATION_TTY"
  FAKE_SSH_ECHEC=1 mk copie-prod-preprod DATE=2026-11-17
  [ "$status" -ne 0 ]
  [ "$(grep -c '^ssh ' "$FAKE_LOG")" -eq 1 ]
  absent -q 'restaurer' "$FAKE_LOG"
}

@test "copie-prod-preprod : l'échec du second ssh est propagé" {
  echo prod > "$CONFIRMATION_TTY"
  FAKE_SSH_ECHEC=2 mk copie-prod-preprod DATE=2026-11-17
  [ "$status" -ne 0 ]
  [ "$(grep -c '^ssh ' "$FAKE_LOG")" -eq 2 ]
}

@test "copie-prod-preprod : date mal formée refusée sans appel" {
  echo prod > "$CONFIRMATION_TTY"
  mk copie-prod-preprod DATE=2026-1-1
  [ "$status" -ne 0 ]
  [ ! -s "$FAKE_LOG" ]
}
