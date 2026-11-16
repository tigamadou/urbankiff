#!/usr/bin/env bash
# Fabrique un dump PostgreSQL (format custom) d'une base Django réellement migrée, avec des données fabriquées et des
# pièges (rôle, fonctions, déclencheur, extension, tâche planifiée factice). Aucun dump n'est commité.
# Usage : fabriquer-dump.sh <sortie.dump> [vide]    (« vide » : base sans table ni piège)
# Variable : API_IMAGE (image de l'api, obligatoire hors mode vide).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage : fabriquer-dump.sh <sortie.dump> [vide]" >&2
  exit 2
fi
sortie="$1"
mode="${2:-piege}"

installer_nettoyage
demarrer_base_jetable 15 source

if [ "$mode" != "vide" ]; then
  : "${API_IMAGE:?image de la variable API_IMAGE obligatoire}"
  docker run -d --name "$(conteneur redis)" --network "$REST_RESEAU" --label "$REST_LABEL" redis:7-alpine > /dev/null
  api() {
    POSTGRES_PASSWORD="$REST_MDP" docker run --rm -i --network "$REST_RESEAU" --label "$REST_LABEL" \
      -e POSTGRES_DB=app -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD -e POSTGRES_HOST="$(conteneur source)" \
      -e REDIS_ENDPOINT="redis://$(conteneur redis):6379/0" \
      -e MINIO_ENDPOINT=minio.invalid:9000 -e MINIO_ROOT_USER=test -e MINIO_ROOT_PASSWORD=test-test -e MINIO_DEFAULT_BUCKETS=test \
      -e FILES_CDN_ENDPOINT=https://api.example.test/file -e TWILIO_ACCOUNT_SID=test -e TWILIO_AUTH_TOKEN=test \
      "$API_IMAGE" python manage.py "$@"
  }
  api migrate > /dev/null
  api shell < "$(dirname "${BASH_SOURCE[0]}")/fabrique.py" > /dev/null
  psql_base source > /dev/null << 'SQL'
create role piege_role;
create table piege_table (id integer);
alter table piege_table owner to piege_role;
grant select on file_file to piege_role;
create extension pg_trgm;
create function piege_copy() returns void language plpgsql as $$
begin
  copy piege_table from program 'true';
end
$$;
create function piege_definer() returns integer language sql security definer as $$ select 1 $$;
create function piege_trigger() returns trigger language plpgsql as $$
begin
  return new;
end
$$;
create trigger piege_declencheur before insert on post_post for each row execute function piege_trigger();
create schema cron;
create table cron.job (jobid integer, command text);
insert into cron.job values (1, 'SENTINELLE_COMMANDE');
SQL
fi

docker exec "$(conteneur source)" pg_dump -U postgres -Fc app > "$sortie.partiel"
mv "$sortie.partiel" "$sortie"
echo "Dump fabriqué : $sortie" >&2
