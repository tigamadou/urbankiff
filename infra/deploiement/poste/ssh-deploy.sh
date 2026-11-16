#!/usr/bin/env bash
# ssh-deploy.sh <env> <deploy X.Y.Z | preprod-arret | preprod-demarrage> : commande forcée, sans entrée standard.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

env="${1:-}"; commande="${2:-}"
case "$env" in prod|preprod) ;; *) usage "ENV=<prod|preprod> (et VERSION=<x.y.z> pour deploiement)" ;; esac
if [[ "$commande" =~ ^deploy\ [0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || [ "$commande" = preprod-arret ] || [ "$commande" = preprod-demarrage ]; then
  :
else
  usage "VERSION=<x.y.z[-rc.n]> requise pour deploiement"
fi
ssh_deploy "$env" "$commande" < /dev/null
