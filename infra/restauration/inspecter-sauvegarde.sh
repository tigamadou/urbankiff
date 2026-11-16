#!/usr/bin/env bash
# Inspecte une sauvegarde de prod (dump PostgreSQL au format custom, dossier de bucket optionnel) dans des conteneurs
# jetables et écrit un rapport Markdown dans infra/restauration/rapports/ (dossier ignoré par git).
# Le rapport ne contient que des noms de structure, des décomptes et des préfixes d'URL : jamais de valeur de ligne.
# Usage : inspecter-sauvegarde.sh <dump> [<dossier-bucket>]
# Codes : 0 rapport écrit (même si des pièges sont trouvés), 2 mauvais usage, 1 échec (dump illisible, restauration).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PREFIXE_ATTENDU="${PREFIXE_ATTENDU:-https://api.urbankiff.com/file}"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage : inspecter-sauvegarde.sh <dump> [<dossier-bucket>]" >&2
  exit 2
fi
dump="$1"
bucket="${2:-}"

version=$(version_pg_du_dump "$dump")
verifier_version_supportee "$version"
majeure="${version%%.*}"

installer_nettoyage
echo "Version PostgreSQL du dump : $version ; base jetable postgres:$majeure" >&2
demarrer_base_jetable "$majeure" base

# Restauration complète (sans --schema=public) pour tout voir.
if ! restaurer_dump base "$dump" --no-owner --no-privileges > /dev/null; then
  erreur "la restauration du dump a échoué"
  exit 1
fi
# Schéma seul en texte : sert à lire propriétaires, droits et corps de fonctions, jamais les données.
docker exec -i "$(conteneur base)" sh -c 'pg_restore --schema-only -f /tmp/schema.sql' < "$dump"

sql() {
  psql_base base -At -F'|' "$@"
}

roles_du_dump() {
  docker exec "$(conteneur base)" awk '
    /OWNER TO / { r = $0; sub(/.*OWNER TO /, "", r); sub(/[; ].*/, "", r); gsub(/"/, "", r); o[r]++; v[r] = 1 }
    /^GRANT / && / TO / { r = $0; sub(/.* TO /, "", r); sub(/[; ].*/, "", r); gsub(/"/, "", r); g[r]++; v[r] = 1 }
    /^ALTER DEFAULT PRIVILEGES/ && / TO / { r = $0; sub(/.* TO /, "", r); sub(/[; ].*/, "", r); gsub(/"/, "", r); d[r]++; v[r] = 1 }
    END { for (r in v) if (r != "postgres" && r != "PUBLIC" && r !~ /^pg_/) print r "|" o[r] + 0 "|" g[r] + 0 "|" d[r] + 0 }' /tmp/schema.sql | sort
}

occurrences_copy_program() {
  docker exec "$(conteneur base)" sh -c "tr '\n' ' ' < /tmp/schema.sql | grep -oiE 'copy[^;]*(from|to)[[:space:]]+program' | wc -l" | tr -d ' \n'
}

presence() {
  if [ "$1" -gt 0 ]; then echo "$2"; else echo "$3"; fi
}

section_urls() {
  local cible table colonne libelle presente
  for cible in 'file_file|url|File.url' 'post_post|image|Post.image' 'banner_media|file|banner.Media.file' 'scrapper_scrapper|image|Scrapper.image'; do
    IFS='|' read -r table colonne libelle <<< "$cible"
    echo "### $libelle (\`public.$table.$colonne\`)"
    echo
    presente=$(sql -c "select count(*) from information_schema.columns where table_schema = 'public' and table_name = '$table' and column_name = '$colonne'")
    if [ "$presente" -eq 0 ]; then
      echo "Table ou colonne absente du dump."
      echo
      continue
    fi
    sql -v "attendu=$PREFIXE_ATTENDU" << SQL | tableau "Préfixe" "Lignes" "Verdict"
with v as (
  select case
    when "$colonne" is null or "$colonne" = '' then '(vide)'
    else coalesce(substring("$colonne" from '^([A-Za-z][A-Za-z0-9+.-]*://[^/?#]*(?:/[^/?#]+(?=/))?)'), '(autre : pas une URL)')
  end as p
  from public."$table")
select p, count(*),
  case when p ~* '^[a-z][a-z0-9+.-]*://s3' then 'à réécrire ou à valider'
       when p = :'attendu' then 'attendu'
       when p in ('(vide)', '(autre : pas une URL)') then ''
       else 'différent de l''attendu' end
from v group by p order by 2 desc, 1;
SQL
    echo
  done
}

rapport() {
  echo "# Inspection de la sauvegarde"
  echo
  echo "Rapport généré le $(date +%F). Il ne contient que des noms de structure, des décomptes et des préfixes d'URL."
  echo
  echo "## Version"
  echo
  echo "- Version PostgreSQL du dump : $version (détectée dans l'en-tête du dump)"
  echo "- Image de la base jetable : \`postgres:$majeure\`"
  echo "- Rappel : la version PostgreSQL du chart \`urbankiff-donnees\` doit être égale ou supérieure à celle du dump."
  echo
  echo "## Tables et décomptes"
  echo
  decomptes_tables base | tableau "Table" "Lignes"
  echo
  echo "## Rôles"
  echo
  echo "Un dump de base ne contient pas les rôles du cluster ni leurs attributs (superutilisateur, connexion) : seuls les rôles"
  echo "cités par \`OWNER TO\`, \`GRANT\` et \`ALTER DEFAULT PRIVILEGES\` sont listés (rôles système exclus)."
  echo
  roles_du_dump | tableau "Rôle" "OWNER TO" "GRANT" "ALTER DEFAULT PRIVILEGES"
  echo
  echo "## Fonctions et procédures hors extensions"
  echo
  sql << 'SQL' | tableau "Schéma" "Nom" "Langage" "SECURITY DEFINER" "Verdict"
select n.nspname, p.proname, l.lanname, case when p.prosecdef then 'oui' else 'non' end,
  case when l.lanname in ('plpython3u', 'plpythonu', 'plperlu', 'pltclu', 'c', 'plsh') then 'SUSPECT (langage non sûr)'
       when p.prosecdef then 'SUSPECT (SECURITY DEFINER)' else '' end
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_language l on l.oid = p.prolang
where n.nspname not in ('pg_catalog', 'information_schema') and p.prokind in ('f', 'p')
  and not exists (select 1 from pg_depend d where d.objid = p.oid and d.classid = 'pg_proc'::regclass and d.deptype = 'e')
order by 1, 2;
SQL
  echo
  echo "## Extensions"
  echo
  sql -c "select extname, extversion from pg_extension order by 1" | tableau "Extension" "Version"
  echo
  echo "## Déclencheurs non internes"
  echo
  sql << 'SQL' | tableau "Table" "Déclencheur" "Fonction"
select c.relnamespace::regnamespace || '.' || c.relname, t.tgname, p.proname
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal
order by 1, 2;
SQL
  echo
  echo "## Objets suspects"
  echo
  echo "- Occurrences de \`COPY ... FROM/TO PROGRAM\` dans le schéma et les corps de fonctions du dump : $(occurrences_copy_program)"
  echo "- L'historique des commandes exécutées sur le serveur n'est pas dans un dump : il n'est pas inspecté."
  local pg_cron cron_schema cron_job pgagent
  pg_cron=$(sql -c "select count(*) from pg_extension where extname = 'pg_cron'")
  echo "- Extension \`pg_cron\` : $(presence "$pg_cron" présente absente)"
  cron_schema=$(sql -c "select count(*) from pg_namespace where nspname = 'cron'")
  echo "- Schéma \`cron\` : $(presence "$cron_schema" présent absent)"
  if [ "$(sql -c "select to_regclass('cron.job') is not null")" = "t" ]; then
    cron_job=$(sql -c "select count(*) from cron.job")
    echo "- Table \`cron.job\` : présente, $cron_job tâche(s) (commandes jamais lues)"
  else
    echo "- Table \`cron.job\` : absente"
  fi
  pgagent=$(sql -c "select count(*) from pg_namespace where nspname = 'pgagent'")
  echo "- Schéma \`pgagent\` : $(presence "$pgagent" présent absent)"
  echo
  echo "## Préfixes d'URL distincts"
  echo
  echo "Préfixe = schéma, hôte et premier segment de chemin ; préfixe attendu en production : \`$PREFIXE_ATTENDU\`."
  echo
  section_urls
  echo "## Bucket"
  echo
  if [ -z "$bucket" ]; then
    echo "Bucket non inspecté (aucun dossier fourni)."
  fi
}

chemin=$(rapport | ecrire_rapport "inspection-$(basename "$dump" .dump)")
echo "Rapport : $chemin"
