#!/usr/bin/env bats
# Invariants de sécurité de restauration.yml et copie-prod-preprod.yml (actionlint est lancé par make workflow-lint).

setup() {
  DOSSIER="$BATS_TEST_DIRNAME/../../../.github/workflows"
  RESTAURATION="$DOSSIER/restauration.yml"
  COPIE="$DOSSIER/copie-prod-preprod.yml"
  FICHIERS="$RESTAURATION $COPIE"
}

chaque() { local f; for f in $FICHIERS; do "$@" "$f" || { echo "en échec sur $f"; return 1; }; done; }

declenche_a_la_main() { grep -qE '^  workflow_dispatch:' "$1" && absent -qE 'pull_request|schedule:|push:|release:' "$1"; }
absent() { ! grep "$@"; }

@test "déclenchés à la main seulement" {
  chaque declenche_a_la_main
}

@test "permissions : aucune par défaut, contents: read par job, jamais d'écriture" {
  grep -qE '^permissions: \{\}$' "$RESTAURATION"
  grep -qE '^permissions: \{\}$' "$COPIE"
  [ "$(grep -c 'contents: read' "$RESTAURATION")" -eq 1 ]
  [ "$(grep -c 'contents: read' "$COPIE")" -eq 2 ]
  absent -qE 'write|id-token' "$RESTAURATION"
  absent -qE 'write|id-token' "$COPIE"
}

@test "un seul secret référencé par job : DEPLOY_SSH_KEY ; jamais toJSON" {
  absent -q 'toJSON' "$RESTAURATION"
  absent -q 'toJSON' "$COPIE"
  [ "$(grep -cE '\$\{\{[^}]*secrets' "$RESTAURATION")" -eq 1 ]
  [ "$(grep -cE '\$\{\{[^}]*secrets' "$COPIE")" -eq 2 ]
  [ "$(grep -E '\$\{\{[^}]*secrets' "$RESTAURATION" "$COPIE" | grep -cE '^[^:]+: +DEPLOY_SSH_KEY: \$\{\{ secrets\.DEPLOY_SSH_KEY \}\}$')" -eq 3 ]
}

expression_dans_run() {
  awk '/^ +run: \|$/ {bloc=1; next} bloc && /^ {0,9}[^ ]/ {bloc=0} bloc && /\$\{\{/ {print NR": "$0; ko=1} END {exit ko}' "$1" \
    && ! grep -E '^ +run: .*\$\{\{' "$1"
}

@test "aucune expression GitHub dans un script run (valeurs passées par env)" {
  chaque expression_dans_run
}

@test "jamais xtrace ni écho de la clé" {
  absent -nE 'set -[a-z]*x|xtrace|echo .*DEPLOY_SSH_KEY' "$RESTAURATION" "$COPIE"
}

@test "nettoyage en always() de la clé et des hôtes connus, un par job" {
  [ "$(grep -cE '^        if: always\(\)$' "$RESTAURATION")" -eq 1 ]
  [ "$(grep -cE '^        if: always\(\)$' "$COPIE")" -eq 2 ]
  [ "$(grep -c 'rm -f "$RUNNER_TEMP/deploy_key" "$RUNNER_TEMP/known_hosts"' "$COPIE")" -eq 2 ]
  grep -q 'rm -f "$RUNNER_TEMP/deploy_key" "$RUNNER_TEMP/known_hosts"' "$RESTAURATION"
}

@test "clé SSH écrite en 0600 dans RUNNER_TEMP, un par job" {
  [ "$(grep -c 'umask 077' "$RESTAURATION")" -eq 1 ]
  [ "$(grep -c 'umask 077' "$COPIE")" -eq 2 ]
}

@test "restauration : environnement choisi, concurrence sans annulation, délai, entrées typées" {
  grep -q 'environment: ${{ inputs.environnement }}' "$RESTAURATION"
  grep -q 'group: deploiement-${{ inputs.environnement }}' "$RESTAURATION"
  grep -q 'cancel-in-progress: false' "$RESTAURATION"
  grep -q 'timeout-minutes: 60' "$RESTAURATION"
  grep -qE '^        type: choice$' "$RESTAURATION"
  grep -qE '^        options: \[preprod, prod\]$' "$RESTAURATION"
  grep -qE '^        type: string$' "$RESTAURATION"
}

@test "copie : export en prod puis restauration en preprod, needs, concurrences, délais" {
  p="$(grep -n '^    environment: prod$' "$COPIE" | cut -d: -f1)"
  q="$(grep -n '^    environment: preprod$' "$COPIE" | cut -d: -f1)"
  [ "$p" -lt "$q" ]
  grep -q '^    needs: exporter$' "$COPIE"
  grep -q 'group: deploiement-prod' "$COPIE"
  grep -q 'group: deploiement-preprod' "$COPIE"
  [ "$(grep -c 'cancel-in-progress: false' "$COPIE")" -eq 2 ]
  [ "$(grep -c 'timeout-minutes' "$COPIE")" -eq 2 ]
  grep -q 'date -u +%F' "$COPIE"
  grep -q 'GITHUB_OUTPUT' "$COPIE"
}

@test "actions épinglées par version majeure ou plus fine" {
  absent -q 'uses: [^@]*$' "$RESTAURATION" "$COPIE"
  grep -hE 'uses:' "$RESTAURATION" "$COPIE" | absent -vE '@v[0-9]+'
}

@test "checkout sans identifiants persistés" {
  [ "$(grep -c 'persist-credentials: false' "$RESTAURATION")" -eq 1 ]
  [ "$(grep -c 'persist-credentials: false' "$COPIE")" -eq 2 ]
}

@test "commandes SSH exactes, sans entrée standard" {
  grep -q '"deploy@$DEPLOY_HOST" restaurer "$PREFIXE" < /dev/null' "$RESTAURATION"
  grep -q '"deploy@$DEPLOY_HOST" exporter-anonyme "$DATE" < /dev/null' "$COPIE"
  grep -q '"deploy@$DEPLOY_HOST" restaurer "restauration/$DATE-prod-anonyme/" < /dev/null' "$COPIE"
}

valide_avant_ssh() {
  awk '/DEPLOY_HOST" =~/ {v=NR} /ssh -i/ {s=NR} END {exit !(v && s && v<s)}' "$1"
}

@test "DEPLOY_HOST validé avant ssh ; préfixe et environnement validés" {
  chaque valide_avant_ssh
  grep -qF 'ENVIRONNEMENT" =~ ^(prod|preprod)$' "$RESTAURATION"
  grep -q 'PREFIXE" =~ ^restauration/' "$RESTAURATION"
  grep -q 'DATE" =~ ' "$COPIE"
}
