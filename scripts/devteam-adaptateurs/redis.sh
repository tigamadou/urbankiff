#!/usr/bin/env bash
# Adaptateur d'exemple devteam : des numéros de base Redis propres au lot (2 à 15 ; 0 et 1 restent à la stack
# principale). Copier dans scripts/devteam-adaptateurs/ et ajuster. Ressource : redis:<nombre de numéros> (ex. redis:2).
# Variables écrites : REDIS_DB_1 … REDIS_DB_<n>. Variables lues : DEVTEAM_PROJET_PRINCIPAL, DEVTEAM_REDIS_SERVICE
# (défaut redis), DEVTEAM_ENVS_ACTIFS et DEVTEAM_ENV_LOT (fournies par le moteur).
set -euo pipefail

action="${1:-}" lot="${2:-}" n="${3:-1}"
SERVICE="${DEVTEAM_REDIS_SERVICE:-redis}"
EX_PAS_DE_PLACE=75

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <nombre de numéros>" >&2; exit 2 ;; esac
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "redis : nombre de numéros invalide « $n »" >&2; exit 1; }

numeros() { # <fichier .agent.env> : ses numéros Redis
  [ -f "$1" ] || return 0
  sed -n 's/^export REDIS_DB_[0-9][0-9]*=//p' "$1"
}

valide() { [[ "$1" =~ ^([2-9]|1[0-5])$ ]]; }

case "$action" in
  variables)
    pris=" "
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      for k in $(numeros "$f"); do pris="$pris$k "; done
    done <<< "${DEVTEAM_ENVS_ACTIFS:-}"
    choisis=""
    # Reprise : les numéros précédents du lot, s'ils sont tous valides et libres
    precedents="$(numeros "${DEVTEAM_ENV_LOT:-}" | tr '\n' ' ')"
    if [ -n "${precedents// /}" ] && [ "$(echo $precedents | wc -w | tr -d ' ')" = "$n" ]; then
      choisis="$precedents"
      for k in $precedents; do
        if ! valide "$k" || case "$pris" in *" $k "*) true ;; *) false ;; esac; then choisis=""; break; fi
      done
    fi
    if [ -z "${choisis// /}" ]; then
      choisis=""
      k=2
      while [ "$k" -le 15 ] && [ "$(echo $choisis | wc -w | tr -d ' ')" -lt "$n" ]; do
        case "$pris" in *" $k "*) ;; *) choisis="$choisis$k " ;; esac
        k=$((k + 1))
      done
      [ "$(echo $choisis | wc -w | tr -d ' ')" -eq "$n" ] || { echo "redis : plus de numéro libre (2 à 15)" >&2; exit "$EX_PAS_DE_PLACE"; }
    fi
    i=1
    for k in $choisis; do echo "export REDIS_DB_$i=$k"; i=$((i + 1)); done
    ;;
  creer) ;; # rien à créer : les numéros existent déjà
  liberer)
    mes="$(numeros "${DEVTEAM_ENV_LOT:-}")"
    for k in $mes; do valide "$k" || { echo "redis : numéro « $k » hors 2..15 dans ${DEVTEAM_ENV_LOT:-} : rien n'est vidé" >&2; exit 1; }; done
    autres=" "
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      for k in $(numeros "$f"); do autres="$autres$k "; done
    done <<< "${DEVTEAM_ENVS_ACTIFS:-}"
    for k in $mes; do
      case "$autres" in *" $k "*) echo "redis : numéro $k tenu par un autre lot actif : rien n'est vidé" >&2; exit 1 ;; esac
    done
    [ -n "$mes" ] || exit 0
    c="$(docker ps --filter "label=com.docker.compose.project=$DEVTEAM_PROJET_PRINCIPAL" \
      --filter "label=com.docker.compose.service=$SERVICE" --filter status=running --format '{{.Names}}' | awk 'NR == 1')"
    [ -n "$c" ] || { echo "redis : service $SERVICE absent : numéros $mes à vider à la main" >&2; exit 1; }
    for k in $mes; do docker exec "$c" redis-cli -n "$k" FLUSHDB >/dev/null; done
    echo "redis : numéros $(echo $mes) vidés (lot $lot)"
    ;;
esac
