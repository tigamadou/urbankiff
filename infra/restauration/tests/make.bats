#!/usr/bin/env bats

load aide

setup() {
  charger_lib
  cd "$RESTAURATION_DIR/../.."
}

@test "sauvegarde-inspecter sans DUMP : code 2 et usage" {
  run make sauvegarde-inspecter
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage : make sauvegarde-inspecter DUMP=<chemin> [BUCKET=<dossier>]"* ]]
}

@test "sauvegarde-repeter sans DUMP : code 2 et usage" {
  run make sauvegarde-repeter
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage : make sauvegarde-repeter DUMP=<chemin>"* ]]
}

@test "sauvegarde-inspecter avec un DUMP inexistant : échec propre" {
  run make sauvegarde-inspecter DUMP=/nexiste/pas.dump
  [ "$status" -ne 0 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "sauvegarde-repeter avec un DUMP inexistant : échec propre" {
  run make sauvegarde-repeter DUMP=/nexiste/pas.dump
  [ "$status" -ne 0 ]
  [[ "$output" == *"introuvable"* ]]
}

@test "make -n : chemins absolus et scripts attendus" {
  run make -n sauvegarde-inspecter DUMP=infra/a.dump BUCKET=infra/b
  [ "$status" -eq 0 ]
  [[ "$output" == *"infra/restauration/inspecter-sauvegarde.sh \"$PWD/infra/a.dump\" \"$PWD/infra/b\""* ]]
  run make -n sauvegarde-repeter DUMP=infra/a.dump
  [ "$status" -eq 0 ]
  [[ "$output" == *"infra/restauration/repeter-sauvegarde.sh \"$PWD/infra/a.dump\""* ]]
}

@test "make -n sans BUCKET : pas d'argument de bucket" {
  run make -n sauvegarde-inspecter DUMP=infra/a.dump
  [ "$status" -eq 0 ]
  [[ "$output" == *"inspecter-sauvegarde.sh \"$PWD/infra/a.dump\""* ]]
  [[ "$output" != *"b\""* ]]
}

@test "cibles documentées dans le help" {
  run make help
  [[ "$output" == *"sauvegarde-inspecter"* ]]
  [[ "$output" == *"sauvegarde-repeter"* ]]
  [[ "$output" == *"restauration-test"* ]]
}
