#!/usr/bin/env bash
# devteam 1.0.0 : fichier du kit, ne pas modifier ici
# Environnement d'agent devteam : un worktree et ses conteneurs applicatifs par lot, sur l'infrastructure partagée de
# la stack principale.
#
#   agent-env.sh up <lot> <profil> <base>   worktree ../<projet>-wt-<lot> sur <base>-<lot> + conteneurs du profil
#   agent-env.sh down <lot>                 arrête les conteneurs de l'agent, libère ses ressources, conserve le reste
#   agent-env.sh status                     environnements, mémoire, budget
#   agent-env.sh budget                     budget_mo=<n> utilise_mo=<n> libre_mo=<n>
#
# Valeurs du projet : devteam.agent.conf à la racine du dépôt principal. Ressources : adaptateurs
# scripts/devteam-adaptateurs/<type>.sh <variables|creer|liberer> <lot> <paramètre>.
# Codes de sortie : 0 succès, 1 erreur, 2 usage, 75 pas de place (budget ou ressource épuisée) : réessayer plus tard.
# Rien n'est jamais supprimé automatiquement. Compatible bash 3.2.
set -euo pipefail

EX_PAS_DE_PLACE=75
LOCK_TIMEOUT="${AGENT_LOCK_TIMEOUT:-30}"
LOCK_SLEEP="${AGENT_LOCK_SLEEP:-1}"
HINT=""
LOCK_HELD=0
LOCK_DIR=""

die() { echo "agent-env : $*" >&2; exit 1; }
# Préfixe stable : `make` renvoie toujours 2 quand une recette échoue, le superviseur reconnaît donc « pas de place » à
# cette ligne quand il passe par `make agent-up`.
die_place() { echo "agent-env : pas de place : $*" >&2; exit "$EX_PAS_DE_PLACE"; }
warn() { echo "agent-env : avertissement : $*" >&2; }
info() { echo "agent-env : $*"; }

on_exit() {
  local rc=$?
  if [ "$LOCK_HELD" = 1 ]; then rmdir "$LOCK_DIR" 2>/dev/null || true; fi
  if [ "$rc" -ne 0 ] && [ -n "$HINT" ]; then echo "$HINT" >&2; fi
  return 0
}
trap on_exit EXIT

usage() {
  cat >&2 <<'EOF'
Usage :
  agent-env.sh up <lot> <profil> <base>
  agent-env.sh down <lot>
  agent-env.sh status
  agent-env.sh budget
EOF
  exit 2
}

# --- Dépôt et configuration -------------------------------------------------------------------------------------
charger() {
  GIT_COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "à lancer dans un dépôt git"
  MAIN_REPO="$(dirname "$GIT_COMMON")"
  PARENT_DIR="$(dirname "$MAIN_REPO")"
  LOCK_DIR="$GIT_COMMON/devteam-agent-env.lock"
  ADAPTATEURS="$MAIN_REPO/scripts/devteam-adaptateurs"
  local conf="$MAIN_REPO/devteam.agent.conf"
  [ -f "$conf" ] || die "configuration absente : $conf (voir devteam.agent.conf.exemple)"
  DEVTEAM_SERVICES_INFRA="" DEVTEAM_RESSOURCES="" DEVTEAM_LOT_MAX=40
  # Exportées : les adaptateurs lisent aussi la configuration (DEVTEAM_*)
  set -a
  # shellcheck disable=SC1090
  . "$conf"
  set +a
  local v
  for v in DEVTEAM_PROJET DEVTEAM_PROFILS DEVTEAM_STACK_MO DEVTEAM_MARGE_MO DEVTEAM_COMPOSE_FICHIERS DEVTEAM_PROJET_PRINCIPAL; do
    [ -n "${!v:-}" ] || die "$v absent de $conf"
  done
}

check_lot() {
  [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "lot invalide « $1 » (attendu : lettres minuscules, chiffres et tirets internes)"
  [ "${#1}" -le "$DEVTEAM_LOT_MAX" ] || die "lot invalide : plus de $DEVTEAM_LOT_MAX caractères (DEVTEAM_LOT_MAX)"
  case "$1" in test | e2e) die "lot réservé « $1 » (noms réservés : test, e2e)" ;; esac
}

check_profil() {
  case " $DEVTEAM_PROFILS " in
    *" $1 "*) ;;
    *) die "profil inconnu « $1 » ($DEVTEAM_PROFILS)" ;;
  esac
}

valeur_profil() { # <préfixe> <profil> : DEVTEAM_<préfixe>_<profil>
  local v="DEVTEAM_$1_$2"
  [ -n "${!v:-}" ] || die "$v absent de devteam.agent.conf"
  echo "${!v}"
}

cout_profil() {
  case " $DEVTEAM_PROFILS " in
    *" $1 "*) valeur_profil COUT_MO "$1" ;;
    *)
      local p max=0 c
      for p in $DEVTEAM_PROFILS; do c="$(valeur_profil COUT_MO "$p")"; [ "$c" -le "$max" ] || max="$c"; done
      echo "$max"
      ;;
  esac
}

wt_dir() { echo "$PARENT_DIR/$DEVTEAM_PROJET-wt-$1"; }
projet_agent() { echo "$DEVTEAM_PROJET-ag-$1"; }

# --- .agent.env ---------------------------------------------------------------------------------------------------
LIGNE_ENV='^export [A-Z_][A-Z0-9_]*=[A-Za-z0-9_.:/@+-]*$'

env_get() { sed -n "s/^export $2=//p" "$1" 2>/dev/null | awk 'NR == 1'; }

env_valide() { # <fichier> <lot>
  [ -f "$1" ] || return 1
  # Sans tube : un « grep -q » en aval sortirait tôt et le SIGPIPE en amont ferait passer un fichier invalide
  if grep -vE "$LIGNE_ENV" "$1" >/dev/null; then return 1; fi
  [ "$(env_get "$1" AGENT_LOT)" = "$2" ]
}

envs_actifs() { # [lot à exclure] : .agent.env des lots réservés (AGENT_ACTIF=1), un par ligne
  local f
  for f in "$PARENT_DIR/$DEVTEAM_PROJET"-wt-*/.agent.env; do
    [ -f "$f" ] || continue
    [ "$(env_get "$f" AGENT_LOT)" = "${1:-}" ] && continue
    [ "$(env_get "$f" AGENT_ACTIF)" = "1" ] || continue
    echo "$f"
  done
}

compose_agent() { # <lot> <args…>
  local lot="$1" wt f
  shift
  wt="$(wt_dir "$lot")"
  local args=(-p "$(projet_agent "$lot")")
  for f in $DEVTEAM_COMPOSE_FICHIERS; do args+=(-f "$f"); done
  (
    set -a
    # shellcheck disable=SC1091
    . "$wt/.agent.env"
    set +a
    cd "$wt"
    docker compose "${args[@]}" "$@"
  )
}

# --- Docker -------------------------------------------------------------------------------------------------------
service_principal() { # <service>
  docker ps --filter "label=com.docker.compose.project=$DEVTEAM_PROJET_PRINCIPAL" \
    --filter "label=com.docker.compose.service=$1" --filter status=running --format '{{.Names}}' | awk 'NR == 1'
}

projet_actif() { [ -n "$(docker ps -q --filter "label=com.docker.compose.project=$(projet_agent "$1")")" ]; }

docker_mem_mo() {
  local octets
  octets="$(docker info --format '{{.MemTotal}}')"
  echo $((octets / 1048576))
}

budget_mo() { echo $(($(docker_mem_mo) - DEVTEAM_STACK_MO - DEVTEAM_MARGE_MO)); }

utilise_mo() { # [lot à exclure]
  local total=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    total=$((total + $(cout_profil "$(env_get "$f" AGENT_PROFIL)")))
  done < <(envs_actifs "${1:-}")
  echo "$total"
}

mem_projet_mo() { # <projet compose>
  local ids
  ids="$(docker ps -q --filter "label=com.docker.compose.project=$1")"
  [ -n "$ids" ] || { echo 0; return 0; }
  # shellcheck disable=SC2086
  docker stats --no-stream --format '{{.MemUsage}}' $ids 2>/dev/null |
    awk '{ v=$1; if (v ~ /GiB$/) { sub(/GiB/,"",v); s+=v*1024 } else if (v ~ /MiB$/) { sub(/MiB/,"",v); s+=v } else if (v ~ /KiB$/) { sub(/KiB/,"",v); s+=v/1024 } } END { printf "%d", s }'
}

# --- Verrou -------------------------------------------------------------------------------------------------------
acquire_lock() {
  local i=0
  until mkdir "$LOCK_DIR" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -le "$LOCK_TIMEOUT" ] || die "verrou $LOCK_DIR toujours tenu après $LOCK_TIMEOUT s (un autre agent-up ? sinon rmdir le dossier)"
    sleep "$LOCK_SLEEP"
  done
  LOCK_HELD=1
}

release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
  LOCK_HELD=0
}

# --- Ressources ---------------------------------------------------------------------------------------------------
# Une ressource « <type>:<paramètre> » ; {lot} est remplacé dans le paramètre
ressource_type() { echo "${1%%:*}"; }
ressource_param() { # <ressource> <lot>
  local p=""
  case "$1" in *:*) p="${1#*:}" ;; esac
  echo "${p//\{lot\}/$2}"
}

adaptateur() { # <type> <action> <lot> <paramètre>
  local f="$ADAPTATEURS/$1.sh"
  [ -x "$f" ] || die "adaptateur introuvable ou non exécutable : $f"
  "$f" "$2" "$3" "$4"
}

# Variables des ressources du lot (sous verrou) ; 75 si une ressource est épuisée
variables_ressources() { # <lot>
  local lot="$1" r rc sortie
  DEVTEAM_ENVS_ACTIFS="$(envs_actifs "$lot")"
  DEVTEAM_ENV_LOT=""
  [ ! -f "$(wt_dir "$lot")/.agent.env" ] || DEVTEAM_ENV_LOT="$(wt_dir "$lot")/.agent.env"
  export DEVTEAM_ENVS_ACTIFS DEVTEAM_ENV_LOT
  for r in $DEVTEAM_RESSOURCES; do
    rc=0
    sortie="$(adaptateur "$(ressource_type "$r")" variables "$lot" "$(ressource_param "$r" "$lot")")" || rc=$?
    [ "$rc" -ne "$EX_PAS_DE_PLACE" ] || die_place "ressource $r épuisée : attendre la fin d'un lot (« make agent-status »)"
    [ "$rc" -eq 0 ] || die "adaptateur $(ressource_type "$r") en échec (code $rc) pour le lot $lot"
    if [ -n "$sortie" ] && printf '%s\n' "$sortie" | grep -vE "$LIGNE_ENV" >/dev/null; then
      die "adaptateur $(ressource_type "$r") : sortie invalide (attendu : lignes « export NOM=valeur » sans caractère spécial)"
    fi
    [ -z "$sortie" ] || printf '%s\n' "$sortie"
  done
}

# --- Sous-commandes -----------------------------------------------------------------------------------------------
preambule() { # <base>
  local svc f
  command -v docker >/dev/null || die "docker introuvable"
  docker info >/dev/null 2>&1 || die "le démon Docker ne répond pas"
  for svc in $DEVTEAM_SERVICES_INFRA; do
    [ -n "$(service_principal "$svc")" ] || die "la stack principale ne tourne pas (service $svc absent du projet $DEVTEAM_PROJET_PRINCIPAL)"
  done
  git rev-parse --verify --quiet --end-of-options "$1^{commit}" >/dev/null || die "branche de base « $1 » introuvable"
  for f in $DEVTEAM_COMPOSE_FICHIERS; do
    git cat-file -e "$1:$f" 2>/dev/null || die "$1 ne contient pas $f (fichier Compose déclaré dans DEVTEAM_COMPOSE_FICHIERS)"
  done
}

cmd_up() {
  [ $# -eq 3 ] || usage
  local lot="$1" profil="$2" base="$3"
  charger
  check_lot "$lot"
  check_profil "$profil"
  case "$base" in -* | "") die "base invalide « $base »" ;; esac
  local wt branch services cout
  wt="$(wt_dir "$lot")"
  branch="$base-$lot"
  services="$(valeur_profil SERVICES "$profil")"
  cout="$(cout_profil "$profil")"

  preambule "$base"
  projet_actif "$lot" && die "lot « $lot » déjà actif (projet $(projet_agent "$lot")) : « make agent-down LOT=$lot » pour l'arrêter"

  local reprise=0 creer=0
  if [ -d "$wt" ]; then
    if [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)" = "$branch" ]; then
      reprise=1
    else
      die "le dossier $wt existe déjà sur une autre branche : l'examiner, puis « git worktree remove $wt » si c'est un reste"
    fi
  elif git show-ref --verify --quiet "refs/heads/$branch"; then
    die "la branche $branch existe déjà sans worktree : « git worktree add $wt $branch » pour la reprendre, ou « git branch -d $branch » si c'est un reste"
  else
    creer=1
  fi

  # Réservation sous verrou : budget, ressources, puis seulement le worktree et .agent.env
  local budget utilise variables
  acquire_lock
  budget="$(budget_mo)"
  utilise="$(utilise_mo "$lot")"
  if [ $((utilise + cout)) -gt "$budget" ]; then
    die_place "budget mémoire dépassé : profil $profil = $cout Mo, déjà utilisés $utilise Mo, budget $budget Mo (libre $((budget - utilise)) Mo). Attendre la fin d'un lot (« make agent-status »)"
  fi
  variables="$(variables_ressources "$lot")"
  if [ "$creer" = 1 ]; then
    git worktree add -q -b "$branch" "$wt" "$base"
    info "worktree $wt créé sur $branch"
  fi
  # .agent.env n'est jamais commité : exclusion locale, partagée par tous les worktrees, non versionnée
  mkdir -p "$GIT_COMMON/info"
  grep -qx '.agent.env' "$GIT_COMMON/info/exclude" 2>/dev/null || echo '.agent.env' >> "$GIT_COMMON/info/exclude"
  HINT="agent-env : échec. Reprise : make agent-up LOT=$lot PROFIL=$profil BASE=$base (idempotent). Nettoyage : make agent-down LOT=$lot puis git worktree remove --force $wt && git branch -D $branch (rien n'a été supprimé automatiquement)."
  {
    echo "export AGENT_LOT=$lot"
    echo "export AGENT_PROFIL=$profil"
    echo "export AGENT_ACTIF=1"
    [ -z "$variables" ] || printf '%s\n' "$variables"
  } > "$wt/.agent.env"
  release_lock

  local r
  for r in $DEVTEAM_RESSOURCES; do
    adaptateur "$(ressource_type "$r")" creer "$lot" "$(ressource_param "$r" "$lot")"
  done

  info "démarrage des conteneurs ($services)"
  # shellcheck disable=SC2086
  if ! compose_agent "$lot" up -d --wait $services; then
    # shellcheck disable=SC2086
    compose_agent "$lot" logs --tail 50 $services >&2 || true
    die "les conteneurs de l'agent ne sont pas sains (logs ci-dessus)"
  fi
  HINT=""
  cat <<EOF

Environnement d'agent prêt
  lot        $lot (profil $profil, coût déclaré $cout Mo)
  worktree   $wt
  branche    $branch$([ "$reprise" = 1 ] && echo " (reprise)")
  projet     $(projet_agent "$lot")
  ressources ${DEVTEAM_RESSOURCES:-aucune}
  ensuite    cd $wt && make test-cible T=… | make coverage-diff BASE=…
EOF
}

cmd_down() {
  [ $# -eq 1 ] || usage
  local lot="$1" wt env r
  charger
  check_lot "$lot"
  wt="$(wt_dir "$lot")"
  env="$wt/.agent.env"
  [ -f "$env" ] || die "lot « $lot » inconnu (pas de $env) : rien à arrêter"
  env_valide "$env" "$lot" || die ".agent.env corrompu ($env : attendu AGENT_LOT=$lot et uniquement des lignes « export NOM=valeur ») : rien n'a été arrêté ni libéré"
  if [ "$(env_get "$env" AGENT_ACTIF)" != "1" ]; then
    # Déjà arrêté : ses ressources ont pu être réattribuées à un autre lot depuis ; ne rien libérer une deuxième fois
    info "lot $lot déjà arrêté : rien à faire"
    return 0
  fi

  compose_agent "$lot" down -v --remove-orphans

  acquire_lock
  DEVTEAM_ENVS_ACTIFS="$(envs_actifs "$lot")"
  export DEVTEAM_ENV_LOT="$env" DEVTEAM_ENVS_ACTIFS
  for r in $DEVTEAM_RESSOURCES; do
    adaptateur "$(ressource_type "$r")" liberer "$lot" "$(ressource_param "$r" "$lot")" ||
      warn "libération de $r en échec pour le lot $lot (à faire à la main)"
  done
  sed 's/^export AGENT_ACTIF=1$/export AGENT_ACTIF=0/' "$env" > "$env.tmp" && mv "$env.tmp" "$env"
  release_lock

  cat <<EOF

Lot $lot arrêté. Conservés : worktree $wt, branche, données des ressources (${DEVTEAM_RESSOURCES:-aucune}), .agent.env.
Nettoyage final, à lancer à la main une fois le lot fusionné :
  git worktree remove --force $wt && git branch -d <branche-du-lot>
  puis supprimer les données des ressources du lot (bases, buckets) selon leurs adaptateurs.
EOF
}

cmd_budget() {
  local budget utilise
  budget="$(budget_mo)"
  utilise="$(utilise_mo "")"
  echo "budget_mo=$budget utilise_mo=$utilise libre_mo=$((budget - utilise))"
}

cmd_status() {
  local f lot profil etat n=0
  for f in "$PARENT_DIR/$DEVTEAM_PROJET"-wt-*/.agent.env; do
    [ -f "$f" ] || continue
    lot="$(env_get "$f" AGENT_LOT)"
    profil="$(env_get "$f" AGENT_PROFIL)"
    if projet_actif "$lot"; then
      etat="actif, $(mem_projet_mo "$(projet_agent "$lot")") Mo"
    elif [ "$(env_get "$f" AGENT_ACTIF)" = "1" ]; then
      etat="réservé, conteneurs arrêtés"
    else
      continue
    fi
    n=$((n + 1))
    echo "lot=$lot profil=$profil $etat worktree=$(dirname "$f")"
  done
  [ "$n" -gt 0 ] || echo "Aucun environnement d'agent."
  cmd_budget
}

[ $# -ge 1 ] || usage
sous_commande="$1"
shift
case "$sous_commande" in
  up) cmd_up "$@" ;;
  down) cmd_down "$@" ;;
  status) [ $# -eq 0 ] || usage; charger; cmd_status ;;
  budget) [ $# -eq 0 ] || usage; charger; cmd_budget ;;
  *) usage ;;
esac
