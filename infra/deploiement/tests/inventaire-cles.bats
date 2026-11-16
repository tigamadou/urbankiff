#!/usr/bin/env bats
# Les listes de clés du script suivent l'inventaire du dépôt (scripts/secrets, lecture seule).

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  SECRETS="$BATS_TEST_DIRNAME/../../../scripts/secrets"
  # shellcheck disable=SC1090
  source <(sed -n '/^# cles:debut/,/^# cles:fin/p' "$SCRIPT")
}

noms() { grep -vE '^(#|$)' "$1" | sed -E 's/[ =].*//' | sort -u | tr '\n' ' '; }
trie() { tr ' ' '\n' <<< "$1" | grep -v '^$' | sort -u | tr '\n' ' '; }

@test "SECRET_KEYS = scripts/secrets/secrets.txt" {
  [ "$(trie "$SECRET_KEYS")" = "$(noms "$SECRETS/secrets.txt")" ]
}

@test "VARIABLE_KEYS = variables de prod et de preprod" {
  [ "$(noms "$SECRETS/variables-prod.txt")" = "$(noms "$SECRETS/variables-preprod.txt")" ]
  [ "$(trie "$VARIABLE_KEYS")" = "$(noms "$SECRETS/variables-prod.txt")" ]
}
