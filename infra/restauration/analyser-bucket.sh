# Analyse d'un bucket extrait dans /b. Exécuté par `sh` dans un conteneur sans réseau (image d'outils) : voir
# analyser_bucket de lib.sh. Écrit un fragment Markdown : décomptes et tailles seulement, jamais un nom de fichier.
cd /b
total=$(find /b -type f | wc -l | tr -d ' ')
if [ "$total" -eq 0 ]; then
  echo "Bucket vide : aucun fichier."
  exit 0
fi

find /b -type f -print0 | xargs -0 file --mime-type -F '|' | sed 's/| */|/' > /tmp/types
find /b -type f -print0 | xargs -0 stat -c '%s|%n' > /tmp/sizes

echo "Fichiers : $total (taille totale : $(awk -F'|' '{ t += $1 } END { print t + 0 }' /tmp/sizes) octets)"
echo
if [ -d /b/uploads ]; then
  echo "Préfixe \`uploads/\` : présent."
else
  echo "Préfixe \`uploads/\` : **absent**."
fi
echo
echo "### Types MIME"
echo
echo "| Type MIME | Fichiers |"
echo "| --- | --- |"
awk -F'|' '{ m = $NF; c[m]++ } END { for (m in c) print "| " m " | " c[m] " |" }' /tmp/types | sort
echo
echo "### Fichiers hors \`uploads/\` (par répertoire de premier niveau)"
echo
hors=$(awk -F'|' '{
  s = $1; p = substr($0, length($1) + 2); sub(/^\/b\//, "", p)
  if (p ~ /^uploads\//) next
  n = index(p, "/"); d = (n ? substr(p, 1, n - 1) : "(racine)")
  c[d]++; t[d] += s
} END { for (d in c) print "| " d " | " c[d] " | " t[d] " |" }' /tmp/sizes | sort)
if [ -z "$hors" ]; then
  echo "Aucun."
else
  echo "| Répertoire | Fichiers | Taille (octets) |"
  echo "| --- | --- | --- |"
  echo "$hors"
fi
echo
echo "### Exécutables"
echo
echo "- Fichiers avec le bit d'exécution : $(find /b -type f -perm /111 | wc -l | tr -d ' ')"
echo "- Binaires (ELF, Mach-O, bibliothèques partagées, PE) : $(grep -cE '\|(application/(x-executable|x-pie-executable|x-sharedlib|x-mach-binary|x-dosexec|vnd\.microsoft\.portable-executable))$' /tmp/types || true)"
echo "- Scripts (shell, PHP, Python, Perl, Ruby) : $(grep -cE '\|(text/x-shellscript|text/x-php|application/x-httpd-php|text/x-script\.python|text/x-python|text/x-perl|text/x-ruby)$' /tmp/types || true)"
exts=$(awk -F'|' '{
  n = split($1, a, "."); e = tolower(a[n])
  if (n > 1 && (e == "sh" || e == "php" || e == "py" || e == "exe" || e == "so")) c[e]++
} END { for (e in c) print "| " e " | " c[e] " |" }' /tmp/types | sort)
if [ -z "$exts" ]; then
  echo "- Extensions \`.sh .php .py .exe .so\` : aucune"
else
  echo
  echo "| Extension | Fichiers |"
  echo "| --- | --- |"
  echo "$exts"
fi
echo
echo "### Liens symboliques"
echo
echo "- Liens symboliques : $(find /b -type l | wc -l | tr -d ' ')"
echo
echo "### Incohérences sous \`uploads/\`"
echo
echo "- Fichiers dont le type n'est pas une image : $(awk -F'|' '$1 ~ /^\/b\/uploads\// && $NF !~ /^image\// { n++ } END { print n + 0 }' /tmp/types)"
echo "- Fichiers à extension d'image dont le contenu n'est pas une image : $(awk -F'|' '{
  m = split($1, a, "."); e = tolower(a[m])
  if ($1 ~ /^\/b\/uploads\// && m > 1 && (e == "png" || e == "jpg" || e == "jpeg" || e == "gif" || e == "webp" || e == "svg" || e == "bmp") && $NF !~ /^image\//) n++
} END { print n + 0 }' /tmp/types)"
