#!/usr/bin/env bash
# Adaptateur d'exemple devteam : une base PostgreSQL par lot dans le service de la stack principale.
# Copier dans scripts/devteam-adaptateurs/ et ajuster. Ressource : postgres:<nom de base> (ex. postgres:monprojet_{lot}).
# Variable écrite : AGENT_DB_NAME (et non DB_NAME, déjà pris par le .env racine). Variables lues : DEVTEAM_PROJET_PRINCIPAL,
# DEVTEAM_PG_SERVICE (défaut postgres), DEVTEAM_PG_USER (défaut : POSTGRES_USER lu dans le conteneur à l'exécution).
set -euo pipefail

action="${1:-}" lot="${2:-}" nom="${3:-}"
SERVICE="${DEVTEAM_PG_SERVICE:-postgres}"
UTILISATEUR="${DEVTEAM_PG_USER:-}"

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <nom de base>" >&2; exit 2 ;; esac
[[ "$nom" =~ ^[a-z0-9_]{1,63}$ ]] || { echo "postgres : nom de base invalide « $nom » (a-z, 0-9, _ ; 63 caractères au plus)" >&2; exit 1; }

conteneur() {
  local c
  c="$(docker ps --filter "label=com.docker.compose.project=$DEVTEAM_PROJET_PRINCIPAL" \
    --filter "label=com.docker.compose.service=$SERVICE" --filter status=running --format '{{.Names}}' | awk 'NR == 1')"
  [ -n "$c" ] || { echo "postgres : service $SERVICE absent de la stack principale" >&2; exit 1; }
  echo "$c"
}

case "$action" in
  variables) echo "export AGENT_DB_NAME=$nom" ;;
  creer)
    c="$(conteneur)"
    [ -n "$UTILISATEUR" ] || UTILISATEUR="$(docker exec "$c" printenv POSTGRES_USER)"
    if [ "$(docker exec "$c" psql -U "$UTILISATEUR" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$nom'")" = "1" ]; then
      echo "postgres : base $nom déjà présente (réutilisée)"
    else
      docker exec "$c" psql -U "$UTILISATEUR" -d postgres -qc "CREATE DATABASE \"$nom\"" >/dev/null
      echo "postgres : base $nom créée (lot $lot)"
    fi
    ;;
  liberer) ;; # la base est conservée jusqu'au nettoyage final
esac
