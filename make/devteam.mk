# devteam 1.0.0 : fichier du kit, ne pas modifier ici
# Cibles de la méthode devteam. Inclus par le Makefile racine (-include make/devteam.mk).
.PHONY: devteam-labels devteam-perimetre devteam-test

devteam-labels: ## Crée les labels GitHub d'une mission (SLUG=<slug> [LOTS="a b"])
	@test -n "$(SLUG)" || { echo "Variable SLUG manquante (ex : make devteam-labels SLUG=ma-mission LOTS=\"1 2\")" >&2; exit 2; }
	@scripts/devteam/labels.sh "$(SLUG)" $(LOTS)

devteam-perimetre: ## Vérifie le périmètre d'un lot (LOT= PLAN= BASE=)
	@test -n "$(LOT)" -a -n "$(PLAN)" -a -n "$(BASE)" || { echo "Variables LOT, PLAN et BASE requises (ex : make devteam-perimetre LOT=3 PLAN=docs/plans/x/3-lot.md BASE=feature/x)" >&2; exit 2; }
	@scripts/devteam/check-perimetre.sh "$(LOT)" "$(PLAN)" "$(BASE)"

devteam-test: ## Lance les tests des scripts du kit devteam (bats, en conteneur)
	docker run --rm -v "$(CURDIR)":/repo -w /repo alpine:3.20 sh -c 'apk add --no-cache bash git bats coreutils >/dev/null && git config --global --add safe.directory "*" && bats -r scripts/devteam'
