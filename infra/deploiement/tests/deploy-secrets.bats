#!/usr/bin/env bats
# Entrée standard (secrets et variables), Secret urbankiff-secrets, ConfigMap urbankiff-config, empreinte.

REPERE='Valeur-Repere-Xq7=avec espace'

setup() {
  RACINE_DEPOT="$BATS_TEST_DIRNAME/../../.."
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
  printf 'URBANKIFF_ENV=preprod\nGHCR_OWNER=tigamadou\nNAMESPACE=preprod\n' > "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  ENTREE="$BATS_TEST_TMPDIR/entree"
  entree_complete > "$ENTREE"
}

noms_secrets() { grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/secrets.txt" | cut -d' ' -f1; }

entree_complete() {
  local nom
  for nom in $(noms_secrets); do echo "$nom=valeur-$nom"; done
  grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/variables-preprod.txt" \
    | sed -e 's/^WASABI_REGION=$/WASABI_REGION=eu-central-1/' -e 's/^WASABI_BUCKET=$/WASABI_BUCKET=urbankiff-preprod/'
}

deployer() { # <fichier d'entrée>
  SSH_ORIGINAL_COMMAND="deploy 1.2.3" run bash "$SCRIPT" preprod < "$1"
}

etat_cluster_depuis_entree() { # écrit secret.txt (base64) et config.txt tels que le cluster les contiendrait
  local nom valeur
  : > "$FAKE_STATE/secret.txt"; : > "$FAKE_STATE/config.txt"
  while IFS='=' read -r nom valeur; do
    if noms_secrets | grep -qx "$nom"; then
      printf '%s=%s\n' "$nom" "$(printf '%s' "$valeur" | base64 -w0)" >> "$FAKE_STATE/secret.txt"
    else
      printf '%s=%s\n' "$nom" "$valeur" >> "$FAKE_STATE/config.txt"
    fi
  done < "$1"
}

empreinte_journal() { grep -o 'secretsChecksum=[0-9a-f]*' "$FAKE_LOG" | head -1; }

@test "entrée complète : Secret et ConfigMap créés puis appliqués dans le namespace, valeurs sur l'entrée standard" {
  deployer "$ENTREE"
  grep -q '^kubectl create secret generic urbankiff-secrets -n preprod --from-env-file=/dev/stdin --dry-run=client -o yaml$' "$FAKE_LOG"
  grep -q '^kubectl create configmap urbankiff-config -n preprod --from-env-file=/dev/stdin --dry-run=client -o yaml$' "$FAKE_LOG"
  [ "$(grep -c '^kubectl apply -n preprod -f -$' "$FAKE_LOG")" -eq 2 ]
}

@test "le Secret ne reçoit que les secrets, la ConfigMap que les variables" {
  deployer "$ENTREE"
  secrets="$(noms_secrets | sort | tr '\n' ',')"
  grep -qF "STDIN_NOMS $secrets" "$FAKE_LOG"
  ! grep 'STDIN_NOMS' "$FAKE_LOG" | grep -q 'SECRET_KEY.*NEXT_PUBLIC' || false
  grep -q 'STDIN_NOMS .*WASABI_BUCKET' "$FAKE_LOG"
}

@test "POSTGRES_PASSWORD n'est plus accepté (généré par CloudNativePG)" {
  echo 'POSTGRES_PASSWORD=x' >> "$ENTREE"
  deployer "$ENTREE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nom inconnu"* ]]
  ! grep -q '^kubectl' "$FAKE_LOG"
}

@test "valeur repère : jamais dans les arguments, le journal ni la sortie, même en échec" {
  sed -i "s|^SECRET_KEY=.*|SECRET_KEY=$REPERE|" "$ENTREE"
  deployer "$ENTREE"
  ! grep -qF "$REPERE" "$FAKE_LOG"
  [[ "$output" != *"$REPERE"* ]]
  grep -q 'STDIN create' "$FAKE_LOG"
  echo "MAUVAIS ligne $REPERE" >> "$ENTREE"
  deployer "$ENTREE"
  [ "$status" -eq 1 ]
  [[ "$output" != *"$REPERE"* ]]
  [[ "$output" != *"MAUVAIS"* ]]
}

@test "entrée de plus de 64 Ko : refus sans appel à kubectl" {
  head -c 65537 /dev/zero | tr '\0' 'a' > "$BATS_TEST_TMPDIR/gros"
  deployer "$BATS_TEST_TMPDIR/gros"
  [ "$status" -eq 1 ]
  [[ "$output" == *"64 Ko"* ]]
  ! grep -q '^kubectl' "$FAKE_LOG"
}

@test "entrée de 64 Ko exactement : acceptée jusqu'à la validation" {
  { cat "$ENTREE"; head -c 65536 /dev/zero | tr '\0' 'a'; } > "$BATS_TEST_TMPDIR/limite"
  head -c 65536 "$BATS_TEST_TMPDIR/limite" > "$BATS_TEST_TMPDIR/limite2"
  deployer "$BATS_TEST_TMPDIR/limite2"
  [[ "$output" != *"64 Ko"* ]]
}

@test "lignes mal formées : refus qui nomme le numéro de ligne, jamais la valeur" {
  n=0
  for mauvaise in 'minuscule=x' 'sans-egal' 'INCONNU=x' $'SMTP_PASSWORD=a\rb' 'SECRET_KEY=doublon'; do
    entree_complete > "$ENTREE"
    printf '%s\n' "$mauvaise" >> "$ENTREE"
    ligne="$(wc -l < "$ENTREE")"
    : > "$FAKE_LOG"
    deployer "$ENTREE"
    [ "$status" -eq 1 ] || { echo "accepté : $mauvaise"; return 1; }
    [[ "$output" == *"ligne $ligne"* ]] || { echo "$output"; return 1; }
    [[ "$output" != *"doublon"* ]]
    ! grep -q '^kubectl' "$FAKE_LOG"
  done
}

@test "clé obligatoire absente ou vide : refus qui nomme la clé" {
  for cle in SMTP_PASSWORD WASABI_BUCKET DJANGO_ENV; do
    grep -v "^$cle=" "$ENTREE" > "$BATS_TEST_TMPDIR/e2"
    deployer "$BATS_TEST_TMPDIR/e2"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$cle"* ]]
    sed "s|^$cle=.*|$cle=|" "$ENTREE" > "$BATS_TEST_TMPDIR/e3"
    deployer "$BATS_TEST_TMPDIR/e3"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$cle"* ]]
  done
  ! grep -q '^kubectl' "$FAKE_LOG"
}

@test "WASABI_REGION et WASABI_BUCKET : caractères restreints (valeurs passées à --set)" {
  sed -i 's|^WASABI_REGION=.*|WASABI_REGION=eu,central|' "$ENTREE"
  deployer "$ENTREE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WASABI_REGION"* ]]
}

@test "sans entrée et sans Secret : erreur claire, rien n'est créé" {
  deployer /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"premier déploiement"* ]]
  [[ "$output" == *"make secrets-cluster"* ]]
  ! grep -qE '^kubectl (create|apply|delete|patch|replace)' "$FAKE_LOG"
}

@test "sans entrée et sans ConfigMap : erreur claire" {
  etat_cluster_depuis_entree "$ENTREE"
  rm "$FAKE_STATE/config.txt"
  deployer /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"urbankiff-config"* ]]
}

@test "le Secret existant dont une clé manque : refus" {
  etat_cluster_depuis_entree "$ENTREE"
  grep -v '^SMTP_PASSWORD=' "$FAKE_STATE/secret.txt" > "$BATS_TEST_TMPDIR/s" && mv "$BATS_TEST_TMPDIR/s" "$FAKE_STATE/secret.txt"
  deployer /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"SMTP_PASSWORD"* ]]
}

@test "preprod-arret n'a pas besoin de l'entrée standard et ne la lit pas" {
  SSH_ORIGINAL_COMMAND="preprod-arret" run bash "$SCRIPT" preprod < "$ENTREE"
  ! grep -q 'STDIN' "$FAKE_LOG"
}

@test "sans entrée : aucun create/apply/delete/patch sur le cluster" {
  etat_cluster_depuis_entree "$ENTREE"
  deployer /dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ! grep -qE '^kubectl (create|apply|delete|patch|replace)' "$FAKE_LOG"
  grep -q '^kubectl get secret urbankiff-secrets -n preprod' "$FAKE_LOG"
}
@test "l'empreinte change si une valeur change et ne dépend pas de l'ordre" {
  deployer "$ENTREE"; a="$(empreinte_journal)"
  [ -n "$a" ]
  : > "$FAKE_LOG"; deployer "$ENTREE"; [ "$(empreinte_journal)" = "$a" ]
  tac "$ENTREE" > "$BATS_TEST_TMPDIR/inverse"
  : > "$FAKE_LOG"; deployer "$BATS_TEST_TMPDIR/inverse"; [ "$(empreinte_journal)" = "$a" ]
  sed -i 's|^SMTP_PASSWORD=.*|SMTP_PASSWORD=autre|' "$ENTREE"
  : > "$FAKE_LOG"; deployer "$ENTREE"; [ "$(empreinte_journal)" != "$a" ]
}

@test "l'empreinte change si une variable change" {
  deployer "$ENTREE"; a="$(empreinte_journal)"
  sed -i 's|^WEB_URL=.*|WEB_URL=https://autre.example|' "$ENTREE"
  : > "$FAKE_LOG"; deployer "$ENTREE"; [ "$(empreinte_journal)" != "$a" ]
}

@test "sans entrée : aucun create/apply/delete/patch, empreinte identique à celle de l'entrée" {
  deployer "$ENTREE"; a="$(empreinte_journal)"
  etat_cluster_depuis_entree "$ENTREE"
  : > "$FAKE_LOG"
  deployer /dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  ! grep -qE '^kubectl (create|apply|delete|patch|replace)' "$FAKE_LOG"
  grep -q '^kubectl get secret urbankiff-secrets -n preprod' "$FAKE_LOG"
  [ "$(empreinte_journal)" = "$a" ]
}

