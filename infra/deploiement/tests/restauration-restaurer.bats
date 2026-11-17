#!/usr/bin/env bats
# Action restaurer (urbankiff-deploy.sh) avec de faux kubectl, helm, curl : déroulé, ordre, échecs, relance.

load aide

setup() {
  RACINE_DEPOT="$BATS_TEST_DIRNAME/../../.."
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export URBANKIFF_CONFIG_DIR="$BATS_TEST_TMPDIR/etc"
  export URBANKIFF_LOCK_FILE="$BATS_TEST_TMPDIR/verrou"
  mkdir -p "$FAKE_STATE" "$HOME" "$URBANKIFF_CONFIG_DIR"
  : > "$FAKE_LOG"
  for e in preprod prod; do
    printf 'URBANKIFF_ENV=%s\nGHCR_OWNER=tigamadou\nNAMESPACE=%s\nAPI_SERVER_CIDR=203.0.113.10/32\n' "$e" "$e" > "$URBANKIFF_CONFIG_DIR/deploy.$e.env"
  done
  etat_nominal
}

etat_nominal() {
  local nom
  : > "$FAKE_STATE/secret.txt"
  for nom in $(noms_secrets_complets); do printf '%s=%s\n' "$nom" "$(printf '%s' "valeur-$nom" | base64 -w0)" >> "$FAKE_STATE/secret.txt"; done
  grep -vE '^(#|$)' "$RACINE_DEPOT/scripts/secrets/variables-preprod.txt" > "$FAKE_STATE/config.txt"
  printf 'image:\n  etiquette: 1.2.3\n' > "$FAKE_STATE/values-urbankiff.yaml"
  : > "$FAKE_STATE/values-urbankiff-donnees.yaml"
  printf 'urbankiff-api 2 \nurbankiff-workers 1 \nurbankiff-pgadmin 1 \n' > "$FAKE_STATE/deployment.txt"
  echo "1/" > "$FAKE_STATE/job-urbankiff-restauration.txt"
  echo "restauration terminée" > "$FAKE_STATE/logs-urbankiff-restauration.txt"
  echo "1/" > "$FAKE_STATE/job-urbankiff-apres-restauration.txt"
}

restaurer() { # <env> <préfixe>
  SSH_ORIGINAL_COMMAND="restaurer $2" run bash "$SCRIPT" "$1" < /dev/null
}

numero() { grep -n -m1 -- "$1" "$FAKE_LOG" | cut -d: -f1; }

dans_l_ordre() { # motifs, chacun doit apparaître après le précédent
  local precedent=0 courant motif
  for motif in "$@"; do
    courant="$(numero "$motif")"
    [ -n "$courant" ] && [ "$courant" -gt "$precedent" ] || { echo "hors ordre ou absent : $motif"; cat "$FAKE_LOG"; return 1; }
    precedent="$courant"
  done
}

aucune_charge_touchee() {
  absent -qE '^kubectl (scale|annotate deployment|apply|delete)' "$FAKE_LOG" || return 1
  absent -q '^helm template' "$FAKE_LOG"
}

@test "succès en preprod : ordre exact des appels et message final" {
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"restauration terminée : restauration/2026-11-17/"* ]]
  dans_l_ordre \
    '^curl .*--head --aws-sigv4 aws:amz:eu-central-1:s3 -K - https://s3.eu-central-1.wasabisys.com/urbankiff-preprod/restauration/2026-11-17/base.dump' \
    '^kubectl wait cluster.postgresql.cnpg.io/urbankiff-pg' \
    '^helm get values urbankiff -n preprod -o yaml' \
    '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff-donnees --version 1.2.3' \
    '^helm pull oci://ghcr.io/tigamadou/charts/urbankiff --version 1.2.3' \
    '^kubectl annotate deployment/urbankiff-api -n preprod urbankiff.com/replicas-avant=2 --overwrite$' \
    '^kubectl scale deployment/urbankiff-api -n preprod --replicas=0$' \
    '^kubectl scale deployment/urbankiff-pgadmin -n preprod --replicas=0$' \
    '^helm template urbankiff-donnees .* --show-only templates/restauration-job.yaml --set restauration.prefixe=restauration/2026-11-17/$' \
    '^kubectl delete job urbankiff-restauration -n preprod --ignore-not-found$' \
    '^kubectl apply -n preprod -f -$' \
    '^kubectl get job urbankiff-restauration' \
    '^helm template urbankiff .* --show-only templates/apres-restauration-job.yaml --set apresRestauration.actif=true$' \
    '^kubectl delete job urbankiff-apres-restauration -n preprod --ignore-not-found$' \
    '^kubectl get job urbankiff-apres-restauration' \
    '^kubectl scale deployment/urbankiff-api -n preprod --replicas=2$' \
    '^kubectl annotate deployment/urbankiff-api -n preprod urbankiff.com/replicas-avant-$' \
    '^kubectl wait deployment -l app.kubernetes.io/part-of=urbankiff -n preprod --for=condition=Available --timeout=600s$' \
    '^curl .*https://api.test.example/api/health/'
  grep -q '^kubectl scale deployment/urbankiff-workers -n preprod --replicas=1$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-pgadmin -n preprod --replicas=1$' "$FAKE_LOG"
  [ "$(grep -c '^kubectl apply' "$FAKE_LOG")" -eq 2 ]
}

@test "succès en prod : même déroulé dans le namespace prod" {
  restaurer prod restauration/2026-11-17/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '^kubectl scale deployment/urbankiff-api -n prod --replicas=0$' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-api -n prod --replicas=2$' "$FAKE_LOG"
  grep -q 'values-prod.yaml' "$FAKE_LOG"
}

@test "préfixe anonymisé : transmis tel quel à restauration.prefixe" {
  restaurer preprod restauration/2026-11-17-prod-anonyme/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q -- '--set restauration.prefixe=restauration/2026-11-17-prod-anonyme/$' "$FAKE_LOG"
  grep -q 'restauration/2026-11-17-prod-anonyme/base.dump' "$FAKE_LOG"
}

@test "préfixe absent de Wasabi : rien n'est arrêté, les identifiants ne sont pas dans la requête" {
  FAKE_CURL_ECHEC_SUR=wasabisys FAKE_CURL_CODE=404 restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"préfixe introuvable dans le bucket urbankiff-preprod : restauration/2026-11-17/base.dump"* ]]
  aucune_charge_touchee
  absent -q 'valeur-WASABI' "$FAKE_LOG"
  grep -qE '^STDIN curl [0-9]+$' "$FAKE_LOG"
  [[ "$output" != *"l'application reste arrêtée"* ]]
}

@test "authentification Wasabi refusée : message distinct de préfixe introuvable, rien n'est arrêté" {
  FAKE_CURL_ECHEC_SUR=wasabisys FAKE_CURL_CODE=403 restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"contrôle du préfixe impossible (HTTP 403)"* ]]
  [[ "$output" != *"préfixe introuvable"* ]]
  aucune_charge_touchee
}

@test "base pas prête : rien n'est arrêté" {
  FAKE_WAIT_ECHEC=1 FAKE_WAIT_ECHEC_SUR=cluster.postgresql restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  aucune_charge_touchee
}

@test "version déployée introuvable ou chart absent : rien n'est arrêté" {
  rm "$FAKE_STATE/values-urbankiff.yaml"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  aucune_charge_touchee
  printf 'image:\n  etiquette: 1.2.3\n' > "$FAKE_STATE/values-urbankiff.yaml"
  FAKE_PULL_ECHEC=1 restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  aucune_charge_touchee
}

@test "Secret sans PGADMIN_EMAIL : message dédié, rien n'est arrêté" {
  grep -v '^PGADMIN_EMAIL=' "$FAKE_STATE/secret.txt" > "$FAKE_STATE/secret.sans"
  mv "$FAKE_STATE/secret.sans" "$FAKE_STATE/secret.txt"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"Secret incomplet : relancer make secrets-cluster"* ]]
  aucune_charge_touchee
  absent -q '^curl' "$FAKE_LOG"
}

@test "échec du Job de restauration : application arrêtée, pas de remise, pas de Job après, Job conservé" {
  echo "0/1" > "$FAKE_STATE/job-urbankiff-restauration.txt"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"l'application reste arrêtée"* ]]
  absent -q 'apres-restauration' "$FAKE_LOG"
  absent -qE '^kubectl scale .* --replicas=[1-9]' "$FAKE_LOG"
  absent -q '^kubectl delete job' <(sed '1,/^kubectl apply/d' "$FAKE_LOG")
  absent -q '^curl .*api/health' "$FAKE_LOG"
}

@test "journal de fin absent du Job de restauration : application arrêtée" {
  echo "autre" > "$FAKE_STATE/logs-urbankiff-restauration.txt"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"l'application reste arrêtée"* ]]
}

@test "échec du Job après restauration : application arrêtée, Job de restauration déjà supprimé" {
  echo "0/1" > "$FAKE_STATE/job-urbankiff-apres-restauration.txt"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"l'application reste arrêtée"* ]]
  grep -q '^kubectl delete job urbankiff-restauration -n preprod --ignore-not-found$' "$FAKE_LOG"
  [ "$(grep -c '^kubectl delete job urbankiff-restauration' "$FAKE_LOG")" -eq 2 ]
  absent -qE '^kubectl scale .* --replicas=[1-9]' "$FAKE_LOG"
  absent -q '^kubectl delete job urbankiff-apres-restauration' <(sed '1,/apres-restauration-job.yaml/d' "$FAKE_LOG" | sed '1,/^kubectl apply/d')
}

@test "rendu du Job impossible : application arrêtée" {
  FAKE_TEMPLATE_ECHEC=1 restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  [[ "$output" == *"l'application reste arrêtée"* ]]
  absent -q '^kubectl apply' "$FAKE_LOG"
}

@test "relance après échec : la note des réplicas n'est pas écrasée, remise à l'échelle d'avant" {
  printf 'urbankiff-api 0 2\nurbankiff-workers 0 1\nurbankiff-pgadmin 0 1\n' > "$FAKE_STATE/deployment.txt"
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  absent -q 'annotate .*=0' "$FAKE_LOG"
  absent -qE '^kubectl scale .* --replicas=0' "$FAKE_LOG"
  grep -q '^kubectl scale deployment/urbankiff-api -n preprod --replicas=2$' "$FAKE_LOG"
}

@test "attente de disponibilité en échec : code 1" {
  FAKE_WAIT_ECHEC=1 FAKE_WAIT_ECHEC_SUR=deployment restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  grep -q '^kubectl scale deployment/urbankiff-api -n preprod --replicas=2$' "$FAKE_LOG"
  absent -q '^curl .*api/health' "$FAKE_LOG"
}

@test "santé en échec : code 1 après la remise des réplicas" {
  FAKE_CURL_ECHEC_SUR=api/health restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 1 ]
  dans_l_ordre '^kubectl scale deployment/urbankiff-api -n preprod --replicas=2$' '^curl .*api/health'
  [[ "$output" != *"l'application reste arrêtée"* ]]
}

@test "jamais de restauration par helm upgrade, de purge ni de suppression de données" {
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 0 ]
  absent -qE 'restauration\.(active|purger|copierFichiers)|--atomic|^helm (upgrade|install)|^kubectl delete (pvc|secret)' "$FAKE_LOG"
}

@test "aucun secret dans le journal des appels ni dans la sortie" {
  restaurer preprod restauration/2026-11-17/
  [ "$status" -eq 0 ]
  absent -q 'valeur-' "$FAKE_LOG"
  [[ "$output" != *"valeur-"* ]]
}
