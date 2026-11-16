# Secrets GitHub du projet (docs/v1/specs/2026-11-16-publication-depot-public.md). Inclus par le Makefile racine.
.PHONY: secrets-definir secrets-test

secrets-definir: ## Définit les secrets et variables GitHub d'un environnement (ENV=prod|preprod REPO=owner/depot)
	@test -n "$(ENV)" -a -n "$(REPO)" || { echo "Usage : make secrets-definir ENV=<prod|preprod> REPO=<owner/depot>" >&2; exit 2; }
	@scripts/secrets/definir-secrets.sh "$(ENV)" "$(REPO)"

secrets-test: ## Tests des scripts de secrets (bats, en conteneur)
	docker run --rm -v "$(CURDIR)":/repo -w /repo alpine:3.20 sh -c 'apk add --no-cache bash bats coreutils grep >/dev/null && bats -r scripts/secrets/tests'

GITLEAKS_IMAGE := ghcr.io/gitleaks/gitleaks:v8.21.2
NMAP_IMAGE := instrumentisto/nmap:7.95
SCAN_DOSSIER := .superpowers/secrets-scan

.PHONY: secrets-scan secrets-scan-historique ports-scan

secrets-scan: ## Cherche des secrets dans les fichiers suivis ou à suivre (hors fichiers ignorés), valeurs masquées
	rm -rf $(SCAN_DOSSIER) && mkdir -p $(SCAN_DOSSIER)
	docker run --rm -v "$(CURDIR)":/repo:ro -v "$(CURDIR)/$(SCAN_DOSSIER)":/out -w /repo alpine:3.20 sh -c 'apk add -q --no-cache git tar >/dev/null && git config --global --add safe.directory /repo && git ls-files -z -co --exclude-standard | tar -c --null -T - | tar -x -C /out'
	docker run --rm -v "$(CURDIR)/$(SCAN_DOSSIER)":/scan:ro -v "$(CURDIR)/.gitleaks.toml":/config.toml:ro $(GITLEAKS_IMAGE) dir /scan --config /config.toml --redact --no-banner -v

secrets-scan-historique: ## Cherche des secrets dans tout l'historique git d'un dépôt (DOSSIER=<chemin>), valeurs masquées
	@test -n "$(DOSSIER)" || { echo "Usage : make secrets-scan-historique DOSSIER=<chemin du dépôt>" >&2; exit 2; }
	docker run --rm -v "$(abspath $(DOSSIER))":/repo:ro -v "$(CURDIR)/.gitleaks.toml":/config.toml:ro $(GITLEAKS_IMAGE) git /repo --config /config.toml --redact --no-banner -v

ports-scan: ## Liste les ports TCP ouverts d'un hôte vus de l'extérieur (HOTE=<ip ou nom>)
	@test -n "$(HOTE)" || { echo "Usage : make ports-scan HOTE=<ip ou nom>" >&2; exit 2; }
	docker run --rm $(NMAP_IMAGE) -Pn -p 1-65535 --open -T4 $(HOTE)

CADDYFILE_PROD := caddyprod/CaddyFile

.PHONY: hotes-scan
hotes-scan: ## Interroge en HTTPS chaque nom d'hôte du Caddyfile de prod et affiche le code de réponse (000 = aucune réponse)
	@for h in $$(sed -nE 's/^([a-z0-9.-]+\.[a-z]+) *\{.*/\1/p' $(CADDYFILE_PROD)); do \
	  printf '%s ' "$$h"; docker run --rm $(CURL_IMAGE) -s -o /dev/null -m 10 -w '%{http_code}\n' "https://$$h/" || echo; \
	done
