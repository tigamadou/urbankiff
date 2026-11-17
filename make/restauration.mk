# Inspection et répétition de la sauvegarde de prod (docs/v1/specs/2026-11-16-k3s-ansible.md, § 5.11). Inclus par le Makefile racine.
RESTAURATION_DIR := infra/restauration
RESTAURATION_API_IMAGE := urbankiff-restauration-api

.PHONY: restauration-test

restauration-test: ## Tests des scripts de restauration (bats, en conteneur, base PostgreSQL jetable)
	docker build -q -t $(RESTAURATION_API_IMAGE) apps/api >/dev/null
	docker run --rm -v "$(CURDIR)":/repo -v /var/run/docker.sock:/var/run/docker.sock -w /repo -e API_IMAGE=$(RESTAURATION_API_IMAGE) alpine:3.20 sh -c 'apk add --no-cache bash bats coreutils grep make docker-cli >/dev/null && bats -r $(RESTAURATION_DIR)/tests'

.PHONY: sauvegarde-inspecter sauvegarde-repeter

sauvegarde-inspecter: ## Inspecte une sauvegarde de prod et écrit un rapport (DUMP=<chemin> [BUCKET=<dossier>])
	@test -n "$(DUMP)" || { echo "Usage : make sauvegarde-inspecter DUMP=<chemin> [BUCKET=<dossier>]" >&2; exit 2; }
	bash $(RESTAURATION_DIR)/inspecter-sauvegarde.sh "$(abspath $(DUMP))" $(if $(BUCKET),"$(abspath $(BUCKET))")

sauvegarde-repeter: ## Répète la restauration d'une sauvegarde de prod dans une base jetable (DUMP=<chemin>)
	@test -n "$(DUMP)" || { echo "Usage : make sauvegarde-repeter DUMP=<chemin>" >&2; exit 2; }
	bash $(RESTAURATION_DIR)/repeter-sauvegarde.sh "$(abspath $(DUMP))"

# Restauration de la preprod et de la prod depuis le dépôt Wasabi (docs/v1/infra/deploiement.md). Les cibles s'appuient
# sur POSTE et POSTE_ENV de make/deploiement.mk, inclus avant ce fichier par le Makefile racine.
RCLONE_IMAGE := rclone/rclone:1.68.2

.PHONY: restauration-lancer restauration-deposer

restauration-lancer: ## Restaure une sauvegarde déposée dans Wasabi (ENV=<prod|preprod> PREFIXE=restauration/<AAAA-MM-JJ>[-prod-anonyme]/)
	@$(POSTE_ENV) $(POSTE)/restauration-lancer.sh "$(ENV)" "$(PREFIXE)"

restauration-deposer: ## Dépose une sauvegarde dans Wasabi (ENV=<prod|preprod> DUMP=<fichier> [FICHIERS=<dossier>] DATE=<AAAA-MM-JJ>)
	@$(POSTE_ENV) RCLONE_IMAGE=$(RCLONE_IMAGE) $(POSTE)/restauration-deposer.sh "$(ENV)" "$(if $(DUMP),$(abspath $(DUMP)))" "$(if $(FICHIERS),$(abspath $(FICHIERS)))" "$(DATE)"
