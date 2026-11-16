# devteam 1.0.0 : fichier du kit, ne pas modifier ici
# Environnements d'agent devteam. Inclus par le Makefile racine seulement si devteam.agent.conf existe.
# « Pas de place » : make renvoie 2 ; le signal est la ligne « agent-env : pas de place : … » (code 75 du script).
.PHONY: agent-up agent-down agent-status

DEVTEAM_AGENT_ENV := scripts/devteam/agent-env/agent-env.sh

agent-up: ## Environnement d'agent : make agent-up LOT=<lot> PROFIL=<profil> BASE=<branche>
	@test -n "$(LOT)" -a -n "$(PROFIL)" -a -n "$(BASE)" || { echo "Usage : make agent-up LOT=<lot> PROFIL=<profil> BASE=<branche>" >&2; exit 2; }
	@$(DEVTEAM_AGENT_ENV) up "$(LOT)" "$(PROFIL)" "$(BASE)"

agent-down: ## Arrête l'environnement d'un agent (conserve worktree, branche et données) : make agent-down LOT=<lot>
	@test -n "$(LOT)" || { echo "Usage : make agent-down LOT=<lot>" >&2; exit 2; }
	@$(DEVTEAM_AGENT_ENV) down "$(LOT)"

agent-status: ## Environnements d'agent actifs, mémoire et budget
	@$(DEVTEAM_AGENT_ENV) status
