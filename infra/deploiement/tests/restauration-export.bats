#!/usr/bin/env bats
# Action exporter-anonyme (prod seulement) avec de faux kubectl et helm.

load aide

setup() {
  RACINE_DEPOT="$BATS_TEST_DIRNAME/../../.."
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export URBANKIFF_CONFIG_DIR="$BATS_TEST_TMPDIR/etc"
  export URBANKIFF_LOCK_FILE="$BATS_TEST_TMPDIR/verrou"
  mkdir -p "$FAKE_STATE" "$HOME" "$URBANKIFF_CONFIG_DIR"
  : > "$FAKE_LOG"
  for e in preprod prod; do
    printf 'URBANKIFF_ENV=%s\nGHCR_OWNER=tigamadou\nNAMESPACE=%s\nAPI_SERVER_CIDR=203.0.113.10/32\n' "$e" "$e" > "$URBANKIFF_CONFIG_DIR/deploy.$e.env"
  done
  echo 'BUCKET_COPIE_PREPROD=bucket-copie' >> "$URBANKIFF_CONFIG_DIR/deploy.prod.env"
  : > "$FAKE_STATE/secret.txt"
  for nom in $(noms_secrets_complets); do printf '%s=%s\n' "$nom" "$(printf '%s' "valeur-$nom" | base64 -w0)" >> "$FAKE_STATE/secret.txt"; done
  grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/variables-prod.txt" > "$FAKE_STATE/config.txt"
  printf 'image:\n  etiquette: 1.2.3\n' > "$FAKE_STATE/values-urbankiff.yaml"
  printf 'urbankiff-api 2 \n' > "$FAKE_STATE/deployment.txt"
  echo "1/" > "$FAKE_STATE/job-urbankiff-export-anonyme.txt"
  echo "export terminé" > "$FAKE_STATE/logs-urbankiff-export-anonyme.txt"
}

exporter() { # <env> <date>
  SSH_ORIGINAL_COMMAND="exporter-anonyme $2" run bash "$SCRIPT" "$1" < /dev/null
}

@test "succès en prod : rendu avec les --set exacts, lancement, suivi, aucun arrêt de l'application" {
  exporter prod 2026-11-17
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"export terminé : restauration/2026-11-17-prod-anonyme/ vers bucket-copie"* ]]
  grep -q '^helm get values urbankiff -n prod -o yaml$' "$FAKE_LOG"
  grep -q '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff --version 1.2.3' "$FAKE_LOG"
  grep -qF -- '--show-only templates/export-anonyme-job.yaml --set exportAnonyme.prefixe=restauration/2026-11-17-prod-anonyme/ --set exportAnonyme.bucketCible=bucket-copie --set environnement=prod --set wasabi.region=eu-central-1,wasabi.endpoint=s3.eu-central-1.wasabisys.com' "$FAKE_LOG"
  grep -q '^kubectl apply -n prod -f -$' "$FAKE_LOG"
  grep -q '^kubectl delete job urbankiff-export-anonyme -n prod --ignore-not-found$' "$FAKE_LOG"
  absent -qE '^kubectl (scale|annotate)' "$FAKE_LOG"
}

@test "preprod : refus code 2 avant tout appel" {
  exporter preprod 2026-11-17
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "BUCKET_COPIE_PREPROD absent : code 1 sans appel" {
  printf 'URBANKIFF_ENV=prod\nGHCR_OWNER=tigamadou\nNAMESPACE=prod\nAPI_SERVER_CIDR=203.0.113.10/32\n' > "$URBANKIFF_CONFIG_DIR/deploy.prod.env"
  exporter prod 2026-11-17
  [ "$status" -eq 1 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "Job en échec : code 1, Job conservé, message" {
  echo "0/1" > "$FAKE_STATE/job-urbankiff-export-anonyme.txt"
  exporter prod 2026-11-17
  [ "$status" -eq 1 ]
  [[ "$output" == *"le Job urbankiff-export-anonyme a échoué"* ]]
  absent -q '^kubectl delete job' <(sed '1,/^kubectl apply/d' "$FAKE_LOG")
}

@test "journal de fin absent : erreur, Job conservé" {
  echo "autre" > "$FAKE_STATE/logs-urbankiff-export-anonyme.txt"
  exporter prod 2026-11-17
  [ "$status" -eq 1 ]
  [[ "$output" == *"export terminé"* ]]
  absent -q '^kubectl delete job' <(sed '1,/^kubectl apply/d' "$FAKE_LOG")
}

@test "rendu impossible : aucune création de Job" {
  FAKE_TEMPLATE_ECHEC=1 exporter prod 2026-11-17
  [ "$status" -eq 1 ]
  absent -q '^kubectl apply' "$FAKE_LOG"
}

@test "le bucket cible n'apparaît que dans un --set" {
  exporter prod 2026-11-17
  [ "$status" -eq 0 ]
  [ "$(grep -c 'bucket-copie' "$FAKE_LOG")" -eq "$(grep -c -- '--set exportAnonyme.bucketCible=bucket-copie' "$FAKE_LOG")" ]
}

@test "aucun secret en argument ni journalisé" {
  exporter prod 2026-11-17
  [ "$status" -eq 0 ]
  absent -q 'valeur-' "$FAKE_LOG"
  [[ "$output" != *"valeur-"* ]]
}

@test "Secret sans PGADMIN_* : l'export réussit quand même" {
  grep -v '^PGADMIN_' "$FAKE_STATE/secret.txt" > "$FAKE_STATE/secret.sans"
  mv "$FAKE_STATE/secret.sans" "$FAKE_STATE/secret.txt"
  exporter prod 2026-11-17
  [ "$status" -eq 0 ]
}
