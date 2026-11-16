#!/usr/bin/env bats

load aide

teardown() {
  nettoyer
}

setup() {
  charger_lib
}

@test "version_pg_du_dump : dump absent" {
  run version_pg_du_dump /nexiste/pas.dump
  [ "$status" -ne 0 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "version_pg_du_dump : argument vide" {
  run version_pg_du_dump ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "version_pg_du_dump : fichier qui n'est pas un dump" {
  echo "pas un dump" > "$BATS_TEST_TMPDIR/faux.dump"
  run version_pg_du_dump "$BATS_TEST_TMPDIR/faux.dump"
  [ "$status" -ne 0 ]
  [[ "$output" == *"illisible"* ]]
}

@test "version_pg_du_dump : dump plus récent que le client épinglé" {
  # En-tête de format custom (PGDMP) annonçant une version d'archive inconnue du client.
  printf 'PGDMP\001\377\000' > "$BATS_TEST_TMPDIR/futur.dump"
  run version_pg_du_dump "$BATS_TEST_TMPDIR/futur.dump"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plus récent"* ]]
}

@test "demarrer_base_jetable, version_pg_du_dump et nettoyer" {
  demarrer_base_jetable 15 source
  docker exec "$(conteneur source)" pg_dump -U postgres -Fc app > "$BATS_TEST_TMPDIR/vide.dump"
  run version_pg_du_dump "$BATS_TEST_TMPDIR/vide.dump"
  [ "$status" -eq 0 ]
  [[ "$output" == 15.* ]]
  [ -n "$(docker ps -q --filter "label=$REST_LABEL")" ]
  nettoyer
  [ -z "$(docker ps -aq --filter "label=$REST_LABEL")" ]
  [ -z "$(docker network ls -q --filter "label=$REST_LABEL")" ]
}

@test "verifier_version_supportee : acceptée jusqu'à la majeure épinglée" {
  PG_MAJEURE_MAX=17 run verifier_version_supportee 15.4
  [ "$status" -eq 0 ]
  PG_MAJEURE_MAX=17 run verifier_version_supportee 17.2
  [ "$status" -eq 0 ]
}

@test "verifier_version_supportee : refusée au-delà de la majeure épinglée" {
  PG_MAJEURE_MAX=17 run verifier_version_supportee 18.1
  [ "$status" -ne 0 ]
  [[ "$output" == *"plus récent"* ]]
}

@test "ecrire_rapport : écrit sous RAPPORTS_DIR avec la date et le nom" {
  run bash -c ". '$RESTAURATION_DIR/lib.sh'; export RAPPORTS_DIR='$BATS_TEST_TMPDIR/r'; echo contenu | ecrire_rapport essai"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/r/$(date +%F)-essai.md" ]
  [ "$(cat "$output")" = "contenu" ]
}

@test "comparer_decomptes : égaux" {
  printf 'public.a|1\npublic.b|2\n' > "$BATS_TEST_TMPDIR/s"
  printf 'public.b|2\npublic.a|1\n' > "$BATS_TEST_TMPDIR/c"
  run comparer_decomptes "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "comparer_decomptes : écart de décompte, table disparue, table en trop" {
  printf 'public.a|1\npublic.b|2\npublic.c|3\n' > "$BATS_TEST_TMPDIR/s"
  printf 'public.a|1\npublic.b|1\npublic.d|4\n' > "$BATS_TEST_TMPDIR/c"
  run comparer_decomptes "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"public.b|2|1"* ]]
  [[ "$output" == *"public.c|3|absente"* ]]
  [[ "$output" == *"public.d|absente|4"* ]]
}

@test "comparer_decomptes : source vide et cible non vide" {
  : > "$BATS_TEST_TMPDIR/s"
  printf 'public.a|1\n' > "$BATS_TEST_TMPDIR/c"
  run comparer_decomptes "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"public.a|absente|1"* ]]
}

@test "conclure_comparaison : décomptes égaux" {
  printf 'public.a|1\n' > "$BATS_TEST_TMPDIR/s"
  cp "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  run conclure_comparaison "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [ "$status" -eq 0 ]
  [ "$output" = "Restauration répétée : décomptes égaux" ]
}

@test "conclure_comparaison : liste des tables en écart, code non nul" {
  printf 'public.a|1\npublic.b|2\n' > "$BATS_TEST_TMPDIR/s"
  printf 'public.a|1\npublic.b|0\n' > "$BATS_TEST_TMPDIR/c"
  run conclure_comparaison "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"- public.b (source 2, restauré 0)"* ]]
}

@test "conclure_comparaison : source sans table" {
  : > "$BATS_TEST_TMPDIR/s"
  run conclure_comparaison "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/s"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aucune table"* ]]
}

@test "tableau_comparaison : marque les écarts" {
  printf 'public.a|1\npublic.b|2\n' > "$BATS_TEST_TMPDIR/s"
  printf 'public.a|1\npublic.b|0\n' > "$BATS_TEST_TMPDIR/c"
  run tableau_comparaison "$BATS_TEST_TMPDIR/s" "$BATS_TEST_TMPDIR/c"
  [[ "$output" == *"| public.a | 1 | 1 | oui |"* ]]
  [[ "$output" == *"| public.b | 2 | 0 | NON |"* ]]
}
