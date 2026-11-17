#!/usr/bin/env bash
# Point d'entrée unique du compte `deploy` (commande forcée SSH) : docs/v1/infra/deploiement.md.
#
#   urbankiff-deploy <prod|preprod>      avec SSH_ORIGINAL_COMMAND = deploy <version> | restaurer <prefixe> | exporter-anonyme <date> |
#                                        preprod-arret | preprod-demarrage
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
  DJANGO_SUPERUSER_PASSWORD WASABI_ACCESS_KEY_ID WASABI_SECRET_ACCESS_KEY PGADMIN_EMAIL PGADMIN_MOT_DE_PASSE"
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
  elif [[ "$commande" =~ ^restaurer\ (restauration/[0-9]{4}-[0-9]{2}-[0-9]{2}(-prod-anonyme)?/)$ ]]; then
    COMMANDE=restaurer
    PREFIXE="${BASH_REMATCH[1]}"
  elif [[ "$commande" =~ ^exporter-anonyme\ ([0-9]{4}-[0-9]{2}-[0-9]{2})$ ]]; then
    COMMANDE=exporter-anonyme
    DATE_EXPORT="${BASH_REMATCH[1]}"
  elif [ "$commande" = preprod-arret ] || [ "$commande" = preprod-demarrage ]; then
    COMMANDE="$commande"
  else
    refuser "attendu : deploy <version>, restaurer <prefixe>, exporter-anonyme <date>, preprod-arret ou preprod-demarrage"
  fi
}

lire_configuration() {
  case "$1" in prod|preprod) ENV="$1" ;; *) die "environnement attendu en premier argument : prod ou preprod" ;; esac
  local fichier="$CONFIG_DIR/deploy.$ENV.env" ligne cle valeur
  [ -f "$fichier" ] || die "configuration introuvable : $fichier"
  local URBANKIFF_ENV="" GHCR_OWNER="" NAMESPACE_LU="" API_CIDR_LU="" BUCKET_LU="" BUCKET_PRESENT=0
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    [ -n "$ligne" ] && [ "${ligne#\#}" = "$ligne" ] || continue
    [[ "$ligne" =~ ^([A-Z_]+)=(.*)$ ]] || die "configuration : ligne mal formée"
    cle="${BASH_REMATCH[1]}"; valeur="${BASH_REMATCH[2]}"
    case "$cle" in
      URBANKIFF_ENV) URBANKIFF_ENV="$valeur" ;;
      GHCR_OWNER) GHCR_OWNER="$valeur" ;;
      NAMESPACE) NAMESPACE_LU="$valeur" ;;
      API_SERVER_CIDR) API_CIDR_LU="$valeur" ;;
      BUCKET_COPIE_PREPROD) [ "$1" = prod ] || die "configuration : clé inconnue $cle"; BUCKET_LU="$valeur"; BUCKET_PRESENT=1 ;;
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
  if [ "$BUCKET_PRESENT" = 1 ]; then
    [[ "$BUCKET_LU" =~ ^[A-Za-z0-9.-]+$ ]] || die "configuration : BUCKET_COPIE_PREPROD invalide"
  fi
  BUCKET_COPIE_PREPROD="$BUCKET_LU"
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

valider_entree() { # [sans-pgadmin] : n'exige pas les identifiants pgAdmin
  local cle
  for cle in $SECRET_KEYS; do
    [[ "${1:-}" == sans-pgadmin && "$cle" == PGADMIN_* ]] && continue
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

lire_cluster() { # [pgadmin] : exige aussi les identifiants pgAdmin
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
  [ "${1:-}" != pgadmin ] || { [ -n "${SECRET_B64[PGADMIN_EMAIL]:-}" ] && [ -n "${SECRET_B64[PGADMIN_MOT_DE_PASSE]:-}" ]; } \
    || die "Secret incomplet : relancer make secrets-cluster"
  if [ "${1:-}" = pgadmin ]; then valider_entree; else valider_entree sans-pgadmin; fi
}

calculer_empreinte() {
  local cle
  CHECKSUM="$({
    echo secrets
    for cle in $(printf '%s\n' $SECRET_KEYS | sort); do echo "$cle=${SECRET_B64[$cle]:-}"; done
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
    lire_cluster pgadmin
  fi
  calculer_empreinte
}

TMP=""
APP_ARRETEE=0
nettoyer() {
  local statut=$?
  [ -z "$TMP" ] || rm -rf "$TMP"
  if [ "$statut" -ne 0 ] && [ "$APP_ARRETEE" = 1 ]; then
    log "l'application reste arrêtée : la base peut être à moitié restaurée, corriger puis relancer la même commande"
  fi
}

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
    -f "$TMP/charts/urbankiff-donnees/values-$ENV.yaml" --wait --timeout 10m \
    --set "reseau.apiKubernetes.cidr=$API_SERVER_CIDR" \
    --set "wasabi.region=$WASABI_REGION,wasabi.bucket=$WASABI_BUCKET"
  kubectl wait cluster.postgresql.cnpg.io/urbankiff-pg -n "$NAMESPACE" --for=condition=Ready --timeout=600s \
    || die "CloudNativePG n'est pas prêt : l'application n'est pas déployée"
  helm upgrade --install urbankiff "$TMP/charts/urbankiff" -n "$NAMESPACE" \
    -f "$TMP/charts/urbankiff/values-$ENV.yaml" --atomic --wait --timeout 10m \
    --set "image.etiquette=$VERSION" --set "secretsChecksum=$CHECKSUM" --set "environnement=$ENV"
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

mettre_a_zero() { # <deployment|statefulset> : note les réplicas, sans écraser la note d'une charge déjà à zéro
  local nom replicas avant
  while read -r nom replicas avant; do
    [ -n "$nom" ] && [ "$replicas" != 0 ] || continue
    kubectl annotate "$1/$nom" -n "$NAMESPACE" "$ANNOTATION_REPLICAS=$replicas" --overwrite
    kubectl scale "$1/$nom" -n "$NAMESPACE" --replicas=0
  done < <(charges "$1")
}

remettre_a_lechelle() { # <deployment|statefulset>
  local nom replicas avant
  while read -r nom replicas avant; do
    [ -n "$nom" ] && [ "$replicas" = 0 ] && [[ "${avant:-}" =~ ^[1-9][0-9]*$ ]] || continue
    kubectl scale "$1/$nom" -n "$NAMESPACE" --replicas="$avant"
    kubectl annotate "$1/$nom" -n "$NAMESPACE" "$ANNOTATION_REPLICAS-"
  done < <(charges "$1")
}

cmd_preprod_arret() {
  local genre
  for genre in deployment statefulset; do mettre_a_zero "$genre"; done
  hibernation on
  log "preprod arrêtée"
}

cmd_preprod_demarrage() {
  local genre
  hibernation off
  kubectl wait "$CLUSTER_PG" -n "$NAMESPACE" --for=condition=Ready --timeout=600s \
    || die "CloudNativePG n'est pas prêt : les charges ne sont pas relancées"
  for genre in deployment statefulset; do remettre_a_lechelle "$genre"; done
  log "preprod démarrée"
}

version_deployee() {
  local lue
  lue="$(helm get values urbankiff -n "$NAMESPACE" -o yaml | awk '/^image:/ {dans=1; next} /^[^ ]/ {dans=0} dans && $1 == "etiquette:" {gsub(/["\047]/, "", $2); print $2; exit}')" \
    || die "application non déployée : version introuvable"
  [[ "$lue" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "application non déployée : version introuvable"
  VERSION="$lue"
}

rendre_job() { # <chart> <release> <gabarit> [--set k=v ...] : manifeste rendu dans MANIFESTE
  local chart="$1" release="$2" gabarit="$3"
  shift 3
  helm get values "$release" -n "$NAMESPACE" -o yaml > "$TMP/valeurs-$release.yaml" \
    || die "valeurs de la release $release introuvables"
  MANIFESTE="$(helm template "$release" "$TMP/charts/$chart" -n "$NAMESPACE" \
    -f "$TMP/charts/$chart/values-$ENV.yaml" -f "$TMP/valeurs-$release.yaml" \
    --show-only "templates/$gabarit" "$@")" || die "rendu de $gabarit impossible"
  [ -n "$MANIFESTE" ] || die "le Job n'est pas rendu : $gabarit"
}

lancer_job() { # <nom> : un Job du même nom resté d'une tentative précédente est supprimé d'abord
  kubectl delete job "$1" -n "$NAMESPACE" --ignore-not-found
  printf '%s\n' "$MANIFESTE" | kubectl apply -n "$NAMESPACE" -f -
}

suivre_job() { # <nom> <journal de fin, vide si non exigé> : le Job d'un échec est conservé pour l'enquête
  local nom="$1" fin="$2" etat reussis echecs essai journaux
  for ((essai = 0; essai < ${URBANKIFF_JOB_TENTATIVES:-360}; essai++)); do
    etat="$(kubectl get job "$nom" -n "$NAMESPACE" -o jsonpath='{.status.succeeded}/{.status.failed}')"
    reussis="${etat%%/*}"; echecs="${etat#*/}"
    if [[ "$reussis" =~ ^[1-9] ]]; then
      journaux="$(kubectl logs "job/$nom" -n "$NAMESPACE" --all-containers --tail=200)" || journaux=""
      if [ -n "$fin" ] && [[ "$journaux" != *"$fin"* ]]; then
        printf '%s\n' "$journaux" >&2
        die "le Job $nom est terminé sans le journal « $fin » : conservé pour l'enquête"
      fi
      kubectl delete job "$nom" -n "$NAMESPACE" --ignore-not-found
      return 0
    fi
    if [[ "$echecs" =~ ^[1-9] ]]; then
      kubectl logs "job/$nom" -n "$NAMESPACE" --all-containers --tail=200 >&2 || true
      die "le Job $nom a échoué : conservé pour l'enquête (kubectl logs job/$nom -n $NAMESPACE)"
    fi
    sleep 5
  done
  kubectl logs "job/$nom" -n "$NAMESPACE" --all-containers --tail=200 >&2 || true
  die "le Job $nom n'est pas terminé après le délai : conservé pour l'enquête"
}

controler_prefixe() {
  local identifiant secret code
  identifiant="$(base64 -d <<< "${SECRET_B64[WASABI_ACCESS_KEY_ID]}")"
  secret="$(base64 -d <<< "${SECRET_B64[WASABI_SECRET_ACCESS_KEY]}")"
  # Les identifiants passent par l'entrée standard de curl (-K -), jamais par un argument.
  code="$(printf 'user = "%s:%s"\n' "$identifiant" "$secret" | curl -sS --max-time 20 -o /dev/null -w '%{http_code}' --head --aws-sigv4 "aws:amz:$WASABI_REGION:s3" -K - \
    "https://s3.$WASABI_REGION.wasabisys.com/$WASABI_BUCKET/${PREFIXE}base.dump")" || code=000
  unset identifiant secret
  case "$code" in
    200) ;;
    404) die "préfixe introuvable dans le bucket $WASABI_BUCKET : ${PREFIXE}base.dump" ;;
    *) die "contrôle du préfixe impossible (HTTP $code) dans le bucket $WASABI_BUCKET : ${PREFIXE}base.dump" ;;
  esac
  kubectl wait "$CLUSTER_PG" -n "$NAMESPACE" --for=condition=Ready --timeout=600s \
    || die "CloudNativePG n'est pas prêt : rien n'est arrêté"
}

cmd_restaurer() {
  lire_cluster pgadmin
  calculer_empreinte
  controler_prefixe
  version_deployee
  telecharger_charts
  APP_ARRETEE=1
  mettre_a_zero deployment
  rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml --set "restauration.prefixe=$PREFIXE"
  lancer_job urbankiff-restauration
  suivre_job urbankiff-restauration "restauration terminée"
  rendre_job urbankiff urbankiff apres-restauration-job.yaml --set "apresRestauration.actif=true"
  lancer_job urbankiff-apres-restauration
  suivre_job urbankiff-apres-restauration ""
  remettre_a_lechelle deployment
  APP_ARRETEE=0
  kubectl wait deployment -l "$LABEL_APPLICATION" -n "$NAMESPACE" --for=condition=Available --timeout=600s \
    || die "l'application ne redevient pas disponible"
  verifier_sante
  log "restauration terminée : $PREFIXE"
}
cmd_exporter_anonyme() {
  local prefixe="restauration/$DATE_EXPORT-prod-anonyme/"
  lire_cluster
  calculer_empreinte
  version_deployee
  telecharger_charts
  rendre_job urbankiff urbankiff export-anonyme-job.yaml \
    --set "exportAnonyme.prefixe=$prefixe" --set "exportAnonyme.bucketCible=$BUCKET_COPIE_PREPROD" \
    --set "environnement=prod" --set "wasabi.region=$WASABI_REGION,wasabi.endpoint=s3.$WASABI_REGION.wasabisys.com"
  lancer_job urbankiff-export-anonyme
  suivre_job urbankiff-export-anonyme "export terminé"
  log "export terminé : $prefixe vers $BUCKET_COPIE_PREPROD"
}

main() {
  analyser_commande
  lire_configuration "${1:-}"
  case "$COMMANDE" in
    deploy)
      case "$VERSION" in *-*) [ "$ENV" = preprod ] || refuser "pré-release interdite en prod" ;; esac ;;
    preprod-*) [ "$ENV" = preprod ] || refuser "$COMMANDE n'existe qu'en preprod" ;;
    restaurer)
      case "$PREFIXE" in *-prod-anonyme/) [ "$ENV" = preprod ] || refuser "restauration d'un export anonymisé interdite en prod" ;; esac ;;
    exporter-anonyme)
      [ "$ENV" = prod ] || refuser "exporter-anonyme n'existe qu'en prod"
      [ -n "$BUCKET_COPIE_PREPROD" ] || die "configuration : BUCKET_COPIE_PREPROD absent" ;;
  esac
  verrouiller
  trap nettoyer EXIT
  export KUBECONFIG="$HOME/.kube/$ENV"
  log "commande $COMMANDE${VERSION:+, version $VERSION}, environnement $ENV"
  case "$COMMANDE" in
    deploy) cmd_deploy ;;
    preprod-arret) cmd_preprod_arret ;;
    preprod-demarrage) cmd_preprod_demarrage ;;
    restaurer) cmd_restaurer ;;
    exporter-anonyme) cmd_exporter_anonyme ;;
  esac
}

main "$@"
