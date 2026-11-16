#!/usr/bin/env bash
# charts-publier.sh <version> : empaquette les deux charts et les pousse en OCI. Le jeton passe par l'entrée standard du
# conteneur helm, jamais en argument. GHCR_UTILISATEUR remplace l'utilisateur de `gh api user` (CI).
# Variables attendues : HELM_IMAGE. CHARTS_DIR remplace infra/helm (tests).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
: "${HELM_IMAGE:?}"

CHARTS_DIR="${CHARTS_DIR:-$RACINE/infra/helm}"
version="${1:-}"
[[ "$version" =~ $SEMVER ]] || usage "make charts-publier VERSION=<x.y.z[-rc.n]>"
for chart in urbankiff-donnees urbankiff; do
  [ -d "$CHARTS_DIR/$chart" ] || die "chart introuvable : infra/helm/$chart"
done
utilisateur="${GHCR_UTILISATEUR:-$(gh api user --jq .login)}"

gh auth token | docker run --rm -i --entrypoint sh -e HOME=/tmp -e GHCR_UTILISATEUR="$utilisateur" \
  -e CHART_VERSION="$version" -e CHART_OWNER="$PROPRIETAIRE_GHCR" \
  -v "$CHARTS_DIR":/charts:ro "$HELM_IMAGE" -c '
set -e
helm registry login ghcr.io -u "$GHCR_UTILISATEUR" --password-stdin
for chart in urbankiff-donnees urbankiff; do
  helm package "/charts/$chart" --version "$CHART_VERSION" --app-version "$CHART_VERSION" --destination /tmp/paquets
  helm push "/tmp/paquets/$chart-$CHART_VERSION.tgz" "oci://ghcr.io/$CHART_OWNER/charts"
done'
