DOCKER_COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo "docker-compose" || echo "docker compose")

init:
	chmod +x init.sh && ./init.sh
start:
	$(DOCKER_COMPOSE) up -d
startdb:
	$(DOCKER_COMPOSE) up -d --build
restartdb:
	$(DOCKER_COMPOSE) down && $(DOCKER_COMPOSE) up -d --build
restartd:
	$(DOCKER_COMPOSE) down && $(DOCKER_COMPOSE) up -d
down:
	$(DOCKER_COMPOSE) down
volume:
	docker volume prune
.PHONY: seed
seed:
	docker exec api bash -c 'python manage.py shell < /app/seed/fake_data.py'
migrate_post_images:
	docker exec api bash -c 'python manage.py shell < /app/seed/migrate_post_images.py'

.PHONY: build-front
build-front:
	docker exec app bash -c 'yarn && yarn build'

.PHONE: clean_branches
clean_branches:
	git branch | grep -v "development" | grep -v "main" | xargs git branch -D

front_pages:
	docker exec api bash -c 'python manage.py create_pages cds apps/page/seed/cds.json'
	docker exec api bash -c 'python manage.py create_pages cgu apps/page/seed/cgu.json'
	docker exec api bash -c 'python manage.py create_pages dec apps/page/seed/dec.json'
	docker exec api bash -c 'python manage.py create_pages mel apps/page/seed/mel.json'
	docker exec api bash -c 'python manage.py create_pages pdc apps/page/seed/pdc.json'

frontlint:
	docker exec app bash -c 'yarn lint'

.PHONY: build-nextjs
build-nextjs:
	cd apps/nextjs && \
	docker compose down || true && \
	docker compose build --no-cache && \
	docker compose up -d && \
	echo "Next.js app built and started in container. Access at http://localhost:3000" && \
	echo "Container will be cleaned up when you run 'make down-nextjs'"

.PHONY: down-nextjs
down-nextjs:
	cd apps/nextjs && docker compose down

-include make/devteam.mk
-include make/standard.mk
ifneq ($(wildcard devteam.agent.conf),)
-include make/devteam-agent.mk
endif

-include make/secrets.mk
