#!/usr/bin/env bats
# Les listes de clés du script suivent l'inventaire du dépôt (scripts/secrets, lecture seule).

load aide

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  SECRETS="$BATS_TEST_DIRNAME/../../../scripts/secrets"
  # shellcheck disable=SC1090
  source <(sed -n '/^# cles:debut/,/^# cles:fin/p' "$SCRIPT")
  SECRET_KEYS="$(echo $SECRET_KEYS)"
}

noms() { grep -vE '^(#|$)' "$1" | sed -E 's/[ =].*//' | sort -u | tr '\n' ' '; }
trie() { tr ' ' '\n' <<< "$1" | grep -v '^$' | sort -u | tr '\n' ' '; }

@test "SECRET_KEYS contient tous les noms de scripts/secrets/secrets.txt" {
  for nom in $(noms "$SECRETS/secrets.txt"); do
    [[ " $SECRET_KEYS " == *" $nom "* ]] || { echo "absent : $nom"; return 1; }
  done
}

@test "tout nom de SECRET_KEYS absent de secrets.txt appartient au contrat" {
  for nom in $SECRET_KEYS; do
    grep -qE "^$nom( |=)" "$SECRETS/secrets.txt" || [[ " $CLES_CONTRAT " == *" $nom "* ]] || { echo "hors contrat : $nom"; return 1; }
  done
}

@test "SECRET_KEYS contient les deux clés du contrat" {
  [[ " $SECRET_KEYS " == *" PGADMIN_EMAIL "* ]]
  [[ " $SECRET_KEYS " == *" PGADMIN_MOT_DE_PASSE "* ]]
}

@test "VARIABLE_KEYS = variables de prod et de preprod" {
  [ "$(noms "$SECRETS/variables-prod.txt")" = "$(noms "$SECRETS/variables-preprod.txt")" ]
  [ "$(trie "$VARIABLE_KEYS")" = "$(noms "$SECRETS/variables-prod.txt")" ]
}
