#!/usr/bin/env bats
# Aides communes de restaurer et exporter-anonyme : version déployée, rendu, lancement et suivi d'un Job.
# Les fonctions sont appelées par une commande minimale du script, avec de faux helm et kubectl.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  mkdir -p "$FAKE_STATE"
  : > "$FAKE_LOG"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export URBANKIFF_JOB_TENTATIVES=3
  # Le script est sourcé sans son appel final à main : les fonctions s'exécutent dans le même shell.
  sed '$d' "$SCRIPT" > "$BATS_TEST_TMPDIR/fonctions.sh"
  TMP="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMP"
}

appeler() { # <fonction> [args] : exécutée dans un sous-shell qui a chargé le script
  run bash -c 'set -euo pipefail; source "$1"; NAMESPACE=preprod; ENV=preprod; OWNER=tigamadou; TMP="$2"; shift 2; "$@"' _ "$BATS_TEST_TMPDIR/fonctions.sh" "$TMP" "$@"
}

@test "le fichier de fonctions se termine bien par l'appel à main" {
  [ "$(tail -1 "$SCRIPT")" = 'main "$@"' ]
}

@test "version_deployee : lit image.etiquette de la release urbankiff et positionne VERSION (guillemets acceptés)" {
  printf 'image:\n  depot: x\n  etiquette: "2.0.1-rc.1"\n' > "$FAKE_STATE/values-urbankiff.yaml"
  run bash -c 'set -euo pipefail; source "$1"; NAMESPACE=preprod; version_deployee; echo "V=$VERSION"' _ "$BATS_TEST_TMPDIR/fonctions.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"V=2.0.1-rc.1"* ]]
  grep -q '^helm get values urbankiff -n preprod -o yaml$' "$FAKE_LOG"
}

@test "version_deployee : absente, invalide ou release introuvable : erreur" {
  printf 'image:\n  depot: x\n' > "$FAKE_STATE/values-urbankiff.yaml"
  appeler version_deployee
  [ "$status" -eq 1 ]
  [[ "$output" == *"version introuvable"* ]]
  printf 'image:\n  etiquette: latest\n' > "$FAKE_STATE/values-urbankiff.yaml"
  appeler version_deployee
  [ "$status" -eq 1 ]
  [[ "$output" == *"version introuvable"* ]]
  printf 'etiquette: 1.2.3\n' > "$FAKE_STATE/values-urbankiff.yaml"
  appeler version_deployee
  [ "$status" -eq 1 ]
  rm "$FAKE_STATE/values-urbankiff.yaml"
  appeler version_deployee
  [ "$status" -eq 1 ]
  [[ "$output" == *"version introuvable"* ]]
}

@test "rendre_job : valeurs de la release, deux -f dans l'ordre, --show-only exact, --set transmis" {
  : > "$FAKE_STATE/values-urbankiff-donnees.yaml"
  appeler rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml --set restauration.prefixe=restauration/2026-11-17/
  [ "$status" -eq 0 ]
  grep -q "^helm get values urbankiff-donnees -n preprod -o yaml$" "$FAKE_LOG"
  grep -qF "helm template urbankiff-donnees $TMP/charts/urbankiff-donnees -n preprod -f $TMP/charts/urbankiff-donnees/values-preprod.yaml -f $TMP/valeurs-urbankiff-donnees.yaml --show-only templates/restauration-job.yaml --set restauration.prefixe=restauration/2026-11-17/" "$FAKE_LOG"
}

@test "rendre_job : release introuvable, rendu en échec, rendu vide : erreur sans apply" {
  appeler rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml
  [ "$status" -eq 1 ]
  : > "$FAKE_STATE/values-urbankiff-donnees.yaml"
  FAKE_TEMPLATE_ECHEC=1 appeler rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml
  [ "$status" -eq 1 ]
  : > "$FAKE_STATE/rendu-restauration-job.yaml"
  appeler rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml
  [ "$status" -eq 1 ]
  [[ "$output" == *"le Job n'est pas rendu"* ]]
  ! grep -q '^kubectl apply' "$FAKE_LOG"
}

@test "lancer_job : supprime d'abord un Job homonyme, puis crée par apply" {
  run bash -c 'set -euo pipefail; source "$1"; NAMESPACE=preprod; MANIFESTE="kind: Job"; lancer_job urbankiff-restauration' _ "$BATS_TEST_TMPDIR/fonctions.sh"
  [ "$status" -eq 0 ]
  d="$(grep -n '^kubectl delete job urbankiff-restauration -n preprod --ignore-not-found$' "$FAKE_LOG" | cut -d: -f1)"
  a="$(grep -n '^kubectl apply -n preprod -f -$' "$FAKE_LOG" | cut -d: -f1)"
  [ "$d" -lt "$a" ]
  grep -q '^STDIN apply 10$' "$FAKE_LOG"
}

@test "suivre_job : succès avec le journal de fin, Job supprimé" {
  echo "1/" > "$FAKE_STATE/job-urbankiff-restauration.txt"
  echo "restauration terminée" > "$FAKE_STATE/logs-urbankiff-restauration.txt"
  appeler suivre_job urbankiff-restauration "restauration terminée"
  [ "$status" -eq 0 ]
  grep -q '^kubectl get job urbankiff-restauration -n preprod -o jsonpath={.status.succeeded}/{.status.failed}$' "$FAKE_LOG"
  grep -q '^kubectl logs job/urbankiff-restauration -n preprod --all-containers --tail=200$' "$FAKE_LOG"
  grep -q '^kubectl delete job urbankiff-restauration -n preprod --ignore-not-found$' "$FAKE_LOG"
}

@test "suivre_job : succès sans journal de fin exigé" {
  echo "1/" > "$FAKE_STATE/job-urbankiff-apres-restauration.txt"
  appeler suivre_job urbankiff-apres-restauration ""
  [ "$status" -eq 0 ]
  grep -q '^kubectl delete job urbankiff-apres-restauration' "$FAKE_LOG"
}

@test "suivre_job : succès mais journal de fin absent : erreur, Job conservé" {
  echo "1/" > "$FAKE_STATE/job-urbankiff-restauration.txt"
  echo "autre chose" > "$FAKE_STATE/logs-urbankiff-restauration.txt"
  appeler suivre_job urbankiff-restauration "restauration terminée"
  [ "$status" -eq 1 ]
  [[ "$output" == *"restauration terminée"* ]]
  ! grep -q '^kubectl delete' "$FAKE_LOG"
}

@test "suivre_job : échec : journaux affichés, erreur, Job conservé" {
  echo "0/1" > "$FAKE_STATE/job-urbankiff-restauration.txt"
  echo "pg_restore : boum" > "$FAKE_STATE/logs-urbankiff-restauration.txt"
  appeler suivre_job urbankiff-restauration "restauration terminée"
  [ "$status" -eq 1 ]
  [[ "$output" == *"pg_restore : boum"* ]]
  [[ "$output" == *"a échoué"* ]]
  ! grep -q '^kubectl delete' "$FAKE_LOG"
}

@test "suivre_job : délai dépassé après URBANKIFF_JOB_TENTATIVES, Job conservé" {
  appeler suivre_job urbankiff-restauration "restauration terminée"
  [ "$status" -eq 1 ]
  [[ "$output" == *"après le délai"* ]]
  [ "$(grep -c '^kubectl get job' "$FAKE_LOG")" -eq 3 ]
  [ "$(grep -c '^sleep 5$' "$FAKE_LOG")" -eq 3 ]
  ! grep -q '^kubectl delete' "$FAKE_LOG"
}
