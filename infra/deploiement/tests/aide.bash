# Aides communes des bats du déploiement.
noms_secrets_complets() {
  grep -vE '^(#|$)' "$BATS_TEST_DIRNAME/../../../scripts/secrets/secrets.txt" | cut -d' ' -f1 | awk '!vu[$0]++'
}

# `! grep` au milieu d'un test ne le fait pas échouer (errexit ignore la négation) : absent() échoue si grep trouve.
absent() { ! grep "$@"; }
