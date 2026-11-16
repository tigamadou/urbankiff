# Outillage des charts Helm (infra/helm). Inclus automatiquement par le Makefile racine (lot socle).
# Tout tourne dans des conteneurs aux versions épinglées ; le dépôt est monté en lecture seule.
# Seule helm-schemas utilise le réseau (récupération des schémas versionnés dans infra/helm/schemas).

HELM_IMAGE := alpine/helm:3.16.4
HELM_UNITTEST_IMAGE := helmunittest/helm-unittest:3.16.4-0.7.1
KUBECONFORM_IMAGE := ghcr.io/yannh/kubeconform:v0.6.7
YQ_IMAGE := mikefarah/yq:4.44.6
KUBERNETES_VERSION := 1.31.0
SCHEMAS_SOURCE := https://raw.githubusercontent.com/datreeio/CRDs-catalog/main
SCHEMAS_LISTE := postgresql.cnpg.io/cluster_v1 postgresql.cnpg.io/scheduledbackup_v1 barmancloud.cnpg.io/objectstore_v1 cert-manager.io/certificate_v1

HELM_DIR ?= infra/helm
HELM_CHARTS := urbankiff-donnees urbankiff
HELM_SORTIE := .superpowers/helm
# Valeurs de test, sans valeur de secret : les valeurs réelles viennent du script de déploiement.
ETIQUETTE ?= 0.0.0-test
WASABI_REGION ?= eu-central-2
WASABI_BUCKET ?= urbankiff-test
HELM_SET := --set image.etiquette=$(ETIQUETTE) --set wasabi.region=$(WASABI_REGION) --set wasabi.bucket=$(WASABI_BUCKET) --set secretsChecksum=test

HELM_RUN := docker run --rm -v "$(CURDIR)/$(HELM_DIR)":/charts:ro -w /charts $(HELM_IMAGE)
CHARTS_CHOISIS := $(if $(CHART),$(CHART),$(HELM_CHARTS))

.PHONY: helm-present helm-env helm-lint helm-rendu helm-valider helm-test helm-transverses helm-paquet helm-schemas helm-garde helm-controle

helm-present:
	@ls -d $(HELM_DIR)/urbankiff*/Chart.yaml >/dev/null 2>&1 || { echo "helm : aucun chart sous $(HELM_DIR)/urbankiff* (Chart.yaml absent)" >&2; exit 1; }

helm-env:
	@case "$(ENV)" in prod|preprod) ;; *) echo "Usage : make $(MAKECMDGOALS) ENV=<prod|preprod> [CHART=<urbankiff-donnees|urbankiff>]" >&2; exit 2;; esac

helm-lint: helm-present ## Lint des deux charts (valeurs par défaut, prod, preprod)
	@for c in $(HELM_CHARTS); do \
	  for v in "" prod preprod; do \
	    f=""; [ -z "$$v" ] || f="-f $$c/values-$$v.yaml"; \
	    echo "== lint $$c $${v:-défaut}"; \
	    $(HELM_RUN) lint $$c $$f $(HELM_SET) --strict || exit 1; \
	  done; \
	done

helm-rendu: helm-env helm-present ## Rend les charts pour un environnement (ENV=prod|preprod, CHART= facultatif)
	@for c in $(CHARTS_CHOISIS); do \
	  $(HELM_RUN) template $$c $$c -n $(ENV) -f $$c/values-$(ENV).yaml $(HELM_SET) || exit 1; \
	done

helm-valider: helm-env helm-present ## Rendu puis kubeconform strict avec les schémas versionnés (ENV=prod|preprod)
	@for c in $(CHARTS_CHOISIS); do \
	  echo "== kubeconform $$c $(ENV)"; \
	  $(HELM_RUN) template $$c $$c -n $(ENV) -f $$c/values-$(ENV).yaml $(HELM_SET) \
	  | docker run --rm -i -v "$(CURDIR)/$(HELM_DIR)/schemas":/schemas:ro $(KUBECONFORM_IMAGE) -strict -summary \
	      -kubernetes-version $(KUBERNETES_VERSION) -schema-location default \
	      -schema-location '/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' - || exit 1; \
	done

helm-test: helm-present ## Tests helm-unittest puis contrôles transverses sur le rendu des deux environnements
	docker run --rm -v "$(CURDIR)/$(HELM_DIR)":/apps:ro $(HELM_UNITTEST_IMAGE) $(HELM_CHARTS)
	@$(MAKE) --no-print-directory helm-transverses

helm-transverses: helm-present
	@mkdir -p $(HELM_SORTIE)
	@for e in prod preprod; do for c in $(HELM_CHARTS); do \
	  $(HELM_RUN) template $$c $$c -n $$e -f $$c/values-$$e.yaml $(HELM_SET) > $(HELM_SORTIE)/$$c-$$e.yaml || exit 1; \
	done; done
	docker run --rm -v "$(CURDIR)/$(HELM_DIR)/tests-transverses":/controle:ro -v "$(CURDIR)/$(HELM_DIR)":/charts:ro -v "$(CURDIR)/$(HELM_SORTIE)":/rendu:ro --entrypoint sh $(YQ_IMAGE) /controle/controle.sh

helm-paquet: helm-present ## Empaquette les charts dans .superpowers/helm-paquets (VERSION=x.y.z)
	@test -n "$(VERSION)" || { echo "Usage : make helm-paquet VERSION=<x.y.z>" >&2; exit 2; }
	@mkdir -p .superpowers/helm-paquets
	@for c in $(HELM_CHARTS); do \
	  docker run --rm -v "$(CURDIR)/$(HELM_DIR)":/charts:ro -v "$(CURDIR)/.superpowers/helm-paquets":/out -w /charts $(HELM_IMAGE) package $$c --version $(VERSION) --app-version $(VERSION) -d /out || exit 1; \
	done

helm-schemas: ## Régénère infra/helm/schemas depuis le catalogue (seule cible avec accès réseau)
	docker run --rm -v "$(CURDIR)/$(HELM_DIR)/schemas":/out alpine:3.20 sh -c 'for f in $(SCHEMAS_LISTE); do mkdir -p /out/$$(dirname $$f) && wget -q -O /out/$$f.json $(SCHEMAS_SOURCE)/$$f.json || exit 1; done'

helm-garde: ## Test d'outillage : les cibles échouent proprement sans chart et sans ENV
	@out=$$($(MAKE) -s helm-lint HELM_DIR=infra/helm-absent 2>&1); [ $$? -ne 0 ] && echo "$$out" | grep -q "aucun chart" || { echo "garde : helm-lint doit échouer sans chart" >&2; exit 1; }
	@out=$$($(MAKE) -s helm-test HELM_DIR=infra/helm-absent 2>&1); [ $$? -ne 0 ] && echo "$$out" | grep -q "aucun chart" || { echo "garde : helm-test doit échouer sans chart" >&2; exit 1; }
	@out=$$($(MAKE) -s helm-rendu 2>&1); rc=$$?; [ $$rc -eq 2 ] && echo "$$out" | grep -q "Usage" || { echo "garde : helm-rendu sans ENV doit afficher l'usage (code 2)" >&2; exit 1; }
	@echo "garde : OK"

helm-controle: helm-lint helm-test helm-garde ## Lint, tests, garde puis kubeconform des deux environnements
	@$(MAKE) --no-print-directory helm-valider ENV=prod
	@$(MAKE) --no-print-directory helm-valider ENV=preprod
