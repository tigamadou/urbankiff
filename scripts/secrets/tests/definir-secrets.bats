#!/usr/bin/env bats
# Tests de scripts/secrets/definir-secrets.sh avec un faux gh : aucune valeur ne doit apparaître en argument ni en sortie.

REPERE='Valeur-Repere-Xq7=avec espace'

setup() {
  RACINE="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SCRIPT="$RACINE/scripts/secrets/definir-secrets.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export FAKE_GH_ETAT="$BATS_TEST_TMPDIR/gh.etat"
  : > "$FAKE_GH_LOG"
  : > "$FAKE_GH_ETAT"
  export SECRETS_LISTE="$BATS_TEST_TMPDIR/secrets.txt"
  export VARIABLES_DOSSIER="$BATS_TEST_TMPDIR"
  printf 'GEN_A aleatoire:29\nGEN_B aleatoire-hex:16\nEXT_A saisie\n' > "$SECRETS_LISTE"
  printf 'VAR_A=valeur publique\n' > "$BATS_TEST_TMPDIR/variables-prod.txt"
  printf '%s\n' '#!/usr/bin/env bash' "R='$REPERE'" 'printf "%s" "${R:0:$2}"' > "$BATS_TEST_TMPDIR/generateur"
  chmod +x "$BATS_TEST_TMPDIR/generateur"
  export GENERATEUR="$BATS_TEST_TMPDIR/generateur"
  export SECRETS_TTY="$BATS_TEST_TMPDIR/saisie"
  printf 'saisie-externe\n' > "$SECRETS_TTY"
}

@test "usage invalide → code 2 sans appel à gh" {
  run "$SCRIPT" staging tigamadou/urbankiff
  [ "$status" -eq 2 ]
  run "$SCRIPT" prod ""
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_GH_LOG" ]
}

@test "chaque secret aleatoire est pose avec --env et --repo" {
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q '^ARGS secret set GEN_A --env prod --repo tigamadou/urbankiff$' "$FAKE_GH_LOG"
  grep -q '^ARGS secret set GEN_B --env prod --repo tigamadou/urbankiff$' "$FAKE_GH_LOG"
}

@test "aucune valeur n'apparait en argument ni en sortie" {
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  ! grep -qF "$REPERE" "$FAKE_GH_LOG" || false
  ! grep -qF 'saisie-externe' "$FAKE_GH_LOG" || false
  [[ "$output" != *"$REPERE"* ]]
  [[ "$output" != *saisie-externe* ]]
}

@test "valeur avec = et espace posee intacte" {
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q "^STDIN GEN_A ${#REPERE}\$" "$FAKE_GH_LOG"
  grep -q '^STDIN EXT_A 14$' "$FAKE_GH_LOG"
}

@test "saisie vide → secret laisse tel quel" {
  printf '\n' > "$SECRETS_TTY"
  echo "secret EXT_A" >> "$FAKE_GH_ETAT"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  ! grep -q '^ARGS secret set EXT_A' "$FAKE_GH_LOG" || false
}

@test "saisie interrompue → rien n'est pose" {
  : > "$SECRETS_TTY"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -ne 0 ]
  ! grep -q '^ARGS secret set EXT_A' "$FAKE_GH_LOG" || false
}

@test "SEULEMENT limite les secrets definis" {
  echo "secret GEN_B" >> "$FAKE_GH_ETAT"
  echo "secret EXT_A" >> "$FAKE_GH_ETAT"
  SEULEMENT="GEN_A VAR_A" run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q '^ARGS secret set GEN_A ' "$FAKE_GH_LOG"
  ! grep -q '^ARGS secret set GEN_B ' "$FAKE_GH_LOG" || false
  ! grep -q '^ARGS secret set EXT_A ' "$FAKE_GH_LOG" || false
}

@test "variables posees avec gh variable set" {
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q '^ARGS variable set VAR_A --env prod --repo tigamadou/urbankiff --body valeur publique$' "$FAKE_GH_LOG"
}

@test "nom attendu absent de gh secret list → code 1" {
  printf '\n' > "$SECRETS_TTY"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 1 ]
  [[ "$output" == *EXT_A* ]]
}

@test "generateur en echec → rien n'est pose" {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 3' > "$GENERATEUR"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -ne 0 ]
  ! grep -q '^ARGS secret set GEN_A' "$FAKE_GH_LOG" || false
}

@test "valeur generee trop courte → rien n'est pose" {
  printf '%s\n' '#!/usr/bin/env bash' "printf 'abc'" > "$GENERATEUR"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -ne 0 ]
  ! grep -q '^ARGS secret set GEN_A' "$FAKE_GH_LOG" || false
}

@test "secret aleatoire deja present → pas regenere" {
  echo "secret GEN_A" >> "$FAKE_GH_ETAT"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  ! grep -q '^ARGS secret set GEN_A ' "$FAKE_GH_LOG" || false
  grep -q '^ARGS secret set GEN_B ' "$FAKE_GH_LOG"
}

@test "FORCER=1 ou SEULEMENT regenere un secret aleatoire present" {
  echo "secret GEN_A" >> "$FAKE_GH_ETAT"
  FORCER=1 run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q '^ARGS secret set GEN_A ' "$FAKE_GH_LOG"
  : > "$FAKE_GH_LOG"
  SEULEMENT="GEN_A" run "$SCRIPT" prod tigamadou/urbankiff
  grep -q '^ARGS secret set GEN_A ' "$FAKE_GH_LOG"
}

@test "generateur par defaut : conteneur sans journal ni reseau" {
  unset GENERATEUR
  export FAKE_DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  run "$SCRIPT" prod tigamadou/urbankiff
  [ "$status" -eq 0 ]
  grep -q -- '--log-driver none' "$FAKE_DOCKER_LOG"
  grep -q -- '--network none' "$FAKE_DOCKER_LOG"
}
