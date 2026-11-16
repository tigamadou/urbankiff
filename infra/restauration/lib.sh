#!/usr/bin/env bash
# Bibliothèque commune des scripts de restauration. À charger avec `.` ; ne fixe aucune option du shell.
# Tout conteneur et tout réseau créés portent l'étiquette urbankiff.restauration=<identifiant d'exécution> et sont
# supprimés par `nettoyer` (à brancher sur `trap` avec `installer_nettoyage`).

PG_CLIENT_IMAGE="${PG_CLIENT_IMAGE:-postgres:17.2}"
PG_MAJEURE_MAX="${PG_MAJEURE_MAX:-17}"
IMAGE_OUTILS="${IMAGE_OUTILS:-urbankiff-restauration-outils:1}"
RESTAURATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAPPORTS_DIR="${RAPPORTS_DIR:-$RESTAURATION_DIR/rapports}"
REST_ID="${REST_ID:-$$-$(date +%s)-$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
REST_LABEL="urbankiff.restauration=$REST_ID"
REST_RESEAU="urbankiff-rest-$REST_ID"

erreur() {
  echo "Erreur : $*" >&2
}

conteneur() {
  echo "rest-$REST_ID-$1"
}

# Version complète (ex. 15.4) lue dans l'en-tête du dump ; échoue avec un message clair si le dump est absent,
# illisible ou plus récent que le client épinglé.
version_pg_du_dump() {
  local dump="${1:-}" sortie version
  if [ -z "$dump" ] || [ ! -f "$dump" ] || [ ! -r "$dump" ]; then
    erreur "dump introuvable ou illisible : ${dump:-<vide>}"
    return 1
  fi
  if ! sortie=$(docker run --rm -i --network none "$PG_CLIENT_IMAGE" pg_restore -l < "$dump" 2>&1); then
    case "$sortie" in
      *"unsupported version"*) erreur "dump plus récent que le client PostgreSQL épinglé ($PG_CLIENT_IMAGE) : $dump" ;;
      *) erreur "dump illisible (format custom attendu) : $dump" ;;
    esac
    return 1
  fi
  version=$(printf '%s\n' "$sortie" | sed -n 's/^; *Dumped from database version:\{0,1\} \([0-9][0-9.]*\).*/\1/p' | head -n 1)
  if [ -z "$version" ]; then
    erreur "version PostgreSQL absente de l'en-tête du dump : $dump"
    return 1
  fi
  printf '%s\n' "$version"
}

verifier_version_supportee() {
  local majeure="${1%%.*}"
  if [ "$majeure" -gt "$PG_MAJEURE_MAX" ]; then
    erreur "dump PostgreSQL $1 plus récent que la version disponible épinglée ($PG_MAJEURE_MAX)"
    return 1
  fi
}

nettoyer() {
  local ids
  ids=$(docker ps -aq --filter "label=$REST_LABEL" 2> /dev/null || true)
  if [ -n "$ids" ]; then
    # shellcheck disable=SC2086
    docker rm -fv $ids > /dev/null 2>&1 || true
  fi
  docker network rm "$REST_RESEAU" > /dev/null 2>&1 || true
}

installer_nettoyage() {
  trap nettoyer EXIT
  trap 'exit 130' INT TERM
}

creer_reseau() {
  if [ -z "${REST_RESEAU_CREE:-}" ]; then
    docker network create --internal --label "$REST_LABEL" "$REST_RESEAU" > /dev/null
    REST_RESEAU_CREE=1
  fi
}

# Mot de passe jetable : variable d'environnement exportée, jamais écrite sur disque ni passée en argument.
mot_de_passe_jetable() {
  if [ -z "${REST_MDP:-}" ]; then
    REST_MDP=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
    export REST_MDP
  fi
}

attendre_base() {
  local i
  for i in $(seq 1 90); do
    if docker exec "$(conteneur "$1")" pg_isready -h 127.0.0.1 -U postgres -d app -q > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  erreur "la base jetable $1 n'a pas démarré"
  return 1
}

# demarrer_base_jetable <majeure> <nom> : PostgreSQL sur le réseau interne, aucun port publié, base « app ».
demarrer_base_jetable() {
  creer_reseau
  mot_de_passe_jetable
  POSTGRES_PASSWORD="$REST_MDP" docker run -d --name "$(conteneur "$2")" --network "$REST_RESEAU" --label "$REST_LABEL" \
    -e POSTGRES_PASSWORD -e POSTGRES_DB=app "postgres:$1" > /dev/null
  attendre_base "$2"
}

psql_base() {
  local nom="$1"
  shift
  docker exec -i "$(conteneur "$nom")" psql -U postgres -d app -X -q -v ON_ERROR_STOP=1 "$@"
}

# restaurer_dump <nom> <dump> [options pg_restore] : le dump est lu en entrée standard, jamais monté en écriture.
restaurer_dump() {
  local nom="$1" dump="$2"
  shift 2
  docker exec -i "$(conteneur "$nom")" pg_restore -U postgres -d app "$@" < "$dump"
}

# decomptes_tables <nom> [schema] : lignes « schema.table|décompte exact » des tables hors schémas système.
decomptes_tables() {
  local filtre="true"
  if [ -n "${2:-}" ]; then
    filtre="table_schema = '$2'"
  fi
  psql_base "$1" -At -F'|' -c "
    select table_schema || '.' || table_name,
           (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text
    from information_schema.tables
    where table_type = 'BASE TABLE' and table_schema not in ('pg_catalog', 'information_schema') and $filtre
    order by 1"
}

# comparer_decomptes <source> <cible> : fichiers de lignes « table|n » ; affiche les écarts « table|source|cible »
# (« absente » pour une table manquante d'un côté) et retourne 1 s'il y en a.
comparer_decomptes() {
  local ecarts
  ecarts=$(awk -F'|' '
    FILENAME == ARGV[1] { s[$1] = $2; next }
    { c[$1] = $2 }
    END {
      for (t in s) { if (!(t in c)) print t "|" s[t] "|absente"; else if (s[t] != c[t]) print t "|" s[t] "|" c[t] }
      for (t in c) if (!(t in s)) print t "|absente|" c[t]
    }' "$1" "$2" | sort)
  if [ -z "$ecarts" ]; then
    return 0
  fi
  printf '%s\n' "$ecarts"
  return 1
}

# ecrire_rapport <nom> : lit le rapport sur l'entrée standard et affiche son chemin.
ecrire_rapport() {
  local fichier
  mkdir -p "$RAPPORTS_DIR"
  fichier="$RAPPORTS_DIR/$(date +%F)-$1.md"
  cat > "$fichier"
  printf '%s\n' "$fichier"
}

# tableau <en-tête>... : lit des lignes « a|b » et écrit un tableau Markdown, ou « Aucun. » si l'entrée est vide.
tableau() {
  local lignes h
  lignes=$(cat)
  if [ -z "$lignes" ]; then
    echo "Aucun."
    return 0
  fi
  printf '|'
  for h in "$@"; do printf ' %s |' "$h"; done
  printf '\n|'
  for h in "$@"; do printf ' --- |'; done
  printf '\n'
  printf '%s\n' "$lignes" | awk -F'|' '{ printf "|"; for (i = 1; i <= NF; i++) printf " %s |", $i; print "" }'
}

image_outils() {
  docker build -q -t "$IMAGE_OUTILS" - > /dev/null << 'DOCKERFILE'
FROM alpine:3.20
RUN apk add --no-cache file
DOCKERFILE
}

# analyser_bucket <dossier> : le dossier est lu par `tar` (jamais modifié) et extrait dans un conteneur sans réseau.
analyser_bucket() {
  if [ ! -d "$1" ]; then
    erreur "dossier de bucket introuvable : $1"
    return 1
  fi
  image_outils
  COPYFILE_DISABLE=1 tar -C "$1" -cf - . | docker run --rm -i --network none --label "$REST_LABEL" "$IMAGE_OUTILS" \
    sh -c "$(printf 'set -e\nmkdir /b\ntar -xf - -C /b\n'; cat "$RESTAURATION_DIR/analyser-bucket.sh")"
}

# tableau_comparaison <source> <cible> : tableau Markdown table | source | restauré | égal.
tableau_comparaison() {
  awk -F'|' '
    FILENAME == ARGV[1] { s[$1] = $2; next }
    { c[$1] = $2 }
    END {
      for (t in s) print t "|" s[t] "|" ((t in c) ? c[t] : "absente") "|" (((t in c) && c[t] == s[t]) ? "oui" : "NON")
      for (t in c) if (!(t in s)) print t "|absente|" c[t] "|NON"
    }' "$1" "$2" | sort | tableau "Table" "Source" "Restauré" "Égal"
}

# conclure_comparaison <source> <cible> : message final ; retourne 1 s'il y a un écart ou si la source est vide.
conclure_comparaison() {
  local ecarts
  if [ ! -s "$1" ]; then
    echo "Restauration répétée : aucune table dans le schéma public de la source"
    return 1
  fi
  if ecarts=$(comparer_decomptes "$1" "$2"); then
    echo "Restauration répétée : décomptes égaux"
    return 0
  fi
  echo "Restauration répétée : écarts sur les tables suivantes"
  printf '%s\n' "$ecarts" | awk -F'|' '{ print "- " $1 " (source " $2 ", restauré " $3 ")" }'
  return 1
}
