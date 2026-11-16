# Infrastructure k3s par Ansible (docs/v1/infra/serveur.md). Inclus par le Makefile racine.
.PHONY: infra-image infra-ansible infra-lint infra-test-assert infra-test infra-vendre

ANSIBLE_DIR := infra/ansible
ANSIBLE_TAG := $(shell git hash-object $(ANSIBLE_DIR)/Dockerfile $(ANSIBLE_DIR)/requirements.yml 2>/dev/null | cut -c1-8 | paste -sd- -)
ANSIBLE_IMAGE ?= urbankiff-ansible:$(ANSIBLE_TAG)
SSH_SOCKET_HOTE ?= /run/host-services/ssh-auth.sock
KNOWN_HOSTS_HOTE ?= $(HOME)/.ssh/known_hosts
LIMITE ?=
ARGS ?=

infra-image: ## Construit l'image Ansible à versions épinglées
	docker build -q -t $(ANSIBLE_IMAGE) $(ANSIBLE_DIR) >/dev/null

infra-ansible: infra-image ## Joue site.yml (LIMITE=<groupe ou hôte>, ARGS="--check --diff")
	@test -n "$(LIMITE)" || { echo "Usage : make infra-ansible LIMITE=<groupe ou hôte> [ARGS=...]" >&2; exit 2; }
	@test -f $(ANSIBLE_DIR)/inventory.yml || { echo "inventory.yml absent : cp $(ANSIBLE_DIR)/inventory.example.yml $(ANSIBLE_DIR)/inventory.yml" >&2; exit 2; }
	@test -f "$(KNOWN_HOSTS_HOTE)" || { echo "known_hosts absent ($(KNOWN_HOSTS_HOTE))" >&2; exit 2; }
	docker run --rm -u 0 -v "$(CURDIR)":/repo:ro \
		-v "$(SSH_SOCKET_HOTE)":/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent \
		-v "$(KNOWN_HOSTS_HOTE)":/root/.ssh/known_hosts:ro \
		$(ANSIBLE_IMAGE) ansible-playbook site.yml --limit "$(LIMITE)" $(ARGS)

infra-lint: infra-image ## ansible-lint, syntax-check, options k3s, manifestes vendus (SHA-256, versions)
	docker run --rm -v "$(CURDIR)":/repo:ro -e ANSIBLE_HOME=/tmp/ansible $(ANSIBLE_IMAGE) \
		sh -c 'ansible-lint --offline && ansible-playbook -i inventory.example.yml site.yml --syntax-check'

infra-test-assert: infra-image ## Vérifie que site.yml refuse les inventaires invalides
	docker run --rm -v "$(CURDIR)":/repo:ro -e ANSIBLE_HOME=/tmp/ansible $(ANSIBLE_IMAGE) sh tests/assert.sh

infra-test: infra-image ## Joue base et le volet utilisateur de deploiement sur un conteneur Ubuntu 24.04 jetable
	IMAGE_ANSIBLE=$(ANSIBLE_IMAGE) sh $(ANSIBLE_DIR)/tests/lancer.sh
