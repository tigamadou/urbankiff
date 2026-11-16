# Déploiement par version (docs/v1/infra/deploiement.md). Inclus par le Makefile racine ; les cibles appellent
# infra/deploiement/poste/*.sh, le même chemin que le workflow GitHub.
DEPOT_GITHUB := tigamadou/urbankiff
PROPRIETAIRE_GHCR := tigamadou
HELM_IMAGE := alpine/helm:3.16.3
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.10.0
ACTIONLINT_IMAGE := rhysd/actionlint:1.7.4
BATS_BASE_IMAGE := alpine:3.20
COMMIT ?= $(shell git rev-parse HEAD 2>/dev/null | cut -c1-12)
POSTE := infra/deploiement/poste
POSTE_ENV := DEPOT_GITHUB=$(DEPOT_GITHUB) PROPRIETAIRE_GHCR=$(PROPRIETAIRE_GHCR)

.PHONY: images-publier charts-publier deploiement secrets-cluster preprod-arret preprod-demarrage deploiement-test deploiement-lint

images-publier: ## Publie les images GHCR (VERSION=<x.y.z[-rc.n]> ENV=<prod|preprod>)
	@$(POSTE_ENV) $(POSTE)/images-publier.sh "$(VERSION)" "$(ENV)" "$(COMMIT)"

charts-publier: ## Publie les deux charts Helm en OCI (VERSION=<x.y.z[-rc.n]>)
	@$(POSTE_ENV) HELM_IMAGE=$(HELM_IMAGE) $(POSTE)/charts-publier.sh "$(VERSION)"

deploiement: ## Déploie une version publiée, Secrets existants réutilisés (ENV=<prod|preprod> VERSION=<x.y.z>)
	@$(POSTE_ENV) $(POSTE)/ssh-deploy.sh "$(ENV)" "deploy $(VERSION)"

secrets-cluster: ## Déploie en fournissant les Secrets par saisie masquée (ENV=<prod|preprod> VERSION=<x.y.z>)
	@$(POSTE_ENV) $(POSTE)/secrets-cluster.sh "$(ENV)" "$(VERSION)"

preprod-arret: ## Arrête la preprod (charges à zéro, base en hibernation)
	@$(POSTE_ENV) $(POSTE)/ssh-deploy.sh preprod preprod-arret

preprod-demarrage: ## Redémarre la preprod
	@$(POSTE_ENV) $(POSTE)/ssh-deploy.sh preprod preprod-demarrage

deploiement-test: ## Tests des scripts de déploiement (bats, en conteneur)
	docker run --rm -v "$(CURDIR)":/repo -w /repo $(BATS_BASE_IMAGE) sh -c 'apk add --no-cache bash bats coreutils grep make findutils >/dev/null && bats -r infra/deploiement/tests'

deploiement-lint: ## shellcheck des scripts de déploiement (en conteneur)
	docker run --rm -v "$(CURDIR)":/repo:ro -w /repo $(SHELLCHECK_IMAGE) -x -P SCRIPTDIR -S warning infra/deploiement/urbankiff-deploy.sh infra/deploiement/poste/*.sh
