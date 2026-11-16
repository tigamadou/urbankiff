#!/usr/bin/env bats
# Commande forcée SSH : refus, configuration, verrou (urbankiff-deploy.sh).

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../urbankiff-deploy.sh"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/appels.log"
  export FAKE_STATE="$BATS_TEST_TMPDIR/etat"
  mkdir -p "$FAKE_STATE"
  : > "$FAKE_LOG"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export URBANKIFF_CONFIG_DIR="$BATS_TEST_TMPDIR/etc"
  export URBANKIFF_LOCK_FILE="$BATS_TEST_TMPDIR/verrou"
  mkdir -p "$URBANKIFF_CONFIG_DIR"
  ecrire_config preprod
  ecrire_config prod
}

ecrire_config() {
  printf 'URBANKIFF_ENV=%s\nGHCR_OWNER=tigamadou\nNAMESPACE=%s\nAPI_SERVER_CIDR=203.0.113.10/32\n' "$1" "$1" > "$URBANKIFF_CONFIG_DIR/deploy.$1.env"
}

lancer() { # <env> <commande>
  SSH_ORIGINAL_COMMAND="$2" run bash "$SCRIPT" "$1" < /dev/null
}

@test "commande vide ou inconnue : refus code 2" {
  for c in "" "ls" "deploy" "deploy 1.0" "deploy 1.0.0; id" 'deploy $(id)' "deploy 1.0.0 extra" "preprod-arret x" "DEPLOY 1.0.0"; do
    lancer preprod "$c"
    [ "$status" -eq 2 ] || { echo "accepté : [$c]"; return 1; }
  done
  [ ! -s "$FAKE_LOG" ]
}

@test "retour à la ligne dans la commande : refus" {
  lancer preprod $'deploy 1.0.0\nid'
  [ "$status" -eq 2 ]
  lancer preprod $'deploy 1.0.0\n'
  [ "$status" -eq 2 ]
}

@test "SSH_ORIGINAL_COMMAND absent : refus" {
  run env -u SSH_ORIGINAL_COMMAND bash "$SCRIPT" preprod < /dev/null
  [ "$status" -eq 2 ]
}

@test "environnement absent ou inconnu en premier argument : erreur" {
  lancer "" "preprod-arret"
  [ "$status" -eq 1 ]
  lancer staging "preprod-arret"
  [ "$status" -eq 1 ]
}

@test "préfixe v accepté et retiré" {
  lancer preprod "deploy v1.2.3"
  [[ "$output" == *"version 1.2.3"* ]]
}

@test "pré-release acceptée en preprod, refusée en prod" {
  lancer preprod "deploy 1.2.3-rc.1"
  [[ "$output" == *"version 1.2.3-rc.1"* ]]
  lancer prod "deploy 1.2.3-rc.1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"pré-release"* ]]
}

@test "preprod-arret et preprod-demarrage refusés en prod" {
  lancer prod "preprod-arret"
  [ "$status" -eq 2 ]
  lancer prod "preprod-demarrage"
  [ "$status" -eq 2 ]
  [ ! -s "$FAKE_LOG" ]
}

@test "configuration absente : erreur" {
  rm "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
  [[ "$output" == *"configuration introuvable"* ]]
}

@test "configuration incomplète : erreur qui nomme la clé" {
  for cle in URBANKIFF_ENV GHCR_OWNER NAMESPACE API_SERVER_CIDR; do
    ecrire_config preprod
    sed -i "/^$cle=/d" "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
    lancer preprod "preprod-arret"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$cle"* ]]
  done
}

@test "configuration : valeurs invalides, clé inconnue, environnement incohérent" {
  ecrire_config preprod
  sed -i 's/^NAMESPACE=.*/NAMESPACE=Pre_Prod/' "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
  ecrire_config preprod
  sed -i 's/^GHCR_OWNER=.*/GHCR_OWNER=a;b/' "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
  ecrire_config preprod
  echo 'AUTRE=1' >> "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
  ecrire_config preprod
  sed -i 's/^URBANKIFF_ENV=.*/URBANKIFF_ENV=prod/' "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
  [[ "$output" == *"URBANKIFF_ENV"* ]]
}

@test "configuration : commentaires et lignes vides tolérés" {
  printf '# commentaire\n\nURBANKIFF_ENV=preprod\nGHCR_OWNER=tigamadou\nNAMESPACE=preprod\nAPI_SERVER_CIDR=203.0.113.10/32\n' > "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "deploy 1.0.0"
  [[ "$output" == *"version 1.0.0"* ]]
}

@test "verrou déjà pris : un déploiement est déjà en cours" {
  FAKE_FLOCK_ECHEC=1 lancer preprod "deploy 1.0.0"
  [ "$status" -eq 1 ]
  [[ "$output" == *"un déploiement est déjà en cours"* ]]
}

@test "le script n'active jamais xtrace ni eval" {
  ! grep -nE 'set -[a-z]*x|xtrace|\beval\b' "$SCRIPT"
}

@test "commande trop longue et configuration mal formée : refus et erreur" {
  lancer preprod "deploy 1.0.0-$(printf 'a%.0s' $(seq 1 120))"
  [ "$status" -eq 2 ]
  echo 'minuscule=1' >> "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
  lancer preprod "preprod-arret"
  [ "$status" -eq 1 ]
}

@test "configuration : API_SERVER_CIDR strictement une IPv4 en /32" {
  for valeur in "203.0.113.10" "203.0.113.10/24" "203.0.113.10/32,10.0.0.1/32" "203.0.113.10/32 " "a.b.c.d/32" '$(id)/32' ""; do
    ecrire_config preprod
    sed -i "s|^API_SERVER_CIDR=.*|API_SERVER_CIDR=$valeur|" "$URBANKIFF_CONFIG_DIR/deploy.preprod.env"
    lancer preprod "preprod-arret"
    [ "$status" -eq 1 ]
    [[ "$output" == *"API_SERVER_CIDR"* ]]
  done
}
