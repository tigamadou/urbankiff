#!/usr/bin/env bats
# Cibles du poste (make/deploiement.mk) avec de faux docker, gh et ssh.

REPERE='Valeur-Repere-Xq7=avec espace'
SHA=0123456789ab

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
      sed -e 's/^WASABI_REGION=$/WASABI_REGION=eu-central-1/' -e 's/^WASABI_BUCKET=$/WASABI_BUCKET=bucket-test/' \
        "$RACINE/scripts/secrets/variables-$e.txt" | grep -vE '^(#|$)'
      echo "DEPLOY_HOST=serveur.test.example"
      printf 'DEPLOY_KNOWN_HOSTS=serveur.test.example ssh-ed25519 AAAAhote\n'
    } > "$FAKE_STATE/variables-$e.txt"
  done
  export SECRETS_TTY="$BATS_TEST_TMPDIR/saisie"
  cd "$RACINE"
}

mk() { run make -s -f make/deploiement.mk COMMIT="$SHA" "$@"; }

@test "usage invalide : code 2 sans appel aux faux" {
  mk images-publier VERSION=1.0.0-rc.1 ENV=staging
  [ "$status" -eq 2 ]
  mk images-publier VERSION=abc ENV=preprod
  [ "$status" -eq 2 ]
  mk images-publier VERSION=1.0.0-rc.1 ENV=prod
  [ "$status" -eq 2 ]
  mk images-publier VERSION=1.0.0 ENV=preprod COMMIT=
  [ "$status" -eq 2 ]
  mk charts-publier VERSION=
  [ "$status" -eq 2 ]
  mk deploiement ENV=preprod
  [ "$status" -eq 2 ]
  mk deploiement ENV=staging VERSION=1.0.0
  [ "$status" -eq 2 ]
  mk secrets-cluster ENV=preprod
  [ "$status" -eq 2 ]
  mk secrets-cluster ENV=x VERSION=1.0.0
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "images-publier preprod : api, Next et panel avec les bonnes étiquettes et linux/amd64" {
  mk images-publier VERSION=1.2.3-rc.1 ENV=preprod
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '^docker login ghcr.io -u testeur --password-stdin$' "$FAKE_LOG"
  grep -q -- "^docker buildx build --platform linux/amd64 --target prod -t ghcr.io/tigamadou/urbankiff-api:sha-$SHA -t ghcr.io/tigamadou/urbankiff-api:1.2.3-rc.1 --push $RACINE/apps/api$" "$FAKE_LOG"
  next="$(grep -- 'urbankiff-nextjs:1.2.3-rc.1-preprod' "$FAKE_LOG")"
  [[ "$next" == *"--platform linux/amd64"* ]]
  for a in NEXT_PUBLIC_BACKEND_URL=https://preprod.api.urbankiff.com NEXT_PUBLIC_BACKEND_URL_FRONT= NEXT_PUBLIC_GOOGLE_CLIENT_ID= BACKEND_URL=https://preprod.api.urbankiff.com; do
    [[ "$next" == *"--build-arg $a"* ]]
  done
  panel="$(grep -- 'urbankiff-panel:1.2.3-rc.1-preprod' "$FAKE_LOG")"
  [[ "$panel" == *"--build-arg REACT_APP_BACKEND_URL=https://preprod.api.urbankiff.com"* ]]
  [[ "$panel" == *"--build-arg REACT_APP_IMAGEKIT_ENDPOINT=https://ik.imagekit.io/ubnews/"* ]]
}

@test "images-publier prod : l'api est réétiquetée, jamais reconstruite ; Next et panel en <version>-prod" {
  mk images-publier VERSION=1.2.3 ENV=prod
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ! grep -q 'urbankiff-api.*--push' "$FAKE_LOG"
  grep -q "^docker buildx imagetools inspect ghcr.io/tigamadou/urbankiff-api:sha-$SHA$" "$FAKE_LOG"
  grep -q "^docker buildx imagetools create --tag ghcr.io/tigamadou/urbankiff-api:1.2.3 ghcr.io/tigamadou/urbankiff-api:sha-$SHA$" "$FAKE_LOG"
  grep -q -- '-t ghcr.io/tigamadou/urbankiff-nextjs:1.2.3-prod --push' "$FAKE_LOG"
  grep -q -- '-t ghcr.io/tigamadou/urbankiff-panel:1.2.3-prod --push' "$FAKE_LOG"
  grep -q -- '--build-arg BACKEND_URL=https://api.urbankiff.com' "$FAKE_LOG"
}

@test "images-publier prod : image du commit absente, aucune étiquette ni construction" {
  FAKE_IMAGE_ABSENTE=1 mk images-publier VERSION=1.2.3 ENV=prod
  [ "$status" -ne 0 ]
  [[ "$output" == *"sha-$SHA"* ]]
  ! grep -qE 'imagetools create|buildx build' "$FAKE_LOG"
}

@test "images-publier : variable de construction absente, échec nommé avant tout build ni connexion" {
  grep -v '^REACT_APP_IMAGEKIT_ENDPOINT=' "$FAKE_STATE/variables-preprod.txt" > "$BATS_TEST_TMPDIR/v"
  mv "$BATS_TEST_TMPDIR/v" "$FAKE_STATE/variables-preprod.txt"
  mk images-publier VERSION=1.2.3-rc.1 ENV=preprod
  [ "$status" -ne 0 ]
  [[ "$output" == *"REACT_APP_IMAGEKIT_ENDPOINT"* ]]
  ! grep -qE '^docker' "$FAKE_LOG"
}

@test "images-publier : URBANKIFF_VAR_<NOM> remplace la variable GitHub (CI)" {
  URBANKIFF_VAR_BACKEND_URL=https://ci.example mk images-publier VERSION=1.2.3-rc.1 ENV=preprod
  [ "$status" -eq 0 ]
  grep -q -- '--build-arg BACKEND_URL=https://ci.example' "$FAKE_LOG"
}

@test "images-publier : GHCR_UTILISATEUR évite gh api user ; le jeton n'est jamais en argument" {
  GHCR_UTILISATEUR=ci-bot mk images-publier VERSION=1.2.3-rc.1 ENV=preprod
  grep -q '^docker login ghcr.io -u ci-bot --password-stdin$' "$FAKE_LOG"
  ! grep -q '^gh api' "$FAKE_LOG"
  ! grep -q 'Jeton-Repere-Gh9' "$FAKE_LOG"
  grep -q '^STDIN docker 17$' "$FAKE_LOG"
}

@test "charts-publier : charts absents, erreur claire sans appel" {
  CHARTS_DIR="$BATS_TEST_TMPDIR/vide" mk charts-publier VERSION=1.2.3-rc.1
  [ "$status" -ne 0 ]
  [[ "$output" == *"chart introuvable"* ]]
  ! grep -q "^docker" "$FAKE_LOG"
}

@test "charts-publier : conteneur helm épinglé, charts en lecture seule, jeton sur l'entrée standard" {
  mkdir -p "$BATS_TEST_TMPDIR/charts/urbankiff" "$BATS_TEST_TMPDIR/charts/urbankiff-donnees"
  CHARTS_DIR="$BATS_TEST_TMPDIR/charts" mk charts-publier VERSION=1.2.3-rc.1
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ligne="$(grep "^docker run" "$FAKE_LOG")"
  [[ "$ligne" == *"alpine/helm:3.16.3"* ]]
  [[ "$ligne" == *"$BATS_TEST_TMPDIR/charts:/charts:ro"* ]]
  [[ "$ligne" == *"CHART_VERSION=1.2.3-rc.1"* ]]
  [[ "$ligne" == *"CHART_OWNER=tigamadou"* ]]
  [[ "$ligne" != *Jeton-Repere-Gh9* ]]
  grep -q "^STDIN docker 17$" "$FAKE_LOG"
}

@test "deploiement : entrée de ssh vide, commande exacte, options strictes" {
  mk deploiement ENV=preprod VERSION=1.2.3-rc.1
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ligne="$(grep '^ssh ' "$FAKE_LOG")"
  [[ "$ligne" == *"-o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="* ]]
  [[ "$ligne" == *" deploy@serveur.test.example deploy 1.2.3-rc.1" ]]
  grep -q '^STDIN ssh 0$' "$FAKE_LOG"
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "preprod-arret et preprod-demarrage : commande exacte vers la preprod" {
  mk preprod-arret
  [ "$status" -eq 0 ]
  mk preprod-demarrage
  [ "$status" -eq 0 ]
  grep -q ' deploy@serveur.test.example preprod-arret$' "$FAKE_LOG"
  grep -q ' deploy@serveur.test.example preprod-demarrage$' "$FAKE_LOG"
  grep -q -- '--env preprod' "$FAKE_LOG"
}

@test "DEPLOY_HOST absent : erreur claire, ssh non appelé" {
  grep -v '^DEPLOY_HOST=' "$FAKE_STATE/variables-preprod.txt" > "$BATS_TEST_TMPDIR/v"
  mv "$BATS_TEST_TMPDIR/v" "$FAKE_STATE/variables-preprod.txt"
  mk preprod-arret
  [ "$status" -ne 0 ]
  [[ "$output" == *"DEPLOY_HOST"* ]]
  ! grep -q '^ssh ' "$FAKE_LOG"
}

@test "DEPLOY_KNOWN_HOSTS absent : erreur claire, ssh non appelé" {
  grep -v '^DEPLOY_KNOWN_HOSTS=' "$FAKE_STATE/variables-preprod.txt" > "$BATS_TEST_TMPDIR/v"
  mv "$BATS_TEST_TMPDIR/v" "$FAKE_STATE/variables-preprod.txt"
  mk preprod-arret
  [ "$status" -ne 0 ]
  [[ "$output" == *"DEPLOY_KNOWN_HOSTS"* ]]
  ! grep -q '^ssh ' "$FAKE_LOG"
}

noms_secrets() { grep -vE '^(#|$)' "$RACINE/scripts/secrets/secrets.txt" | cut -d' ' -f1; }

@test "secrets-cluster : flux NOM=valeur dans un tube, sans fichier ni argument, saisie vide omise" {
  { echo "$REPERE"; for n in $(noms_secrets | tail -n +2); do echo "val-$n"; done; } > "$SECRETS_TTY"
  sed -i.bak '2s/.*//' "$SECRETS_TTY" && rm -f "$SECRETS_TTY.bak"
  avant="$(find "$RACINE" -type f -not -path "$RACINE/.git*" | wc -l)"
  mk secrets-cluster ENV=preprod VERSION=1.2.3-rc.1
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ! grep -qF "$REPERE" "$FAKE_LOG"
  [[ "$output" != *"$REPERE"* ]]
  ! grep -q 'val-' "$FAKE_LOG"
  attendu="SECRET_KEY=$REPERE"$'\n'
  for n in $(noms_secrets | tail -n +3); do attendu+="$n=val-$n"$'\n'; done
  while IFS= read -r n; do
    attendu+="$(grep "^$n=" "$FAKE_STATE/variables-preprod.txt")"$'\n'
  done < <(grep -vE '^(#|$)' "$RACINE/scripts/secrets/variables-preprod.txt" | sed 's/=.*//')
  [ "$(grep '^STDIN ssh' "$FAKE_LOG" | cut -d' ' -f3)" -eq "${#attendu}" ]
  grep -q ' deploy@serveur.test.example deploy 1.2.3-rc.1$' "$FAKE_LOG"
  grep -q 'STDIN_NOMS SECRET_KEY,' "$FAKE_LOG"
  ! grep -q 'STDIN_NOMS .*REDIS_PASSWORD' "$FAKE_LOG"
  ! grep -q 'DEPLOY_HOST=.*STDIN\|STDIN_NOMS .*DEPLOY' "$FAKE_LOG"
  apres="$(find "$RACINE" -type f -not -path "$RACINE/.git*" | wc -l)"
  [ "$avant" -eq "$apres" ]
  [ -z "$(ls -A "$TMPDIR")" ]
  [ -z "$(ls -A "$BATS_TEST_TMPDIR" | grep -vE '^(appels.log|etat|tmp|home|saisie|v)$')" ]
}

@test "secrets-cluster : saisie interrompue, rien n'est envoyé" {
  printf 'a\nb\n' > "$SECRETS_TTY"
  mk secrets-cluster ENV=preprod VERSION=1.2.3-rc.1
  [ "$status" -ne 0 ]
  [[ "$output" == *"saisie interrompue"* ]]
  ! grep -q '^ssh ' "$FAKE_LOG"
}

@test "aucun fichier des cibles du poste n'active xtrace" {
  ! grep -rnE 'set -[a-z]*x|xtrace' infra/deploiement/poste infra/deploiement/urbankiff-deploy.sh
}

@test "make -n : les cibles s'expandent" {
  mk -n images-publier VERSION=0.0.0-rc.1 ENV=preprod
  [ "$status" -eq 0 ]
  mk -n charts-publier VERSION=0.0.0-rc.1
  [ "$status" -eq 0 ]
  mk -n deploiement ENV=preprod VERSION=0.0.0-rc.1
  [ "$status" -eq 0 ]
}
