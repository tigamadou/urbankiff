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
  local URBANKIFF_ENV="" GHCR_OWNER="" NAMESPACE_LU="" API_CIDR_LU=""
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    [ -n "$ligne" ] && [ "${ligne#\#}" = "$ligne" ] || continue
    [[ "$ligne" =~ ^([A-Z_]+)=(.*)$ ]] || die "configuration : ligne mal formée"
    cle="${BASH_REMATCH[1]}"; valeur="${BASH_REMATCH[2]}"
    case "$cle" in
      URBANKIFF_ENV) URBANKIFF_ENV="$valeur" ;;
      GHCR_OWNER) GHCR_OWNER="$valeur" ;;
      NAMESPACE) NAMESPACE_LU="$valeur" ;;
      API_SERVER_CIDR) API_CIDR_LU="$valeur" ;;
      *) die "configuration : clé inconnue $cle" ;;
    esac
  done < "$fichier"
  [ -n "$URBANKIFF_ENV" ] || die "configuration : URBANKIFF_ENV absent"
  [ -n "$GHCR_OWNER" ] || die "configuration : GHCR_OWNER absent"
  [ -n "$NAMESPACE_LU" ] || die "configuration : NAMESPACE absent"
  [ -n "$API_CIDR_LU" ] || die "configuration : API_SERVER_CIDR absent"
  [ "$URBANKIFF_ENV" = "$ENV" ] || die "configuration : URBANKIFF_ENV ne correspond pas à l'environnement de la clé"
  [[ "$GHCR_OWNER" =~ ^[A-Za-z0-9-]+$ ]] || die "configuration : GHCR_OWNER invalide"
  [[ "$NAMESPACE_LU" =~ ^[a-z0-9-]+$ ]] || die "configuration : NAMESPACE invalide"
  [[ "$API_CIDR_LU" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/32$ ]] || die "configuration : API_SERVER_CIDR invalide (attendu : IPv4 en /32)"
  OWNER="$GHCR_OWNER"
  NAMESPACE="$NAMESPACE_LU"
  API_SERVER_CIDR="$API_CIDR_LU"
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
  else
    log "aucune entrée standard : Secrets et variables existants réutilisés"
    lire_cluster
  fi
  calculer_empreinte
}

TMP=""
nettoyer() { [ -z "$TMP" ] || rm -rf "$TMP"; }

telecharger_charts() {
  local chart
  TMP="$(mktemp -d)"
  export HELM_CACHE_HOME="$TMP/cache" HELM_CONFIG_HOME="$TMP/config" HELM_DATA_HOME="$TMP/data"
  for chart in urbankiff-donnees urbankiff; do
    helm pull "oci://ghcr.io/$OWNER/charts/$chart" --version "$VERSION" --untar --untardir "$TMP/charts" \
      || die "chart introuvable : $chart $VERSION"
  done
}

deployer_charts() {
  helm upgrade --install urbankiff-donnees "$TMP/charts/urbankiff-donnees" -n "$NAMESPACE" \
    -f "$TMP/charts/urbankiff-donnees/values-$ENV.yaml" --wait --timeout 10m
  kubectl wait cluster.postgresql.cnpg.io/urbankiff-pg -n "$NAMESPACE" --for=condition=Ready --timeout=600s \
    || die "CloudNativePG n'est pas prêt : l'application n'est pas déployée"
  helm upgrade --install urbankiff "$TMP/charts/urbankiff" -n "$NAMESPACE" \
    -f "$TMP/charts/urbankiff/values-$ENV.yaml" --atomic --wait --timeout 10m \
    --set "image.etiquette=$VERSION" --set "secretsChecksum=$CHECKSUM" --set "environnement=$ENV" \
    --set "wasabi.region=$WASABI_REGION,wasabi.bucket=$WASABI_BUCKET" \
    --set "reseau.apiKubernetes.cidr=$API_SERVER_CIDR"
}

verifier_sante() {
  local hote
  hote="$(kubectl get ingress urbankiff-api -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')"
  [[ "$hote" =~ ^[a-z0-9.-]+$ ]] || die "hôte de l'Ingress urbankiff-api illisible"
  for _ in $(seq 1 24); do
    if curl -fsS --max-time 5 -o /dev/null "https://$hote/api/health/"; then
      log "santé de l'api confirmée"
      return 0
    fi
    sleep 5
  done
  die "l'api ne répond pas sur /api/health/ après 2 minutes"
}

cmd_deploy() {
  preparer_secrets
  telecharger_charts
  [ "$ENTREE_PRESENTE" = 0 ] || appliquer_entree
  deployer_charts
  verifier_sante
  log "version $VERSION déployée dans $ENV"
}

LABEL_APPLICATION="app.kubernetes.io/part-of=urbankiff"
CLUSTER_PG="cluster.postgresql.cnpg.io/urbankiff-pg"
ANNOTATION_REPLICAS="urbankiff.com/replicas-avant"

charges() { # <deployment|statefulset> : « nom replicas replicas-avant » par ligne
  kubectl get "$1" -n "$NAMESPACE" -l "$LABEL_APPLICATION" \
    -o go-template='{{range .items}}{{.metadata.name}} {{.spec.replicas}} {{with .metadata.annotations}}{{index . "urbankiff.com/replicas-avant"}}{{end}}{{"\n"}}{{end}}'
}

hibernation() { # <on|off>
  local actuelle
  actuelle="$(kubectl get "$CLUSTER_PG" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.cnpg\.io/hibernation}')"
  [ "$actuelle" = "$1" ] || kubectl annotate "$CLUSTER_PG" -n "$NAMESPACE" "cnpg.io/hibernation=$1" --overwrite
}

cmd_preprod_arret() {
  local genre nom replicas avant
  for genre in deployment statefulset; do
    while read -r nom replicas avant; do
      [ -n "$nom" ] && [ "$replicas" != 0 ] || continue
      kubectl annotate "$genre/$nom" -n "$NAMESPACE" "$ANNOTATION_REPLICAS=$replicas" --overwrite
      kubectl scale "$genre/$nom" -n "$NAMESPACE" --replicas=0
    done < <(charges "$genre")
  done
  hibernation on
  log "preprod arrêtée"
}

cmd_preprod_demarrage() {
  local genre nom replicas avant
  hibernation off
  kubectl wait "$CLUSTER_PG" -n "$NAMESPACE" --for=condition=Ready --timeout=600s \
    || die "CloudNativePG n'est pas prêt : les charges ne sont pas relancées"
  for genre in deployment statefulset; do
    while read -r nom replicas avant; do
      [ -n "$nom" ] && [ "$replicas" = 0 ] && [[ "${avant:-}" =~ ^[1-9][0-9]*$ ]] || continue
      kubectl scale "$genre/$nom" -n "$NAMESPACE" --replicas="$avant"
      kubectl annotate "$genre/$nom" -n "$NAMESPACE" "$ANNOTATION_REPLICAS-"
    done < <(charges "$genre")
  done
  log "preprod démarrée"
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
  trap nettoyer EXIT
  export KUBECONFIG="$HOME/.kube/$ENV"
  log "commande $COMMANDE${VERSION:+, version $VERSION}, environnement $ENV"
  case "$COMMANDE" in
    deploy) cmd_deploy ;;
    preprod-arret) cmd_preprod_arret ;;
    preprod-demarrage) cmd_preprod_demarrage ;;
  esac
}

main "$@"
