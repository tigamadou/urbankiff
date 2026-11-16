#!/usr/bin/env bash
# images-publier.sh <version> <env> <sha12> : publie les images sur GHCR (linux/amd64).
# api : construite une fois (preprod) sous sha-<12> et <version> ; en prod, l'image du commit est réétiquetée <version>
# (même digest), jamais reconstruite. Next et panel : construits par environnement, étiquette <version>-<env>.
# Les variables de construction viennent de l'environnement GitHub (gh variable list) ; URBANKIFF_VAR_<NOM> les remplace
# (CI : variables du contexte du workflow). Le jeton GHCR passe par --password-stdin. GHCR_UTILISATEUR remplace
# l'utilisateur de `gh api user` (CI).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

UTILISATION="make images-publier VERSION=<x.y.z[-rc.n]> ENV=<prod|preprod>"
version="${1:-}"; env="${2:-}"; sha="${3:-}"
[[ "$version" =~ $SEMVER ]] || usage "$UTILISATION"
case "$env" in prod) [[ "$version" != *-* ]] || usage "$UTILISATION (pas de pré-release en prod)" ;; preprod) ;; *) usage "$UTILISATION" ;; esac
[[ "$sha" =~ ^[0-9a-f]{12}$ ]] || usage "$UTILISATION (commit introuvable)"

NEXT_ARGS="NEXT_PUBLIC_BACKEND_URL NEXT_PUBLIC_BACKEND_URL_FRONT NEXT_PUBLIC_GOOGLE_CLIENT_ID BACKEND_URL"
PANEL_ARGS="REACT_APP_BACKEND_URL REACT_APP_IMAGEKIT_ENDPOINT"

declare -A valeur
depuis_github=0
for nom in $NEXT_ARGS $PANEL_ARGS; do
  depuis_env="URBANKIFF_VAR_$nom"
  [ -n "${!depuis_env:-}" ] || depuis_github=1
done
if [ "$depuis_github" = 1 ]; then
  while IFS='=' read -r nom contenu; do
    [ -z "$nom" ] || valeur[$nom]="$contenu"
  done < <(variables_github "$env")
fi

for nom in $NEXT_ARGS $PANEL_ARGS; do
  depuis_env="URBANKIFF_VAR_$nom"
  if [ -n "${!depuis_env:-}" ]; then valeur[$nom]="${!depuis_env}"; fi
  [ -n "${valeur[$nom]:-}" ] || die "variable de construction absente de l'environnement $env : $nom"
done

arguments() { # <noms> : --build-arg NOM=valeur, un mot par ligne
  local nom
  for nom in $1; do printf '%s\n' "--build-arg" "$nom=${valeur[$nom]}"; done
}
mapfile -t args_next < <(arguments "$NEXT_ARGS")
mapfile -t args_panel < <(arguments "$PANEL_ARGS")

depot="ghcr.io/$PROPRIETAIRE_GHCR"
utilisateur="${GHCR_UTILISATEUR:-$(gh api user --jq .login)}"
gh auth token | docker login ghcr.io -u "$utilisateur" --password-stdin

if [ "$env" = preprod ]; then
  docker buildx build --platform linux/amd64 --target prod \
    -t "$depot/urbankiff-api:sha-$sha" -t "$depot/urbankiff-api:$version" --push "$RACINE/apps/api"
else
  docker buildx imagetools inspect "$depot/urbankiff-api:sha-$sha" > /dev/null \
    || die "image $depot/urbankiff-api:sha-$sha absente : publier d'abord la pré-release de ce commit"
  docker buildx imagetools create --tag "$depot/urbankiff-api:$version" "$depot/urbankiff-api:sha-$sha"
fi
docker buildx build --platform linux/amd64 "${args_next[@]}" -t "$depot/urbankiff-nextjs:$version-$env" --push "$RACINE/apps/nextjs"
docker buildx build --platform linux/amd64 "${args_panel[@]}" -t "$depot/urbankiff-panel:$version-$env" --push "$RACINE/apps/panel"
