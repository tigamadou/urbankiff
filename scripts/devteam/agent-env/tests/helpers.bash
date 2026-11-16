# devteam 1.0.0 : fichier du kit, ne pas modifier ici
# Aides des tests du moteur d'environnement d'agent : dépôt git réel dans $BATS_TEST_TMPDIR/root/main, faux docker en
# tête du PATH, adaptateur factice « fx » qui journalise ses appels dans $CALLS_LOG.

AE_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
AE="$AE_DIR/agent-env.sh"

setup_env() {
  ROOT="$BATS_TEST_TMPDIR/root"
  MAIN="$ROOT/main"
  FIX="$BATS_TEST_TMPDIR/fix"
  CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$MAIN" "$FIX/ps"
  : > "$CALLS_LOG"
  export ROOT MAIN FIX CALLS_LOG
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export AGENT_LOCK_TIMEOUT=1 AGENT_LOCK_SLEEP=0
  export FAKE_MEM_MO=16000
  cd "$MAIN"
  git init -q -b main .
  git config user.email t@example.com
  git config user.name T
  git config commit.gpgsign false
  echo 'services: {}' > compose.yml
  echo 'services: {}' > compose.agent.yml
  git add -A
  git commit -q -m init
  git branch feature/base
  ecrire_conf
  adaptateur fx
  infra_en_marche
}

# Configuration générique : profils web (1000 Mo) et api (500 Mo), une ressource « fx:mp_{lot} »
ecrire_conf() {
  cat > "$MAIN/devteam.agent.conf" <<'CONF'
DEVTEAM_PROJET=mp
DEVTEAM_PROFILS="web api"
DEVTEAM_COUT_MO_web=1000
DEVTEAM_SERVICES_web="web"
DEVTEAM_COUT_MO_api=500
DEVTEAM_SERVICES_api="api worker"
DEVTEAM_STACK_MO=2000
DEVTEAM_MARGE_MO=1000
DEVTEAM_COMPOSE_FICHIERS="compose.yml compose.agent.yml"
DEVTEAM_PROJET_PRINCIPAL=mp
DEVTEAM_SERVICES_INFRA="db"
DEVTEAM_RESSOURCES="fx:mp_{lot}"
DEVTEAM_LOT_MAX=20
CONF
}

# adaptateur <type> : adaptateur factice ; FAKE_ADAPT_RC_<action> force son code de sortie
adaptateur() {
  mkdir -p "$MAIN/scripts/devteam-adaptateurs"
  cat > "$MAIN/scripts/devteam-adaptateurs/$1.sh" <<'ADAPT'
#!/usr/bin/env bash
set -euo pipefail
echo "adaptateur $(basename "$0" .sh) $* actifs=[${DEVTEAM_ENVS_ACTIFS:-}] projet=${DEVTEAM_PROJET:-} principal=${DEVTEAM_PROJET_PRINCIPAL:-}" >> "$CALLS_LOG"
var="FAKE_ADAPT_RC_$1"
rc="${!var:-0}"
[ "$rc" = 0 ] || exit "$rc"
[ "$1" != variables ] || echo "export FX_NOM=$3"
ADAPT
  chmod +x "$MAIN/scripts/devteam-adaptateurs/$1.sh"
}

infra_en_marche() { echo "mp-db-1" > "$FIX/ps/mp.db"; }

wt_of() { echo "$ROOT/mp-wt-$1"; }

# lot_env <lot> <profil> <actif> : .agent.env d'un lot existant
lot_env() {
  local wt
  wt="$(wt_of "$1")"
  mkdir -p "$wt"
  printf 'export AGENT_LOT=%s\nexport AGENT_PROFIL=%s\nexport AGENT_ACTIF=%s\nexport FX_NOM=mp_%s\n' "$1" "$2" "$3" "$1" > "$wt/.agent.env"
}

lot_conteneurs() { echo "c1" > "$FIX/ps/mp-ag-$1"; }

env_value() { sed -n "s/^export $2=//p" "$(wt_of "$1")/.agent.env"; }

assert_call() { grep -qE -- "$1" "$CALLS_LOG" || { echo "appel attendu absent : $1"; cat "$CALLS_LOG"; return 1; }; }
refute_call() { if grep -qE -- "$1" "$CALLS_LOG"; then echo "appel interdit présent : $1"; cat "$CALLS_LOG"; return 1; fi; }
refute_docker() { refute_call '^docker '; }
refute_destructif() {
  refute_call 'worktree remove'
  refute_call 'branch -[dD]'
  refute_call 'dropdb|DROP DATABASE|FLUSHALL'
}
assert_output_contains() { case "$output" in *"$1"*) ;; *) echo "sortie sans « $1 » :"; echo "$output"; return 1 ;; esac; }
