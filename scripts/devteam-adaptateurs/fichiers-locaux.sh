#!/usr/bin/env bash
# Adaptateur devteam d'Urbankiff : copie dans le worktree d'un lot les fichiers locaux ignorés par git (.env) dont
# compose.agent.yml a besoin (chemins des applications, identifiants de développement). Ressource :
# fichiers-locaux:<chemin>,<chemin>… (chemins relatifs à la racine du dépôt principal). Un fichier déjà présent dans le
# worktree n'est jamais écrasé. Variables lues : DEVTEAM_PROJET (le worktree du lot est ../<projet>-wt-<lot>, comme
# dans agent-env.sh).
set -euo pipefail

action="${1:-}" lot="${2:-}" liste="${3:-}"

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <chemin>,<chemin>…" >&2; exit 2 ;; esac
[ -n "$liste" ] || { echo "fichiers-locaux : liste de chemins vide" >&2; exit 1; }
[ "$action" = creer ] || exit 0

commun="$(git rev-parse --path-format=absolute --git-common-dir)"
principal="$(dirname "$commun")"
wt="$(dirname "$principal")/${DEVTEAM_PROJET:?DEVTEAM_PROJET absent}-wt-$lot"
[ -d "$wt" ] || { echo "fichiers-locaux : worktree $wt introuvable" >&2; exit 1; }

IFS=',' read -r -a chemins <<< "$liste"
for c in "${chemins[@]}"; do
  case "$c" in "" | /* | *..*) echo "fichiers-locaux : chemin invalide « $c » (relatif, sans ..)" >&2; exit 1 ;; esac
  [ -f "$principal/$c" ] || { echo "fichiers-locaux : $principal/$c absent du dépôt principal" >&2; exit 1; }
  if [ -e "$wt/$c" ]; then
    echo "fichiers-locaux : $c déjà présent (conservé)"
  else
    mkdir -p "$(dirname "$wt/$c")"
    cp "$principal/$c" "$wt/$c"
    echo "fichiers-locaux : $c copié (lot $lot)"
  fi
done
