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

# cles:debut
SECRET_KEYS="SECRET_KEY REDIS_PASSWORD MINIO_ROOT_USER MINIO_ROOT_PASSWORD SMTP_USERNAME SMTP_PASSWORD
  TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN SOCIAL_AUTH_GOOGLE_OAUTH2_KEY SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET
  DJANGO_SUPERUSER_PASSWORD WASABI_ACCESS_KEY_ID WASABI_SECRET_ACCESS_KEY"
VARIABLE_KEYS="NEXT_PUBLIC_BACKEND_URL BACKEND_URL NEXT_PUBLIC_BACKEND_URL_FRONT NEXT_PUBLIC_GOOGLE_CLIENT_ID
  DJANGO_ENV ALLOWED_HOSTS WEB_URL API_URL SMTP_SERVER SMTP_PORT MINIO_DEFAULT_BUCKETS FILES_CDN_ENDPOINT
  REACT_APP_BACKEND_URL REACT_APP_IMAGEKIT_ENDPOINT WASABI_REGION WASABI_BUCKET"
# cles:fin
SECRET_KEYS="$(echo $SECRET_KEYS)"
VARIABLE_KEYS="$(echo $VARIABLE_KEYS)"

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

LIMITE_ENTREE=65536
declare -A SECRET_B64 VARIABLE_VAL
ENTREE_PRESENTE=0
SECRET_ENV=""
VARIABLE_ENV=""

lire_entree() {
  [ ! -t 0 ] || return 0
  local donnees ligne reste numero=0 nom valeur
  donnees="$(head -c $((LIMITE_ENTREE + 1)); printf x)"
  donnees="${donnees%x}"
  [ -n "$donnees" ] || return 0
  [ "${#donnees}" -le "$LIMITE_ENTREE" ] || die "entrée standard de plus de 64 Ko refusée"
  ENTREE_PRESENTE=1
  reste="$donnees"
  unset donnees
  while [ -n "$reste" ]; do
    if [[ "$reste" == *$'\n'* ]]; then ligne="${reste%%$'\n'*}"; reste="${reste#*$'\n'}"; else ligne="$reste"; reste=""; fi
    numero=$((numero + 1))
    [ -n "$ligne" ] || continue
    [[ "$ligne" != *$'\r'* ]] || die "ligne $numero : retour chariot interdit"
    [[ "$ligne" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || die "ligne $numero : mal formée (attendu NOM=valeur)"
    nom="${BASH_REMATCH[1]}"; valeur="${BASH_REMATCH[2]}"
    if [[ " $SECRET_KEYS " == *" $nom "* ]]; then
      [ -z "${SECRET_B64[$nom]+x}" ] || die "ligne $numero : nom en double"
      SECRET_B64[$nom]="$(printf %s "$valeur" | base64 -w0)"
      SECRET_ENV+="$nom=$valeur"$'\n'
    elif [[ " $VARIABLE_KEYS " == *" $nom "* ]]; then
      [ -z "${VARIABLE_VAL[$nom]+x}" ] || die "ligne $numero : nom en double"
      VARIABLE_VAL[$nom]="$valeur"
      VARIABLE_ENV+="$nom=$valeur"$'\n'
    else
      die "ligne $numero : nom inconnu"
    fi
  done
  unset reste ligne valeur
}

valider_entree() {
  local cle
  for cle in $SECRET_KEYS; do
    [ -n "${SECRET_B64[$cle]:-}" ] || die "clé obligatoire absente ou vide : $cle"
  done
  for cle in $VARIABLE_KEYS; do
    [ -n "${VARIABLE_VAL[$cle]:-}" ] || die "clé obligatoire absente ou vide : $cle"
  done
}

appliquer_entree() {
  printf '%s' "$SECRET_ENV" | kubectl create secret generic urbankiff-secrets -n "$NAMESPACE" \
    --from-env-file=/dev/stdin --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
  printf '%s' "$VARIABLE_ENV" | kubectl create configmap urbankiff-config -n "$NAMESPACE" \
    --from-env-file=/dev/stdin --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
  SECRET_ENV=""; VARIABLE_ENV=""
  log "Secret urbankiff-secrets et ConfigMap urbankiff-config appliqués"
}

lire_cluster() {
  local sortie ligne cle
  sortie="$(kubectl get secret urbankiff-secrets -n "$NAMESPACE" -o go-template='{{range $k, $v := .data}}{{$k}}={{$v}}{{"\n"}}{{end}}')" \
    || die "Secret urbankiff-secrets introuvable : premier déploiement, fournir les Secrets (voir make secrets-cluster)"
  while IFS= read -r ligne; do
    [[ "$ligne" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] && SECRET_B64[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
  done <<< "$sortie"
  sortie="$(kubectl get configmap urbankiff-config -n "$NAMESPACE" -o go-template='{{range $k, $v := .data}}{{$k}}={{$v}}{{"\n"}}{{end}}')" \
    || die "ConfigMap urbankiff-config introuvable : premier déploiement, fournir les Secrets et variables (voir make secrets-cluster)"
  while IFS= read -r ligne; do
    [[ "$ligne" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] && VARIABLE_VAL[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
  done <<< "$sortie"
  unset sortie ligne
  valider_entree
}

calculer_empreinte() {
  local cle
  CHECKSUM="$({
    echo secrets
    for cle in $(printf '%s\n' $SECRET_KEYS | sort); do echo "$cle=${SECRET_B64[$cle]}"; done
    echo config
    for cle in $(printf '%s\n' $VARIABLE_KEYS | sort); do echo "$cle=${VARIABLE_VAL[$cle]}"; done
  } | sha256sum | cut -c1-16)"
  WASABI_REGION="${VARIABLE_VAL[WASABI_REGION]}"
  WASABI_BUCKET="${VARIABLE_VAL[WASABI_BUCKET]}"
  [[ "$WASABI_REGION" =~ ^[A-Za-z0-9.-]+$ ]] || die "WASABI_REGION invalide"
  [[ "$WASABI_BUCKET" =~ ^[A-Za-z0-9.-]+$ ]] || die "WASABI_BUCKET invalide"
}

preparer_secrets() {
  lire_entree
  if [ "$ENTREE_PRESENTE" = 1 ]; then
    valider_entree
    calculer_empreinte
    appliquer_entree
  else
    log "aucune entrée standard : Secrets et variables existants réutilisés"
    lire_cluster
    calculer_empreinte
  fi
}

cmd_deploy() {
  preparer_secrets
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
  case "$COMMANDE" in
    deploy) cmd_deploy ;;
  esac
}

main "$@"
