# Urbankiff conforme devteam (points 2, 3, 4, 7 et remise au vert) — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : remettre le code au vert puis construire l'environnement d'agent, l'isolation, `coverage-diff` et le
budget, jusqu'à un diagnostic devteam entièrement `rempli`.

**Architecture** : moteur d'environnement d'agent du kit devteam, `compose.agent.yml` autonome sur le réseau
`URBANKIFF`, adaptateurs `postgres`, `redis`, `s3`, `port` ; garde-fou en lanceur de tests Django.

**Stack** : Django 4.1 (Python 3.9), Next.js (TypeScript), React CRA/craco, Docker Compose, Make, GitHub Actions.

**Spec** : `docs/v1/specs/2026-11-15-devteam-conformite.md` (elle fait autorité). Plan séquentiel hors mission
devteam.

## Exécution

- **Mission** : sans objet (mise en conformité) · **Issue** : aucune
- **Branche** : `chore/devteam-conformite` · **Base** : `development` · **Profil** : sans objet
- **Dépendances** : les fichiers déjà générés par `/devteam:conformite` (`.claude/devteam.projet.md`,
  `make/standard.mk`, kit de base, `devteam-ci.yml`, `.claude/settings.json`) sont commités sur la base avant de
  démarrer.
- Toutes les commandes passent par `make` (conteneurs). La stack principale tourne (`make start`, `make stack-check`).
- Aucun commit sans demande explicite du développeur ; jamais sur `development`, jamais de `--force` ni de
  `--no-verify`, aucune mention d'IA.

## Avancement

Statut : ✅ terminé (sauf `ci-ok`, en attente : GitHub Actions bloquées par la facturation)

- [x] **Tâche 1** Migrations manquantes (2026-11-15)
- [x] **Tâche 2** flake8 de l'api (2026-11-15)
- [x] **Tâche 3** ESLint nextjs (2026-11-15)
- [x] **Tâche 4** TypeScript nextjs (2026-11-15)
- [x] **Tâche 5** Tests api (2026-11-15)
- [x] **Tâche 6** Test panel (2026-11-15)
- [x] **Tâche 7** Nettoyage des workflows et de l'outillage de bascule (2026-11-15)
- [x] **Tâche 8** Garde-fou des tests (2026-11-15)
- [x] **Tâche 9** `coverage-diff` (2026-11-15)
- [x] **Tâche 10** Configuration d'agent et adaptateurs (2026-11-15)
- [x] **Tâche 11** `compose.agent.yml` et cibles standard dans un worktree d'agent (2026-11-15)
- [x] **Tâche 12** Mesure du budget (2026-11-15)
- [~] **Tâche 13** Vérification (2026-11-15 : tout vert ; `ci-ok` en attente)

> Reprise (2026-11-15) : PR #48 (remise au vert, garde-fou, coverage-diff, environnement d'agent, budget) fusionnée
> dans `development`, migrations appliquées à la stack principale. **Tâche 3** : décisions du développeur :
> `--format=compact` retiré de `lint:strict` (absent d'ESLint 9), `no-console` réglé en
> `["warn", {allow: ["warn", "error"]}]` et 4 `console.log` supprimés (celui de `global-error.tsx` passé en
> `console.error`), `@next/next/no-img-element` désactivée (`<img>` conservé, rendu inchangé). **Tâche 11** : le premier
> `make agent-up` réel a échoué (worktree de lot sans les `.env` ignorés par git) : ajout de l'adaptateur
> `fichiers-locaux` (copie `.env`, `apps/api/.env`, `apps/nextjs/.env` du dépôt principal). Puis
> `make agent-up LOT=essai PROFIL=complet BASE=development` prêt ; dans le worktree du lot, `make lint`, `typecheck`,
> `migrations-check`, `test-cible T="apps/api/apps apps/api/project apps/panel/src"` verts (projet `urbankiff-ag-essai`,
> base du lot acceptée par le garde-fou) ; `api` ne résout que l'api principale ; seul `127.0.0.1:41000` publié ;
> `stack-check` vert avant, pendant et après ; `make agent-down LOT=essai` fait. Laissés au développeur : worktree
> `../urbankiff-wt-essai`, branche `development-essai`, base `urbankiff_essai`, bucket `urbankiff-essai`. **Tâche 12** :
> chaque profil lancé seul : api 750 Mo, front 2 050, panel 1 100, complet 3 050, stack 2 000 ; mémoire Docker
> 13 958 Mo. **Tâche 13** : diagnostic 9/9 `rempli` ; seul `ci-ok` reste en attente (Actions bloquées).
>
> Tâche 5, choix (aucun code de production modifié, les 4 tests étaient faux) :
> `test_login_user` et `test_login_user_icase` : l'utilisateur de test n'avait pas de rôle, or `UserLogin` refuse
> (401) tout compte sans rôle admin/editor/contributor (garde voulue, commit 34d03813 ; le signup assigne
> `contributor`) → le test assigne `contributor`. `test_user_can_request_password_icase` : la vue répond 200
> (réponse générique), le panel (`ForgotPassword.js`) ne traite que 200 → le test attend 200 et vérifie
> `mail.outbox`. `test_user_can_reset_password` : 200 au lieu de 201 et mock de `Mail.send` que la vue n'appelle
> plus → backend mail en mémoire, URL extraite du mail, 200 attendu. Hors périmètre, à traiter à part :
> `apps/nextjs/src/app/api/auth/reset-password/route.ts` envoie `userId` alors que l'api lit `user_id`.

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**.

## Fichiers du lot (exclusifs)

- `apps/api/apps/comment/migrations/**` [nouveau]
- `apps/api/apps/user/migrations/**` [nouveau]
- `apps/api/apps/**` (corrections flake8, tests api)
- `apps/api/project/**`
- `apps/api/libs/**`
- `apps/nextjs/src/**`
- `apps/nextjs/eslint.config.mjs`
- `apps/nextjs/.eslintrc.json`
- `apps/panel/src/**`
- `.github/workflows/nextjs-eslint.yml` (supprimé)
- `make/monorepo.mk` (supprimé)
- `Makefile`
- `make/standard.mk`
- `devteam.agent.conf` [nouveau]
- `compose.agent.yml` [nouveau]
- `scripts/devteam-adaptateurs/**` [nouveau]
- `scripts/devteam/agent-env/**` [nouveau, kit]
- `make/devteam-agent.mk` [nouveau, kit]
- `docs/v1/plans/2026-11-15-devteam-conformite.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docker-compose.yml`, `.env.template`, `apps/*/.env*`, `apps/*/env.*`, `.github/workflows/<app>-deploy-*.yml`,
`.claude/devteam.projet.md`, `.github/workflows/devteam-ci.yml`, `make/devteam.mk`, `scripts/devteam/*.sh`.

Besoin d'y toucher → **s'arrêter et le signaler**.

## Contraintes globales

Aucun mock de la base ni de l'ORM ; fabriques (`factory-boy`) pour les données ; ne jamais modifier le code de
production pour faire passer un test sans l'avoir signalé ; pas de `retry` ni de contournement ; aucune règle de
lint désactivée pour faire passer ; toutes les commandes passent par `make` ; aucun comportement voulu modifié par la
remise au vert.

## Points de revue

1. Migrations : aucune perte de données, uniquement un alignement d'état.
2. Tests api corrigés : pour chacun, le choix test faux / code faux est justifié dans « Reprise » ou dans un commentaire
   de PR.
3. Le garde-fou refuse la base principale et la base d'un autre lot ; hors agent, rien ne change.
4. Un environnement d'agent ne publie aucun port fixe et ne crée aucun service d'infrastructure.

---

### Tâche 1 : migrations manquantes

**Fichiers :** Créer `apps/api/apps/comment/migrations/0008_*.py`, `apps/api/apps/user/migrations/0015_*.py`.

- [ ] **Étape 1** : `make migrations-check` rouge (constaté : `comment` 0008, `user` 0015).
- [ ] **Étape 2** : générer les migrations dans un conteneur api (`docker compose run --rm --no-deps api python
  manage.py makemigrations comment user`) ; relire : seulement des `AlterField`, aucune suppression de colonne.
- [ ] **Étape 3** : `make migrations-check` vert ; `make test-cible T=apps/api/apps` sans régression.

### Tâche 2 : flake8 de l'api

- [ ] **Étape 1** : `make lint-api` rouge (368 constats ; classer par code).
- [ ] **Étape 2** : corriger par code (W293, E302, F401, E111, W292, W291, E114, F841…). Un import inutilisé n'est
  retiré qu'après vérification qu'il n'a pas d'effet de bord (enregistrement de signaux, admin).
- [ ] **Étape 3** : `make lint-api` vert ; tests api sans régression.

### Tâche 3 : ESLint nextjs

- [ ] **Étape 1** : `make lint-nextjs` rouge (« Unexpected key "0" »).
- [ ] **Étape 2** : réparer la configuration à plat (`eslint.config.mjs`) et retirer la configuration héritée en
  double si elle n'est plus lue ; puis corriger les constats de `lint:strict`.
- [ ] **Étape 3** : `make lint-nextjs` vert.

### Tâche 4 : TypeScript nextjs

- [ ] **Étape 1** : `make typecheck` rouge (22 erreurs).
- [ ] **Étape 2** : corriger les types, sans `any` ni `@ts-ignore` ajoutés.
- [ ] **Étape 3** : `make typecheck` vert ; `make lint-nextjs` toujours vert.

### Tâche 5 : tests api

- [ ] **Étape 1** : `make test-cible T=apps/api/apps.user.tests` rouge (`test_login_user`, `test_login_user_icase`,
  `test_user_can_request_password_icase`, `test_user_can_reset_password`).
- [ ] **Étape 2** : pour chacun, trouver la cause et corriger le test ou le code ; noter le choix.
- [ ] **Étape 3** : `make test-cible T=apps/api/apps` vert.

### Tâche 6 : test panel

- [ ] **Étape 1** : `make test-cible T=apps/panel/src` rouge (« Test suite failed to run »).
- [ ] **Étape 2** : faire démarrer la suite (configuration Jest/craco) ou remplacer le test par défaut par un test
  réel du rendu.
- [ ] **Étape 3** : `make test-cible T=apps/panel/src` vert.

### Tâche 7 : nettoyage des workflows et de l'outillage de bascule

- [ ] Supprimer `.github/workflows/nextjs-eslint.yml`, `make/monorepo.mk` et la ligne `-include make/monorepo.mk`.
- [ ] Vérification : actionlint (conteneur `rhysd/actionlint:1.7.7`, `.github` en lecture seule, sans réseau) sur
  `.github/workflows/*.yml` ; `make help` fonctionne.

### Tâche 8 : garde-fou des tests

**Fichiers :** Créer `apps/api/project/test_runner.py`, ses tests ; Modifier `apps/api/project/settings.py`
(`TEST_RUNNER`).

- [ ] **Étape 1** : tests du garde-fou (avec `AGENT_LOT=x` et une base `urbankiff`, refus ; avec la base
  `urbankiff_x`, accepté ; sans `AGENT_LOT`, accepté) ; les voir échouer.
- [ ] **Étape 2** : implémenter le lanceur (sous-classe de `DiscoverRunner`).
- [ ] **Étape 3** : tests verts ; `make test-cible T=apps/api/apps` vert hors agent.

### Tâche 9 : `coverage-diff`

**Fichiers :** Modifier `make/standard.mk`.

- [ ] **Étape 1** : `make -n coverage-diff BASE=development` répond « No rule ».
- [ ] **Étape 2** : api, tests sous `coverage run` puis `coverage xml` ; panel, `craco test --coverage` (lcov) ;
  `diff-cover` à version épinglée dans un conteneur Python, `--compare-branch=$(BASE) --fail-under=100`.
  Commentaire `# d'après :` (spec, Point 4).
- [ ] **Étape 3** : sur une branche d'essai qui modifie une ligne couverte puis une ligne non couverte, la cible est
  respectivement verte puis rouge.

### Tâche 10 : configuration d'agent et adaptateurs

**Fichiers :** Créer `devteam.agent.conf`, `scripts/devteam-adaptateurs/{postgres,redis,s3,port}.sh`.

- [ ] Copier le kit : `devteam.agent.conf.exemple` → `devteam.agent.conf` ; adaptateurs `postgres`, `redis`, `s3`,
  `port` → `scripts/devteam-adaptateurs/`.
- [ ] Remplir : `DEVTEAM_PROJET=urbankiff`, `DEVTEAM_PROFILS="api front panel complet"`, services par profil (spec),
  `DEVTEAM_COMPOSE_FICHIERS="compose.agent.yml"`, `DEVTEAM_PROJET_PRINCIPAL=urbankiff`,
  `DEVTEAM_SERVICES_INFRA="postgresDB redis minio mailhog imgproxy caddy"`, `DEVTEAM_MARGE_MO=1500`,
  `DEVTEAM_RESSOURCES="postgres:urbankiff_{lot} redis:1 s3:urbankiff-{lot} port:<plage>"`, `DEVTEAM_PG_SERVICE=postgresDB`,
  `DEVTEAM_RESEAU_INFRA=URBANKIFF`, `DEVTEAM_S3_ENDPOINT=http://minio:9000` ; coûts à 0 jusqu'à la tâche 12.
- [ ] Adaptateur `postgres` : écrire `AGENT_DB_NAME` au lieu de `DB_NAME` (spec, Point 3).
- [ ] `kit.sh appliquer` pour l'ensemble `agent` ; `make devteam-test` vert.

### Tâche 11 : `compose.agent.yml` et cibles standard dans un worktree d'agent

**Fichiers :** Créer `compose.agent.yml` ; Modifier `make/standard.mk`.

- [ ] `compose.agent.yml` : services `api`, `workers`, `migrations`, `nextjs`, `panel` repris du Compose principal,
  sans `container_name`, sans port fixe (port `127.0.0.1:${AGENT_PORT}` sur le service d'entrée), réseau externe
  `URBANKIFF`, `environment:` pour `POSTGRES_DB=${AGENT_DB_NAME}`, `REDIS_ENDPOINT`, bucket, `AGENT_LOT`.
- [ ] `make/standard.mk` : si `.agent.env` existe, `COMPOSE_RUN` charge ses variables et vise
  `-p urbankiff-ag-$(AGENT_LOT) -f compose.agent.yml`.
- [ ] Vérification : `make agent-up LOT=essai PROFIL=api BASE=development`, puis dans le worktree
  `make test-cible T=apps/api/apps` (base `test_urbankiff_essai`), `make agent-status`, `make agent-down LOT=essai`.
  La stack principale n'est pas touchée (`make stack-check` vert pendant et après).

### Tâche 12 : mesure du budget

- [ ] Pour chaque profil : `make agent-up` seul, régime établi, puis tests et typecheck ; relever le pic avec
  `make agent-status` ou `docker stats` ; reporter les coûts arrondis et `DEVTEAM_STACK_MO` dans
  `devteam.agent.conf` uniquement.
- [ ] `make agent-down` de chaque essai ; worktrees et branches d'essai laissés au développeur pour suppression.

### Tâche 13 : vérification

- [ ] `bash <plugin>/outils/diagnostic.sh <projet>` : neuf points `rempli`, structure `ok`.
- [ ] `make lint`, `make typecheck`, `make migrations-check`, `make test-cible T="apps/api/apps apps/panel/src"`
  verts.
- [ ] PR `chore/devteam-conformite` → `development` : `ci-ok` vert.
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, choix signalés
  (tests api).
