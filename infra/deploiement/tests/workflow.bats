#!/usr/bin/env bats
# Invariants de sécurité de .github/workflows/deploiement.yml (actionlint est lancé par make workflow-lint).

setup() { WF="$BATS_TEST_DIRNAME/../../../.github/workflows/deploiement.yml"; }

@test "déclenché seulement par release prereleased et released, jamais pull_request_target" {
  grep -qE '^  release:$' "$WF"
  grep -qE 'types: \[prereleased, released\]' "$WF"
  ! grep -q 'pull_request' "$WF"
}

@test "permissions : aucune par défaut, contents: read partout, packages: write seulement où l'on publie" {
  grep -qE '^permissions: \{\}$' "$WF"
  [ "$(grep -c 'contents: read' "$WF")" -eq 4 ]
  [ "$(grep -c 'packages: write' "$WF")" -eq 2 ]
  ! grep -q 'write-all\|id-token' "$WF"
}

@test "les secrets n'apparaissent que dans deux affectations d'env: (clé SSH, entrée standard)" {
  [ "$(grep -cE '\$\{\{[^}]*secrets' "$WF")" -eq 2 ]
  grep -E '\$\{\{[^}]*secrets' "$WF" | grep -qE '^ +[A-Z_]+: \$\{\{ (secrets\.DEPLOY_SSH_KEY|toJSON\(secrets\)) \}\}$'
  [ "$(grep -E '\$\{\{[^}]*secrets' "$WF" | grep -cE '^ +[A-Z_]+: \$\{\{ (secrets\.DEPLOY_SSH_KEY|toJSON\(secrets\)) \}\}$')" -eq 2 ]
  ! grep -E 'run:.*\$\{\{ *(secrets|vars|github\.event)' "$WF"
}

@test "aucune expression GitHub dans un script run (valeurs passées par env)" {
  awk '/^ +run: \|$/ {bloc=1; next} bloc && /^ {0,9}[^ ]/ {bloc=0} bloc && /\$\{\{/ {print NR": "$0; ko=1} END {exit ko}' "$WF"
  ! grep -E '^ +run: .*\$\{\{' "$WF"
}

@test "jamais xtrace ni écho des secrets" {
  ! grep -nE 'set -[a-z]*x|xtrace|echo .*SECRETS_JSON|echo .*DEPLOY_SSH_KEY' "$WF"
}

@test "nettoyage en always() de la clé et des hôtes connus" {
  grep -qE '^        if: always\(\)$' "$WF"
  grep -q 'rm -f "$RUNNER_TEMP/deploy_key" "$RUNNER_TEMP/known_hosts"' "$WF"
}

@test "clé SSH écrite en 0600 dans RUNNER_TEMP" {
  grep -q 'umask 077' "$WF"
  grep -q '"$RUNNER_TEMP/deploy_key"' "$WF"
}

@test "déploiement : environnement GitHub, concurrence sans annulation, délai maximal" {
  grep -qE 'environment: \$\{\{ needs.meta.outputs.environnement \}\}' "$WF"
  grep -qE 'group: deploiement-\$\{\{ needs.meta.outputs.environnement \}\}' "$WF"
  grep -q 'cancel-in-progress: false' "$WF"
  [ "$(grep -c 'timeout-minutes' "$WF")" -eq 4 ]
}

@test "actions épinglées par version majeure ou plus fine" {
  ! grep -E 'uses:' "$WF" | grep -vE '@v[0-9]+'
}

@test "les jobs de publication appellent les cibles make du poste" {
  grep -q 'run: make images-publier VERSION="$VERSION" ENV="$ENVIRONNEMENT"' "$WF"
  grep -q 'run: make charts-publier VERSION="$VERSION"' "$WF"
}

@test "tags : pré-release vers preprod, release sans suffixe vers prod" {
  grep -q 'environnement=preprod' "$WF"
  grep -q 'environnement=prod' "$WF"
  grep -q 'tag de release attendu : vX.Y.Z (sans suffixe)' "$WF"
}
