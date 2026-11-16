# Valeurs du projet pour devteam

Réponses d'Urbankiff au contrat de devteam : une section par clé. Les lignes de la forme `- Libellé : …` sont lues
par le diagnostic : garder leur libellé exact. Les chiffres de budget ne sont **jamais recopiés ici** : ils vivent
dans le document cité par `budget`.

## docker

Toutes les commandes de build, test, lint et génération passent par des cibles `make` qui lancent des conteneurs.
Sur l'hôte : `docker`, `make`, `git`, `gh` seulement. Les cibles de déploiement manuel (`uploadDeploys`) et
`init` (création des hôtes locaux) sont hors du périmètre des missions.

## agent_env

- `make agent-up LOT=<lot> PROFIL=<profils> BASE=<branche>`, `make agent-down LOT=<lot>`, `make agent-status`.
- Worktree `../urbankiff-wt-<lot>` ; projet Compose `urbankiff-ag-<lot>`.
- Worktree d'intégration `../urbankiff-wt-integration` sur `feature/<slug>`.
- Profils : `api` (api, workers, migrations), `front` (nextjs sur l'api de la stack principale), `panel` (panel sur
  l'api de la stack principale), `complet` (api, workers, migrations, nextjs, panel).
- Services d'infrastructure partagés, lancés par la stack principale : `postgresDB`, `redis`, `minio` (RustFS),
  `mailhog`, `caddy`.
- « Pas de place » de `agent-up` : ligne `agent-env : pas de place : …` (code 75 du script, réessayer plus tard) ;
  autres échecs = erreur.
- La stack principale se lance toujours depuis le dépôt principal.

## isolation

- Ressources isolées par lot : base Postgres `urbankiff_<lot>` (base de test `test_urbankiff_<lot>` créée par
  Django), numéros de base Redis propres au lot, bucket RustFS `urbankiff-<lot>`, port hôte par lot. Mailhog est
  partagé : le lanceur de tests Django envoie les emails dans une boîte en mémoire.
- Garde-fou : `apps/api/project/test_runner.py`

## cibles

Toutes lancées depuis le worktree : `make test-cible T=<chemins>`, `make coverage-diff BASE=<branche>`, `make lint`,
`make typecheck`, `make generate`, `make check-generated`, `make migrations-check`, `make e2e-fixtures`, `make e2e`.

- `test-cible` aiguille selon le préfixe des chemins : `apps/api/…` → `python manage.py test`, `apps/panel/…` →
  `craco test --watchAll=false`. nextjs n'a pas de tests.
- `lint` : api `flake8`, nextjs `yarn lint:strict`, panel `yarn lint`. `typecheck` : nextjs `yarn type-check`
  (api et panel n'ont pas de typage vérifié).
- `migrations-check` : `python manage.py makemigrations --check --dry-run` (api).
- generate : sans objet (aucun fichier généré versionné ; drf-yasg produit le schéma à l'exécution)
- check-generated : sans objet (aucun fichier généré versionné)
- e2e-fixtures : sans objet (aucun test e2e pour l'instant)
- e2e : sans objet (aucun test e2e pour l'instant)

## branches

- Intégration : `development`
- Protégées : `development`, `main` (règle tenue par les agents : GitHub Free ne permet pas de protection de
  branche sur ce dépôt privé).
- Nommage : `feature/<slug>`, `feature/<slug>-<lot>`, `fix/<slug>-<sujet>`.
- PR de lot vers `feature/<slug>`, fusionnée en merge commit par le lead dev ; PR finale vers la branche
  d'intégration, **jamais fusionnée par un agent**.
- Commits : Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`), en ASCII ; aucune mention d'IA,
  aucun trailer.

## ci

- Check requis : `ci-ok`
- Déclenché sur toute PR ; les jobs ne tournent que pour les applications touchées. `gh` authentifié
  (`gh auth status`).
- Le check n'est pas imposé par GitHub (pas de protection de branche sur GitHub Free) : aucun agent ne fusionne une
  PR dont `ci-ok` n'est pas vert.

## budget

- Document : `devteam.agent.conf`
- Jeton e2e : 1

## generes_migrations

- Générés : sans objet
- Migrations : les modèles et migrations d'une app Django (`apps/api/apps/<app>/`) appartiennent à **un seul lot
  actif** ; un modèle partagé remonte dans un lot amont. `make migrations-check` à chaque fusion.

## taches_planifiees

Application de bureau Claude ouverte, machine éveillée, Docker lancé.

## stack_principale

Démarrage : `make start` ; vérification : `make stack-check` (tous les services démarrés, api et front qui
répondent via Caddy).

## notification

Outil `PushNotification` s'il est disponible dans la session, sinon une ligne `NOTIF …` dans
`.superpowers/sdd/<slug>/state.md`.

## plans

- Specs : `docs/v1/specs` ; plans : `docs/v1/plans/<slug>/<n>-<lot>.md` + `README.md` de la mission.
- Labels : `devteam:<slug>`, `lot:<id>`, `role:dev`, `role:testeur`, `role:planificateur`, `type:lot`, `type:ci`,
  `type:test`, `type:revue`, `etat:pret`, `etat:en-cours`, `etat:en-revue`, `etat:a-corriger`, `etat:bloque`,
  `revue:ok`.
