#!/usr/bin/env bats
# devteam 1.0.0 : fichier du kit, ne pas modifier ici
# Moteur d'environnement d'agent : validation, worktree, verrou, budget, ressources, arrêt.

load helpers

setup() { setup_env; }

@test "sans argument ou sous-commande inconnue : usage, code 2" {
  run "$AE"
  [ "$status" -eq 2 ]
  run "$AE" inconnue
  [ "$status" -eq 2 ]
  run "$AE" up a web
  [ "$status" -eq 2 ]
}

@test "lots invalides refusés avant tout appel docker (injection comprise)" {
  local lot
  for lot in 'a;rm -rf x' '../x' 'A' '-a' 'a-' 'a b' ''; do
    : > "$CALLS_LOG"
    run "$AE" up "$lot" web feature/base
    [ "$status" -eq 1 ] || { echo "lot accepté : « $lot »"; return 1; }
    refute_docker
  done
}

@test "lot de DEVTEAM_LOT_MAX caractères accepté, un de plus refusé" {
  run "$AE" up "$(printf 'a%.0s' $(seq 1 20))" web feature/base
  [ "$status" -eq 0 ]
  run "$AE" up "$(printf 'b%.0s' $(seq 1 21))" web feature/base
  [ "$status" -eq 1 ]
}

@test "lots réservés test et e2e refusés" {
  run "$AE" up test web feature/base
  [ "$status" -eq 1 ]
  run "$AE" up e2e web feature/base
  [ "$status" -eq 1 ]
  refute_docker
}

@test "profil hors DEVTEAM_PROFILS refusé" {
  run "$AE" up l1 complet feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "profil inconnu"
  refute_docker
}

@test "configuration absente : erreur explicite" {
  rm "$MAIN/devteam.agent.conf"
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "devteam.agent.conf"
}

@test "base inexistante refusée, rien n'est créé" {
  run "$AE" up l1 web nulle-part
  [ "$status" -eq 1 ]
  [ ! -d "$(wt_of l1)" ]
}

@test "base sans fichier Compose déclaré refusée, rien n'est créé" {
  git -C "$MAIN" checkout -q -b sans-agent
  git -C "$MAIN" rm -q compose.agent.yml
  git -C "$MAIN" commit -q -m retrait
  git -C "$MAIN" checkout -q main
  run "$AE" up l1 web sans-agent
  [ "$status" -eq 1 ]
  assert_output_contains "compose.agent.yml"
  [ ! -d "$(wt_of l1)" ]
}

@test "service d'infrastructure absent : refus nommant le service" {
  rm "$FIX/ps/mp.db"
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "db"
}

@test "démon Docker muet : refus" {
  FAKE_DOCKER_INFO_RC=1 run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
}

@test "premier lot : worktree, .agent.env avec les variables de l'adaptateur, conteneurs lancés" {
  run "$AE" up l1 api feature/base
  [ "$status" -eq 0 ]
  [ -d "$(wt_of l1)" ]
  [ "$(git -C "$(wt_of l1)" rev-parse --abbrev-ref HEAD)" = "feature/base-l1" ]
  [ "$(env_value l1 AGENT_LOT)" = "l1" ]
  [ "$(env_value l1 AGENT_PROFIL)" = "api" ]
  [ "$(env_value l1 AGENT_ACTIF)" = "1" ]
  [ "$(env_value l1 FX_NOM)" = "mp_l1" ]
  assert_call '^adaptateur fx variables l1 mp_l1'
  assert_call '^adaptateur fx creer l1 mp_l1'
  assert_call 'docker compose -p mp-ag-l1 -f compose.yml -f compose.agent.yml up -d --wait api worker'
}

@test "l'adaptateur reçoit les .agent.env des autres lots réservés, pas ceux des lots arrêtés" {
  lot_env l2 web 1
  lot_env l3 web 0
  run "$AE" up l1 api feature/base
  [ "$status" -eq 0 ]
  assert_call "adaptateur fx variables l1 mp_l1 actifs=\[$(wt_of l2)/.agent.env\]"
}

@test "budget dépassé : code 75, aucun worktree ni création de ressource" {
  lot_env l2 web 1
  FAKE_MEM_MO=4400 run "$AE" up l1 web feature/base
  [ "$status" -eq 75 ]
  [ ! -d "$(wt_of l1)" ]
  refute_call 'adaptateur fx creer'
  assert_output_contains "budget"
  assert_output_contains "agent-env : pas de place : "
}

@test "budget juste suffisant : accepté" {
  FAKE_MEM_MO=4000 run "$AE" up l1 web feature/base
  [ "$status" -eq 0 ]
}

@test "ressource épuisée (adaptateur en 75) : code 75, aucun worktree" {
  FAKE_ADAPT_RC_variables=75 run "$AE" up l1 web feature/base
  [ "$status" -eq 75 ]
  assert_output_contains "agent-env : pas de place : "
  [ ! -d "$(wt_of l1)" ]
  refute_call 'adaptateur fx creer'
}

@test "adaptateur en erreur : code 1, aucun worktree" {
  FAKE_ADAPT_RC_variables=3 run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  [ ! -d "$(wt_of l1)" ]
}

@test "adaptateur introuvable : erreur explicite" {
  rm "$MAIN/scripts/devteam-adaptateurs/fx.sh"
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "fx.sh"
}

@test "reprise d'un lot arrêté sur sa branche : worktree réutilisé" {
  "$AE" up l1 web feature/base
  "$AE" down l1
  run "$AE" up l1 web feature/base
  [ "$status" -eq 0 ]
  assert_output_contains "reprise"
  [ "$(env_value l1 AGENT_ACTIF)" = "1" ]
}

@test "dossier du lot sur une autre branche : refus" {
  git -C "$MAIN" worktree add -q -b autre "$(wt_of l1)" feature/base
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "autre branche"
}

@test "branche du lot existante sans worktree : refus" {
  git -C "$MAIN" branch feature/base-l1 feature/base
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  [ ! -d "$(wt_of l1)" ]
}

@test "lot déjà actif refusé" {
  lot_conteneurs l1
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "déjà actif"
}

@test "verrou tenu au-delà du délai : code 1, verrou d'autrui conservé, rien créé" {
  mkdir -p "$MAIN/.git/devteam-agent-env.lock"
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  [ -d "$MAIN/.git/devteam-agent-env.lock" ]
  [ ! -d "$(wt_of l1)" ]
}

@test "conteneurs non sains : code 1, message de reprise, rien supprimé" {
  FAKE_COMPOSE_UP_RC=1 run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  assert_output_contains "Reprise"
  [ -d "$(wt_of l1)" ]
  refute_destructif
}

@test "down normal : conteneurs arrêtés, ressources libérées, AGENT_ACTIF=0, rien de destructif" {
  "$AE" up l1 web feature/base
  : > "$CALLS_LOG"
  run "$AE" down l1
  [ "$status" -eq 0 ]
  assert_call 'docker compose -p mp-ag-l1 .* down -v --remove-orphans'
  assert_call '^adaptateur fx liberer l1 mp_l1'
  [ "$(env_value l1 AGENT_ACTIF)" = "0" ]
  [ -d "$(wt_of l1)" ]
  refute_destructif
}

@test "down avec .agent.env corrompu : refus avant tout arrêt ni libération" {
  lot_env l1 web 1
  sed -i 's/^export AGENT_LOT=l1$/export AGENT_LOT=autre/' "$(wt_of l1)/.agent.env"
  run "$AE" down l1
  [ "$status" -eq 1 ]
  refute_call 'compose'
  refute_call 'liberer'
}

@test "down avec une ligne étrangère dans .agent.env : refus" {
  lot_env l1 web 1
  echo 'rm -rf /' >> "$(wt_of l1)/.agent.env"
  run "$AE" down l1
  [ "$status" -eq 1 ]
  refute_call 'compose'
}

@test "down d'un lot inconnu : code 1" {
  run "$AE" down l9
  [ "$status" -eq 1 ]
}

@test "status sans environnement : message puis ligne de budget" {
  run "$AE" status
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Aucun environnement d'agent." ]
  [ "${lines[1]}" = "budget_mo=13000 utilise_mo=0 libre_mo=13000" ]
}

@test "status et budget avec un lot actif et un lot arrêté" {
  lot_env l1 web 1
  lot_conteneurs l1
  lot_env l2 api 0
  run "$AE" status
  [ "$status" -eq 0 ]
  assert_output_contains "lot=l1 profil=web actif"
  [[ "$output" != *"lot=l2"* ]]
  assert_output_contains "budget_mo=13000 utilise_mo=1000 libre_mo=12000"
}

@test "lancé depuis le worktree d'un lot : mêmes chemins que depuis le dépôt principal" {
  "$AE" up l1 web feature/base
  cd "$(wt_of l1)"
  run "$AE" status
  [ "$status" -eq 0 ]
  assert_output_contains "worktree=$(wt_of l1)"
}

@test "les adaptateurs voient les variables DEVTEAM_* de la configuration" {
  run "$AE" up l1 web feature/base
  [ "$status" -eq 0 ]
  assert_call 'adaptateur fx variables .* projet=mp principal=mp'
}

@test "down avec un .agent.env volumineux contenant une ligne étrangère : refus (pas de faux accord par SIGPIPE)" {
  lot_env l1 web 1
  local i
  for i in $(seq 1 20000); do echo "touch $BATS_TEST_TMPDIR/pwned-$i"; done >> "$(wt_of l1)/.agent.env"
  run "$AE" down l1
  [ "$status" -eq 1 ]
  refute_call 'compose'
  [ ! -e "$BATS_TEST_TMPDIR/pwned-1" ]
}

@test "sortie d'adaptateur volumineuse et invalide : refus, aucun worktree" {
  cat > "$MAIN/scripts/devteam-adaptateurs/fx.sh" <<'ADAPT'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = variables ] || exit 0
echo "export FX_NOM=ok"
for i in $(seq 1 20000); do echo "touch /tmp/pwned-$i"; done
ADAPT
  run "$AE" up l1 web feature/base
  [ "$status" -eq 1 ]
  [ ! -d "$(wt_of l1)" ]
}

@test "down d'un lot déjà arrêté : rien n'est relancé, code 0" {
  "$AE" up l1 web feature/base
  "$AE" down l1
  : > "$CALLS_LOG"
  run "$AE" down l1
  [ "$status" -eq 0 ]
  assert_output_contains "déjà arrêté"
  refute_call 'liberer'
  refute_call 'compose'
}

@test "down : l'adaptateur reçoit les .agent.env des autres lots réservés" {
  "$AE" up l1 web feature/base
  lot_env l2 web 1
  : > "$CALLS_LOG"
  run "$AE" down l1
  [ "$status" -eq 0 ]
  assert_call "adaptateur fx liberer l1 mp_l1 actifs=\[$(wt_of l2)/.agent.env\]"
}

@test ".agent.env exclu de git dans le worktree, une seule ligne d'exclusion après deux up" {
  "$AE" up l1 web feature/base
  run git -C "$(wt_of l1)" status --porcelain
  [[ "$output" != *".agent.env"* ]]
  "$AE" down l1
  "$AE" up l1 web feature/base
  [ "$(grep -cx '.agent.env' "$MAIN/.git/info/exclude")" -eq 1 ]
}
