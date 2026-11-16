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

@test "contrat Secrets du lot nettoyage : Wasabi present, imgproxy absent, secrets de deploiement documentes" {
  for n in WASABI_ACCESS_KEY_ID WASABI_SECRET_ACCESS_KEY; do
    grep -q "^$n saisie" "$RACINE/scripts/secrets/secrets.txt"
  done
  for n in WASABI_REGION WASABI_BUCKET; do
    grep -q "^$n=" "$RACINE"/scripts/secrets/variables-prod.txt
    grep -q "^$n=" "$RACINE"/scripts/secrets/variables-preprod.txt
  done
  ! grep -rq 'IMGPROXY_' "$RACINE"/scripts/secrets/secrets.txt "$RACINE"/scripts/secrets/variables-*.txt
  for n in DEPLOY_SSH_KEY DEPLOY_HOST DEPLOY_KNOWN_HOSTS; do
    grep -q "\`$n\`" "$INVENTAIRE"
    ! grep -q "^$n" "$RACINE"/scripts/secrets/secrets.txt "$RACINE"/scripts/secrets/variables-*.txt
  done
  for n in POSTGRES_PASSWORD; do ! grep -q "^$n" "$RACINE/scripts/secrets/secrets.txt"; done
  for n in POSTGRES_USER POSTGRES_DB MINIO_ENDPOINT REACT_APP_MINIO_ENDPOINT; do
    ! grep -q "^$n=" "$RACINE"/scripts/secrets/variables-*.txt
  done
}
