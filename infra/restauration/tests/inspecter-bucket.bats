#!/usr/bin/env bats

load aide

setup_file() {
  source "$BATS_TEST_DIRNAME/aide.bash"
  export RAPPORTS_DIR="$BATS_FILE_TMPDIR/rapports"
  dump_vide
  b="$BATS_FILE_TMPDIR/bucket"
  mkdir -p "$b/uploads" "$b/outils"
  printf '\211PNG\r\n\032\n\000\000\000\015IHDR\000\000\000\001\000\000\000\001\010\006\000\000\000' > "$b/uploads/a.png"
  printf '\377\330\377\340\000\020JFIF\000\001\001\000\000\001\000\001\000\000' > "$b/uploads/b.jpg"
  printf '<?php echo 1;\n' > "$b/uploads/evil.php"
  printf 'ceci n est pas une image\n' > "$b/uploads/fake.png"
  ln -s a.png "$b/uploads/lien.png"
  printf '#!/bin/sh\necho salut\n' > "$b/outils/run.sh"
  chmod +x "$b/outils/run.sh"
  printf 'notes\n' > "$b/notes.txt"
  mkdir -p "$BATS_FILE_TMPDIR/sans-uploads" "$BATS_FILE_TMPDIR/vide"
  printf 'x\n' > "$BATS_FILE_TMPDIR/sans-uploads/x.txt"
  for cas in bucket sans-uploads vide; do
    bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_VIDE" "$BATS_FILE_TMPDIR/$cas" > "$BATS_FILE_TMPDIR/sortie-$cas" 2> /dev/null
    sed -n 's/^Rapport : //p' "$BATS_FILE_TMPDIR/sortie-$cas" > "$BATS_FILE_TMPDIR/chemin-$cas"
    cp "$(cat "$BATS_FILE_TMPDIR/chemin-$cas")" "$BATS_FILE_TMPDIR/rapport-$cas.md"
  done
}

setup() {
  charger_lib
}

@test "bucket fabriqué : décomptes, types MIME et préfixe uploads" {
  r="$BATS_FILE_TMPDIR/rapport-bucket.md"
  grep -q '^Fichiers : 6 ' "$r"
  grep -q 'uploads/` : présent' "$r"
  grep -q '^| image/png | 1 |' "$r"
  grep -q '^| image/jpeg | 1 |' "$r"
  grep -q '^| text/x-php | 1 |' "$r"
  grep -q '^| text/x-shellscript | 1 |' "$r"
  grep -q '^| text/plain | 2 |' "$r"
}

@test "bucket fabriqué : fichiers hors uploads par répertoire de premier niveau" {
  r="$BATS_FILE_TMPDIR/rapport-bucket.md"
  grep -q '^| outils | 1 | 21 |' "$r"
  grep -q '^| (racine) | 1 | 6 |' "$r"
}

@test "bucket fabriqué : exécutables, extensions, liens et incohérences" {
  r="$BATS_FILE_TMPDIR/rapport-bucket.md"
  grep -q "bit d'exécution : 1" "$r"
  grep -q 'Binaires .* : 0' "$r"
  grep -q 'Scripts .* : 2' "$r"
  grep -q '^| php | 1 |' "$r"
  grep -q '^| sh | 1 |' "$r"
  grep -q 'Liens symboliques : 1' "$r"
  grep -q "n'est pas une image : 2" "$r"
  grep -q "contenu n'est pas une image : 1" "$r"
}

@test "bucket fabriqué : aucun nom de fichier dans le rapport" {
  r="$BATS_FILE_TMPDIR/rapport-bucket.md"
  ! grep -qE 'evil|fake|notes|lien|run\.sh|a\.png|b\.jpg' "$r"
}

@test "bucket sans uploads : préfixe signalé absent" {
  grep -q 'uploads/` : \*\*absent\*\*' "$BATS_FILE_TMPDIR/rapport-sans-uploads.md"
  grep -q '^| (racine) | 1 | 2 |' "$BATS_FILE_TMPDIR/rapport-sans-uploads.md"
  grep -q 'Extensions .* aucune' "$BATS_FILE_TMPDIR/rapport-sans-uploads.md"
}

@test "bucket vide" {
  grep -q 'Bucket vide' "$BATS_FILE_TMPDIR/rapport-vide.md"
}

@test "dossier de bucket inexistant : échec propre sans rien laisser" {
  run bash "$RESTAURATION_DIR/inspecter-sauvegarde.sh" "$DUMP_VIDE" /nexiste/pas
  [ "$status" -eq 1 ]
  [[ "$output" == *"introuvable"* ]]
  aucun_conteneur_restant
}

@test "le bucket n'est pas modifié" {
  [ "$(find "$BATS_FILE_TMPDIR/bucket" | wc -l)" -eq 10 ]
}
