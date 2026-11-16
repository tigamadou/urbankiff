#!/usr/bin/env bats
# Déploiement : charts OCI, ordre des appels, --atomic, santé.

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
  export TMPDIR="$BATS_TEST_TMPDIR"
  mkdir -p "$URBANKIFF_CONFIG_DIR"
  printf 'URBANKIFF_ENV=preprod\nGHCR_OWNER=tigamadou\nNAMESPACE=preprod\n' > "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  ENTREE="$BATS_TEST_TMPDIR/entree"
  {
    for nom in $(grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/secrets.txt" | cut -d' ' -f1); do echo "$nom=valeur-$nom"; done
    grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/variables-preprod.txt" \
      | sed -e 's/^WASABI_REGION=$/WASABI_REGION=eu-central-1/' -e 's/^WASABI_BUCKET=$/WASABI_BUCKET=urbankiff-preprod/'
  } > "$ENTREE"
}

deployer() { SSH_ORIGINAL_COMMAND="deploy 1.2.3" run bash "$SCRIPT" preprod < "${1:-$ENTREE}"; }
numero() { grep -n -m1 -- "$1" "$FAKE_LOG" | cut -d: -f1; }

@test "ordre : pull des deux charts, Secrets, données, attente CNPG, application, santé" {
  deployer
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff-donnees --version 1.2.3 --untar --untardir ' "$FAKE_LOG"
  grep -q '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff --version 1.2.3 --untar --untardir ' "$FAKE_LOG"
  p1="$(numero '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff ')"
  s="$(numero '^kubectl apply')"
  d="$(numero '^helm upgrade --install urbankiff-donnees ')"
  w="$(numero '^kubectl wait cluster.postgresql.cnpg.io/urbankiff-pg')"
  a="$(numero '^helm upgrade --install urbankiff ')"
  c="$(numero '^curl ')"
  [ "$p1" -lt "$s" ] && [ "$s" -lt "$d" ] && [ "$d" -lt "$w" ] && [ "$w" -lt "$a" ] && [ "$a" -lt "$c" ]
}

@test "données sans --atomic avec --wait ; application avec --atomic --wait --timeout et les valeurs" {
  deployer
  ligne_donnees="$(grep '^helm upgrade --install urbankiff-donnees ' "$FAKE_LOG")"
  [[ "$ligne_donnees" == *" --wait "* ]]
  [[ "$ligne_donnees" != *"--atomic"* ]]
  [[ "$ligne_donnees" == *"-n preprod"* ]]
  [[ "$ligne_donnees" == *"values-preprod.yaml"* ]]
  ligne_app="$(grep '^helm upgrade --install urbankiff ' "$FAKE_LOG")"
  [[ "$ligne_app" == *"--atomic --wait --timeout 10m"* ]]
  [[ "$ligne_app" == *"--set image.etiquette=1.2.3"* ]]
  [[ "$ligne_app" == *"--set environnement=preprod"* ]]
  [[ "$ligne_app" == *"--set wasabi.region=eu-central-1,wasabi.bucket=urbankiff-preprod"* ]]
  [[ "$ligne_app" =~ --set\ secretsChecksum=[0-9a-f]{16}\  ]]
  [[ "$ligne_app" == *"values-preprod.yaml"* ]]
}

@test "aucun login de registre : les paquets GHCR sont publics" {
  deployer
  ! grep -q 'registry login' "$FAKE_LOG"
}

@test "chart introuvable : arrêt avant tout upgrade et avant tout Secret" {
  FAKE_PULL_ECHEC=1 deployer
  [ "$status" -eq 1 ]
  [[ "$output" == *"chart introuvable"* ]]
  ! grep -qE '^helm upgrade|^kubectl (create|apply)' "$FAKE_LOG"
}

@test "CloudNativePG pas prêt : l'application n'est pas déployée" {
  FAKE_WAIT_ECHEC=1 deployer
  [ "$status" -eq 1 ]
  grep -q '^helm upgrade --install urbankiff-donnees ' "$FAKE_LOG"
  ! grep -q '^helm upgrade --install urbankiff ' "$FAKE_LOG"
}

@test "échec de l'upgrade de l'application : code non nul, pas de test de santé" {
  FAKE_UPGRADE_ECHEC=1 deployer
  [ "$status" -ne 0 ]
  ! grep -q '^curl ' "$FAKE_LOG"
}

@test "santé : deux échecs puis succès" {
  FAKE_CURL_ECHECS=2 deployer
  [ "$status" -eq 0 ]
  [ "$(grep -c '^curl ' "$FAKE_LOG")" -eq 3 ]
  grep -q '^curl .*https://api.test.example/api/health/$' "$FAKE_LOG"
}

@test "santé : échec permanent, sortie non nulle après 24 essais" {
  FAKE_CURL_ECHECS=-1 deployer
  [ "$status" -eq 1 ]
  [ "$(grep -c '^curl ' "$FAKE_LOG")" -eq 24 ]
  [[ "$output" == *"2 minutes"* ]]
}

@test "hôte de l'Ingress illisible : erreur" {
  FAKE_HOTE='a b;c' deployer
  [ "$status" -eq 1 ]
  ! grep -q '^curl ' "$FAKE_LOG"
}

@test "répertoire temporaire supprimé en fin d'exécution, succès comme échec" {
  deployer
  [ -z "$(ls "$BATS_TEST_TMPDIR" | grep '^tmp\.')" ]
  FAKE_UPGRADE_ECHEC=1 deployer
  [ -z "$(ls "$BATS_TEST_TMPDIR" | grep '^tmp\.')" ]
}

@test "aucun secret ne figure dans le journal des appels ni la sortie" {
  sed -i 's|^SECRET_KEY=.*|SECRET_KEY=Valeur-Repere-Xq7=avec espace|' "$ENTREE"
  deployer
  ! grep -qF 'Valeur-Repere-Xq7' "$FAKE_LOG"
  [[ "$output" != *"Valeur-Repere-Xq7"* ]]
  ! grep -q 'valeur-SMTP_PASSWORD' "$FAKE_LOG"
}
