# Aides communes des bats du déploiement. `secrets.txt` ne gagne PGADMIN_* qu'avec le lot 6 : ces clés du contrat sont
# ajoutées ici pour que les tests restent verts avant et après sa fusion.
CLES_CONTRAT="PGADMIN_EMAIL PGADMIN_MOT_DE_PASSE"

noms_secrets_complets() {
  {
    grep -vE '^(#|$)' "$BATS_TEST_DIRNAME/../../../scripts/secrets/secrets.txt" | cut -d' ' -f1
    tr ' ' '\n' <<< "$CLES_CONTRAT"
  } | grep -v '^$' | awk '!vu[$0]++'
}

# `! grep` au milieu d'un test ne le fait pas échouer (errexit ignore la négation) : absent() échoue si grep trouve.
absent() { ! grep "$@"; }
