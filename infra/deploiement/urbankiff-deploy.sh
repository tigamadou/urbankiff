#!/usr/bin/env bash
# Point d'entrée unique du compte `deploy` (commande forcée SSH) : docs/v1/infra/deploiement.md.
#
#   urbankiff-deploy <prod|preprod>      avec SSH_ORIGINAL_COMMAND = deploy <version> | preprod-arret | preprod-demarrage
#
# L'environnement vient du premier argument, fixé par authorized_keys : le client ne peut pas le choisir. Le script ne
# lit rien de l'environnement SSH (le compte est en `restrict`), sauf les variables URBANKIFF_* des tests.
# Entrée standard facultative `NOM=valeur` (secrets et variables) pour `deploy` : voir plus bas. Aucune valeur n'est
# jamais passée en argument, journalisée ni écrite sur disque.
# Codes : 0 succès, 1 erreur, 2 commande refusée.
set -euo pipefail
umask 077
export LC_ALL=C

CONFIG_DIR="${URBANKIFF_CONFIG_DIR:-/etc/urbankiff}"
LOCK_FILE="${URBANKIFF_LOCK_FILE:-/var/lock/urbankiff-deploy.lock}"

log() { printf '%s urbankiff-deploy : %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
die() { log "erreur : $*"; exit 1; }
refuser() { log "commande refusée : $*"; exit 2; }

analyser_commande() {
  local commande="${SSH_ORIGINAL_COMMAND:-}"
  [ "${#commande}" -le 100 ] || refuser "commande trop longue"
  local semver='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'
  if [[ "$commande" =~ ^deploy\ v?($semver)$ ]]; then
    COMMANDE=deploy
    VERSION="${BASH_REMATCH[1]}"
  elif [ "$commande" = preprod-arret ] || [ "$commande" = preprod-demarrage ]; then
    COMMANDE="$commande"
  else
    refuser "attendu : deploy <version>, preprod-arret ou preprod-demarrage"
  fi
}

lire_configuration() {
  case "$1" in prod|preprod) ENV="$1" ;; *) die "environnement attendu en premier argument : prod ou preprod" ;; esac
  local fichier="$CONFIG_DIR/deploy.$ENV.env" ligne cle valeur
  [ -f "$fichier" ] || die "configuration introuvable : $fichier"
  local URBANKIFF_ENV="" GHCR_OWNER="" NAMESPACE_LU=""
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    [ -n "$ligne" ] && [ "${ligne#\#}" = "$ligne" ] || continue
    [[ "$ligne" =~ ^([A-Z_]+)=(.*)$ ]] || die "configuration : ligne mal formée"
    cle="${BASH_REMATCH[1]}"; valeur="${BASH_REMATCH[2]}"
    case "$cle" in
      URBANKIFF_ENV) URBANKIFF_ENV="$valeur" ;;
      GHCR_OWNER) GHCR_OWNER="$valeur" ;;
      NAMESPACE) NAMESPACE_LU="$valeur" ;;
      *) die "configuration : clé inconnue $cle" ;;
    esac
  done < "$fichier"
  [ -n "$URBANKIFF_ENV" ] || die "configuration : URBANKIFF_ENV absent"
  [ -n "$GHCR_OWNER" ] || die "configuration : GHCR_OWNER absent"
  [ -n "$NAMESPACE_LU" ] || die "configuration : NAMESPACE absent"
  [ "$URBANKIFF_ENV" = "$ENV" ] || die "configuration : URBANKIFF_ENV ne correspond pas à l'environnement de la clé"
  [[ "$GHCR_OWNER" =~ ^[A-Za-z0-9-]+$ ]] || die "configuration : GHCR_OWNER invalide"
  [[ "$NAMESPACE_LU" =~ ^[a-z0-9-]+$ ]] || die "configuration : NAMESPACE invalide"
  OWNER="$GHCR_OWNER"
  NAMESPACE="$NAMESPACE_LU"
}

verrouiller() {
  exec 9> "$LOCK_FILE"
  flock -n 9 || die "un déploiement est déjà en cours"
}

main() {
  analyser_commande
  lire_configuration "${1:-}"
  case "$COMMANDE" in
    deploy)
      case "$VERSION" in *-*) [ "$ENV" = preprod ] || refuser "pré-release interdite en prod" ;; esac ;;
    preprod-*) [ "$ENV" = preprod ] || refuser "$COMMANDE n'existe qu'en preprod" ;;
  esac
  verrouiller
  export KUBECONFIG="$HOME/.kube/$ENV"
  log "commande $COMMANDE${VERSION:+, version $VERSION}, environnement $ENV"
}

main "$@"
