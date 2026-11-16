#!/usr/bin/env bash
# Définit les secrets et variables GitHub d'un environnement (spec : docs/v1/specs/2026-11-16-publication-depot-public.md).
#
#   definir-secrets.sh <prod|preprod> <owner/depot>
#
# Secrets : scripts/secrets/secrets.txt (« NOM TYPE », TYPE = aleatoire:<n>, aleatoire-hex:<n> ou saisie).
# Variables non secrètes : scripts/secrets/variables-<env>.txt (« NOM=valeur »).
# Une valeur de secret ne passe jamais en argument, n'est jamais exportée, affichée ni écrite sur disque : elle va de
# son générateur (ou de la saisie masquée) à `gh secret set` par un tube.
# SEULEMENT="NOM1 NOM2" limite les noms (re)définis. Saisie vide : secret laissé tel quel. Un secret aléatoire déjà
# présent est conservé, sauf s il est nommé dans SEULEMENT ou avec FORCER=1.
# Codes : 0 tout est présent dans GitHub, 1 erreur ou nom attendu absent, 2 usage.
set -euo pipefail

DOSSIER="$(cd "$(dirname "$0")" && pwd)"
LISTE="${SECRETS_LISTE:-$DOSSIER/secrets.txt}"
VARIABLES="${VARIABLES_DOSSIER:-$DOSSIER}"
TTY="${SECRETS_TTY:-/dev/tty}"

usage() { echo "usage : definir-secrets.sh <prod|preprod> <owner/depot>" >&2; exit 2; }

env="${1:-}"
repo="${2:-}"
case "$env" in prod|preprod) ;; *) usage ;; esac
[ -n "$repo" ] || usage
fichier_variables="$VARIABLES/variables-$env.txt"
[ -f "$LISTE" ] || { echo "liste des secrets introuvable : $LISTE" >&2; exit 1; }
[ -f "$fichier_variables" ] || { echo "variables introuvables : $fichier_variables" >&2; exit 1; }

retenu() { [ -z "${SEULEMENT:-}" ] || [[ " $SEULEMENT " == *" $1 "* ]]; }

generer() { # <alphabet> <longueur> : écrit la valeur sur la sortie standard, sans retour à la ligne
  if [ -n "${GENERATEUR:-}" ]; then
    "$GENERATEUR" "$1" "$2"
  else
    docker run --rm --log-driver none --network none alpine:3.20 sh -c "tr -dc '$1' < /dev/urandom | head -c $2"
  fi
}

poser() { gh secret set "$1" --env "$env" --repo "$repo"; }

poser_genere() { # <nom> <alphabet> <longueur> : ne transmet qu'une valeur complète
  local valeur
  if ! valeur="$(generer "$2" "$3")" || [ "${#valeur}" -ne "$3" ]; then
    echo "génération en échec pour $1 : rien n'est posé, arrêt" >&2
    exit 1
  fi
  printf '%s' "$valeur" | poser "$1"
}

# Un secret aléatoire déjà présent n'est régénéré que s'il est nommé dans SEULEMENT ou avec FORCER=1 : le régénérer en
# silence casserait un service déjà configuré avec l'ancienne valeur (mot de passe de base, clé Django…).
deja_presents=" $(gh secret list --env "$env" --repo "$repo" --json name -q '.[].name' | tr '\n' ' ') "
a_regenerer() { [ "${FORCER:-}" = 1 ] || [[ " ${SEULEMENT:-} " == *" $1 "* ]] || [[ "$deja_presents" != *" $1 "* ]]; }

attendus=""
while read -r nom type; do
  [ -n "$nom" ] && [ "${nom#\#}" = "$nom" ] || continue
  attendus="$attendus secret:$nom"
  retenu "$nom" || continue
  case "$type" in
    aleatoire*)
      if ! a_regenerer "$nom"; then
        echo "déjà présent, conservé : secret $nom ($env) (FORCER=1 ou SEULEMENT=$nom pour le régénérer)"
        continue
      fi
      ;;
  esac
  case "$type" in
    aleatoire:*) poser_genere "$nom" 'A-Za-z0-9' "${type#*:}" ;;
    aleatoire-hex:*) poser_genere "$nom" 'a-f0-9' "${type#*:}" ;;
    saisie)
      printf '%s (%s, vide = inchangé) : ' "$nom" "$env" > /dev/stderr
      if ! IFS= read -rs valeur < "$TTY"; then
        echo >&2
        echo "saisie interrompue sur $nom : rien n'est posé pour ce secret, arrêt" >&2
        exit 1
      fi
      echo >&2
      if [ -z "$valeur" ]; then
        echo "inchangé : $nom" >&2
        continue
      fi
      printf '%s' "$valeur" | poser "$nom"
      unset valeur
      ;;
    *) echo "type inconnu pour $nom : $type" >&2; exit 1 ;;
  esac
  echo "posé : secret $nom ($env)"
done < "$LISTE"

while IFS= read -r ligne; do
  [ -n "$ligne" ] && [ "${ligne#\#}" = "$ligne" ] || continue
  nom="${ligne%%=*}"
  attendus="$attendus variable:$nom"
  retenu "$nom" || continue
  gh variable set "$nom" --env "$env" --repo "$repo" --body "${ligne#*=}"
  echo "posé : variable $nom ($env)"
done < "$fichier_variables"

secrets_presents=" $(gh secret list --env "$env" --repo "$repo" --json name -q '.[].name' | tr '\n' ' ') "
variables_presentes=" $(gh variable list --env "$env" --repo "$repo" --json name -q '.[].name' | tr '\n' ' ') "
manquants=""
for a in $attendus; do
  nom="${a#*:}"
  case "$a" in
    secret:*) [[ "$secrets_presents" == *" $nom "* ]] || manquants="$manquants $nom" ;;
    variable:*) [[ "$variables_presentes" == *" $nom "* ]] || manquants="$manquants $nom" ;;
  esac
done
if [ -n "$manquants" ]; then
  echo "absents de l'environnement $env :$manquants" >&2
  exit 1
fi
echo "environnement $env complet"
