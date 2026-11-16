# Cibles standard devteam d'Urbankiff (contrat, point 4). Chaque commande tourne dans un conteneur.
# Les services du Compose principal sont réutilisés avec `run --rm --no-deps` : même image, mêmes volumes, même .env.
# Les cibles generate, check-generated, e2e-fixtures et e2e sont déclarées « sans objet » dans .claude/devteam.projet.md.
# coverage-diff installe ses outils à la volée (coverage.py dans le conteneur api jetable, diff-cover dans un conteneur Python
# outil) : ils n'entrent pas dans les dépendances des applications.

# Dans un worktree d'agent, .agent.env (lignes « export NOM=valeur », écrites par agent-env.sh) est lu par make lui-même :
# la directive `export` de make est la même syntaxe, les variables arrivent donc aux recettes et à Compose sans « source ».
-include .agent.env
ifneq ($(wildcard .agent.env),)
ifndef AGENT_LOT
$(error .agent.env présent mais sans AGENT_LOT : fichier invalide)
endif
COMPOSE_RUN := $(DOCKER_COMPOSE) -p urbankiff-ag-$(AGENT_LOT) -f compose.agent.yml run --rm --no-deps -T
# Services préfixés en agent (alias DNS distincts de la stack principale, voir compose.agent.yml)
SVC_API := agent-api
SVC_NEXTJS := agent-nextjs
SVC_PANEL := agent-panel
else
COMPOSE_RUN := $(DOCKER_COMPOSE) run --rm --no-deps -T
SVC_API := api
SVC_NEXTJS := nextjs
SVC_PANEL := panel
endif
# stack-check vise toujours la stack principale (projet urbankiff, Compose principal), même dans un worktree d'agent
STACK_PS := $(DOCKER_COMPOSE) -p urbankiff -f docker-compose.yml ps
CURL_IMAGE := curlimages/curl:8.11.1

COVERAGE_VERSION := 7.10.7
DIFF_COVER_VERSION := 10.6.0
DIFF_COVER_IMAGE := python:3.12.7
# Rapports de couverture : dossier ignoré par git (api : monté dans le conteneur ; panel : apps/panel/coverage, ignoré aussi)
COVERAGE_DIR := .coverage-diff
GIT_COMMON_DIR := $(shell git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
# Options supplémentaires de diff-cover (ex : DIFF_COVER_OPTS=--ignore-staged pour n'évaluer que les modifications non indexées)
DIFF_COVER_OPTS ?=

API_T := $(patsubst %/,%,$(filter apps/api/%,$(T)))
API_LABELS := $(subst /,.,$(basename $(patsubst apps/api/%,%,$(API_T))))
PANEL_T := $(patsubst apps/panel/%,%,$(filter apps/panel/%,$(T)))
AUTRES_T := $(filter-out apps/api/% apps/panel/%,$(T))

.PHONY: help test-cible lint lint-api lint-nextjs lint-panel typecheck migrations-check stack-check coverage-diff

help: ## Liste les cibles documentées
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | sed -E 's/:.*## /\t/' | sort

# d'après : apps/api/Makefile (tests : python manage.py test) et apps/panel/package.json (test : craco test) ; aiguillage par préfixe validé par le développeur
test-cible: ## Lance les tests des chemins donnés (T="apps/api/... apps/panel/...")
	@test -n "$(T)" || { echo "Variable T manquante (ex : make test-cible T=apps/api/apps/user)" >&2; exit 2; }
	@test -z "$(AUTRES_T)" || { echo "Pas de tests pour : $(AUTRES_T) (seuls apps/api/ et apps/panel/ en ont)" >&2; exit 2; }
ifneq ($(API_LABELS),)
	$(COMPOSE_RUN) $(SVC_API) python manage.py test $(API_LABELS)
endif
ifneq ($(PANEL_T),)
	$(COMPOSE_RUN) $(SVC_PANEL) sh -c 'cd /app && yarn --silent && CI=true yarn test --watchAll=false $(PANEL_T)'
endif

# d'après : apps/api/Makefile (lint), apps/nextjs/package.json (lint:strict), apps/panel/package.json (lint)
lint: lint-api lint-nextjs lint-panel ## Lint de api, nextjs et panel

lint-api: ## Lint de l'api (flake8)
	$(COMPOSE_RUN) $(SVC_API) python -m flake8 --ignore E501,E722,F821,W504 apps/ project/ libs/

lint-nextjs: ## Lint de nextjs (eslint)
	$(COMPOSE_RUN) $(SVC_NEXTJS) sh -c 'yarn install --frozen-lockfile --silent && yarn lint:strict'

lint-panel: ## Lint de panel (eslint)
	$(COMPOSE_RUN) $(SVC_PANEL) sh -c 'cd /app && yarn --silent && yarn lint'

# d'après : apps/nextjs/package.json (type-check : tsc --noEmit) ; api et panel n'ont pas de typage vérifié
typecheck: ## Vérification des types (nextjs)
	$(COMPOSE_RUN) $(SVC_NEXTJS) sh -c 'yarn install --frozen-lockfile --silent && yarn type-check'

# d'après : réponse du développeur (commande Django makemigrations --check --dry-run)
migrations-check: ## Échoue si un modèle Django a changé sans migration
	$(COMPOSE_RUN) $(SVC_API) python manage.py makemigrations --check --dry-run

# d'après : réponse du développeur (services démarrés, api et front qui répondent via Caddy)
stack-check: ## Vérifie que la stack principale est démarrée et répond
	@arretes=$$($(STACK_PS) -a --format '{{.Service}} {{.State}}' | awk '$$1 != "migrations" && $$2 != "running" {print $$1}'); \
	  test -z "$$arretes" || { echo "Services non démarrés : $$arretes" >&2; exit 1; }
	docker run --rm --network URBANKIFF $(CURL_IMAGE) -fsS -o /dev/null -H 'Host: api.urbankiff.local' http://caddy/
	docker run --rm --network URBANKIFF $(CURL_IMAGE) -fsS -o /dev/null -H 'Host: urbankiff.local' http://caddy/

# d'après : docs/v1/specs/2026-11-15-devteam-conformite.md (Point 4) ; api : coverage.py (rapport XML), panel : craco test --coverage (lcov), diff-cover épinglé dans un conteneur Python
# Les chemins des rapports sont relatifs à la racine de chaque application, ceux du diff à la racine du dépôt (--src-roots ne vaut que
# pour JaCoCo) : api (XML relatif grâce à relative_files) : diff-cover est lancé depuis apps/api, qui compare alors relativement à ce dossier ;
# panel : les chemins SF du lcov sont préfixés par apps/panel/ avant lecture, diff-cover tourne à la racine.
# diff-cover ne mélange pas XML et lcov : un appel par rapport, la cible échoue si l'un des deux échoue.
# Le dépôt est monté au même chemin absolu que sur l'hôte, avec le dépôt git commun en lecture seule (un worktree n'a qu'un fichier .git).
coverage-diff: ## Échoue si le code modifié par rapport à BASE n'est pas couvert à 100 % (BASE=<branche>)
	@test -n "$(BASE)" || { echo "Variable BASE manquante (ex : make coverage-diff BASE=development)" >&2; exit 2; }
	@test -n "$(GIT_COMMON_DIR)" || { echo "Dépôt git introuvable" >&2; exit 2; }
	mkdir -p $(CURDIR)/$(COVERAGE_DIR)
	rm -rf $(CURDIR)/$(COVERAGE_DIR)/api.xml $(CURDIR)/$(COVERAGE_DIR)/.coverage $(CURDIR)/apps/panel/coverage
	$(COMPOSE_RUN) -v "$(CURDIR)/$(COVERAGE_DIR):/cov" $(SVC_API) sh -c 'pip install -q --root-user-action=ignore coverage==$(COVERAGE_VERSION) \
	  && printf "[run]\nrelative_files = True\nsource = .\n[report]\ninclude =\n    apps/*\n    project/*\n    libs/*\n" > /tmp/coverage.rc \
	  && export COVERAGE_RCFILE=/tmp/coverage.rc COVERAGE_FILE=/cov/.coverage \
	  && { coverage run manage.py test apps project libs; status=$$?; coverage xml -o /cov/api.xml; exit $$status; }'
	$(COMPOSE_RUN) $(SVC_PANEL) sh -c "cd /app && yarn --silent && CI=true yarn test --watchAll=false --coverage --coverageReporters=lcov --collectCoverageFrom='src/**/*.{js,jsx,ts,tsx}' --collectCoverageFrom='!src/**/*.test.*'"
	docker run --rm --mount type=bind,src=$(CURDIR),dst=$(CURDIR) --mount type=bind,src=$(GIT_COMMON_DIR),dst=$(GIT_COMMON_DIR),readonly -w $(CURDIR) $(DIFF_COVER_IMAGE) sh -c \
	  'printf "[safe]\n\tdirectory = *\n" > ~/.gitconfig && pip install -q --root-user-action=ignore diff-cover==$(DIFF_COVER_VERSION) \
	  && sed "s|^SF:|SF:apps/panel/|" apps/panel/coverage/lcov.info > /tmp/panel.lcov \
	  && status=0 \
	  && { (cd $(CURDIR)/apps/api && diff-cover $(CURDIR)/$(COVERAGE_DIR)/api.xml --compare-branch=$(BASE) --fail-under=100 $(DIFF_COVER_OPTS)) || status=1; } \
	  && { diff-cover /tmp/panel.lcov --compare-branch=$(BASE) --fail-under=100 $(DIFF_COVER_OPTS) || status=1; } \
	  && exit $$status'
