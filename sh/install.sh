#!/bin/bash
# Source the external color variables file
source .env
source ./sh/colors.sh

if ! [ -x "$(command -v docker)" ]; then
  echo '  ${RED}Error: docker is not installed.${RED}' >&2
  exit 1
fi

## Check Docker Compose install
if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker compose >/dev/null 2>&1; then
  echo '  ${RED}Error: Neither docker-compose nor docker compose is installed.${RED}' >&2
  exit 1
fi

# api, nextjs, panel, minio and backup_service are versioned in this repository (monorepo):
# only their local .env files are created, never overwritten.
copy_env_if_missing() {
  if [ ! -f "$2" ]; then
    cp "$1" "$2"
    echo "    ${GREEN}$2 created from $1${GREEN}"
  fi
}

copy_env_if_missing "${API_FOLDER}/.env.temp" "${API_FOLDER}/.env"
copy_env_if_missing "${FRONT_NEXTJS_FOLDER}/env.example" "${FRONT_NEXTJS_FOLDER}/.env"

## Install urbankiff-mobile (separate repository, outside the monorepo)
if [ ! -d "${MOBILE_FOLDER}" ]; then
  echo "Installing ${MOBILE_FOLDER}"
  git clone ${MOBILE_REPO} ${MOBILE_FOLDER}
  echo "   ${GREEN}mobile app installed${GREEN}"
fi

exit 0
