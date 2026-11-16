#!/usr/bin/env bats
# preprod-arret et preprod-demarrage.

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
  printf 'URBANKIFF_ENV=preprod\nGHCR_OWNER=tigamadou\nNAMESPACE=preprod\n' > "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
}

lancer() { SSH_ORIGINAL_COMMAND="$1" run bash "$SCRIPT" preprod < /dev/null; }

@test "KUBECONFIG vaut ~/.kube/<env>" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "KUBECONFIG=$KUBECONFIG" >> "$FAKE_LOG"\n' > "$BATS_TEST_TMPDIR/bin/kubectl"
  chmod +x "$BATS_TEST_TMPDIR/bin/kubectl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" lancer preprod-arret
  grep -q "^KUBECONFIG=$HOME/.kube/preprod$" "$FAKE_LOG"
}

@test "arrêt : met à zéro les charges applicatives en notant les réplicas, puis hibernation" {
  printf 'urbankiff-api 2 \nurbankiff-nextjs 1 \n' > "$FAKE_STATE/deployment.txt"
  printf 'urbankiff-redis 1 \n' > "$FAKE_STATE/statefulset.txt"
  lancer preprod-arret
  [ "$status" -eq 0 ]
  grep -q -- '^kubectl get deployment -n preprod -l app.kubernetes.io/part-of=urbankiff ' "$FAKE_LOG"
  grep -q '^kubectl annotate deployment/urbankiff-api -n preprod urbankiff.com/replicas-avant=2 --overwrite$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-api -n preprod --replicas=0$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-nextjs -n preprod --replicas=0$' "$FAKE_LOG"
  grep -q '^kubectl annotate statefulset/urbankiff-redis -n preprod urbankiff.com/replicas-avant=1 --overwrite$' "$FAKE_LOG"
  grep -q '^kubectl scale statefulset/urbankiff-redis -n preprod --replicas=0$' "$FAKE_LOG"
  grep -q '^kubectl annotate cluster.postgresql.cnpg.io/urbankiff-pg -n preprod cnpg.io/hibernation=on --overwrite$' "$FAKE_LOG"
  dernier_scale="$(grep -n '^kubectl scale' "$FAKE_LOG" | tail -1 | cut -d: -f1)"
  hib="$(grep -n 'hibernation=on' "$FAKE_LOG" | cut -d: -f1)"
  [ "$dernier_scale" -lt "$hib" ]
}

@test "arrêt répété : rien ne change" {
  printf 'urbankiff-api 0 2\n' > "$FAKE_STATE/deployment.txt"
  echo on > "$FAKE_STATE/hibernation.txt"
  lancer preprod-arret
  [ "$status" -eq 0 ]
  ! grep -qE '^kubectl (scale|annotate)' "$FAKE_LOG"
}

@test "démarrage : réveille la base, attend, remet à l'échelle d'origine et retire la note" {
  printf 'urbankiff-api 0 2\nurbankiff-nextjs 0 1\nurbankiff-autre 0 \n' > "$FAKE_STATE/deployment.txt"
  echo on > "$FAKE_STATE/hibernation.txt"
  lancer preprod-demarrage
  [ "$status" -eq 0 ]
  grep -q '^kubectl annotate cluster.postgresql.cnpg.io/urbankiff-pg -n preprod cnpg.io/hibernation=off --overwrite$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-api -n preprod --replicas=2$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-nextjs -n preprod --replicas=1$' "$FAKE_LOG"
  grep -q '^kubectl annotate deployment/urbankiff-api -n preprod urbankiff.com/replicas-avant-$' "$FAKE_LOG"
  ! grep -q 'urbankiff-autre -n preprod --replicas' "$FAKE_LOG"
  off="$(grep -n 'hibernation=off' "$FAKE_LOG" | cut -d: -f1)"
  w="$(grep -n '^kubectl wait' "$FAKE_LOG" | cut -d: -f1)"
  s="$(grep -n '^kubectl scale' "$FAKE_LOG" | head -1 | cut -d: -f1)"
  [ "$off" -lt "$w" ] && [ "$w" -lt "$s" ]
}

@test "démarrage répété : rien à remettre à l'échelle, base déjà réveillée" {
  printf 'urbankiff-api 2 \n' > "$FAKE_STATE/deployment.txt"
  echo off > "$FAKE_STATE/hibernation.txt"
  lancer preprod-demarrage
  [ "$status" -eq 0 ]
  ! grep -qE '^kubectl (scale|annotate)' "$FAKE_LOG"
}

@test "démarrage : base pas prête, aucune charge relancée" {
  printf 'urbankiff-api 0 2\n' > "$FAKE_STATE/deployment.txt"
  FAKE_WAIT_ECHEC=1 lancer preprod-demarrage
  [ "$status" -eq 1 ]
  ! grep -q '^kubectl scale' "$FAKE_LOG"
}

@test "jamais de suppression de PVC, de Secret ni d'autre ressource" {
  printf 'urbankiff-api 2 \n' > "$FAKE_STATE/deployment.txt"
  lancer preprod-arret
  printf 'urbankiff-api 0 2\n' > "$FAKE_STATE/deployment.txt"
  lancer preprod-demarrage
  ! grep -qE '^kubectl (delete|patch|replace|create|apply)' "$FAKE_LOG"
}
