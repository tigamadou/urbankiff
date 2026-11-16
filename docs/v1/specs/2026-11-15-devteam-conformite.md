# Urbankiff : mise en conformité avec le contrat devteam — environnement d'agent, isolation, budget, remise au vert

> Rédigée par `/devteam:conformite` le 2026-11-15 ; validée par le développeur le 2026-11-15. Elle s'exécute de
> façon **séquentielle** (le contrat n'étant pas rempli, une mission parallèle est impossible), par exemple avec
> `superpowers:subagent-driven-development`, à partir du plan joint
> (`docs/v1/plans/2026-11-15-devteam-conformite.md`). Précédente : `2026-11-15-monorepo-devteam.md` (structure).

## 1. Diagnostic de départ

| Point | État | Constat |
| --- | --- | --- |
| structure | ok | un seul dépôt |
| 1 docker | rempli | |
| 2 agent_env | partiel | cibles `agent-up`, `agent-down`, `agent-status` absentes |
| 3 isolation | partiel | garde-fou `apps/api/project/test_runner.py` introuvable |
| 4 cibles | partiel | `coverage-diff` absente |
| 5 branches | rempli | |
| 6 ci | rempli | `ci-ok` existe mais n'est pas imposé (GitHub Free) ; rouge sur l'état actuel du code |
| 7 budget | partiel | `devteam.agent.conf` introuvable |
| 8 generes_migrations | rempli | |
| 9 taches_planifiees | rempli | |

État des cibles le 2026-11-15 : `stack-check` vert ; `migrations-check` rouge (migrations manquantes `comment` et
`user`) ; `lint-api` rouge (368 constats flake8) ; `lint-nextjs` rouge (configuration ESLint invalide :
« Unexpected key "0" ») ; `lint-panel` vert ; `typecheck` rouge (22 erreurs TypeScript) ; tests api rouges
(`apps.user.tests` : 2 échecs, 2 erreurs sur 11 tests) ; tests panel rouges (la suite `src/App.test.js` ne démarre
pas).

## 2. Ce qui reste à construire, et pourquoi

### Point 2 : environnement d'agent

- **Moteur** : celui du kit devteam (`scripts/devteam/agent-env/agent-env.sh`, `make/devteam-agent.mk`,
  `devteam.agent.conf`). Raison : le projet n'a aucun environnement d'agent propre, et le kit gère déjà le budget,
  les worktrees et le signal « pas de place ».
- **Profils** (réponse du développeur) :

  | Profil | Services Compose |
  | --- | --- |
  | `api` | `api`, `workers`, `migrations` |
  | `front` | `nextjs`, branché sur l'api de la stack principale |
  | `panel` | `panel`, branché sur l'api de la stack principale |
  | `complet` | `api`, `workers`, `migrations`, `nextjs`, `panel` |

- **Infrastructure partagée** (`DEVTEAM_SERVICES_INFRA`) : `postgresDB`, `redis`, `minio`, `mailhog`, `imgproxy`,
  `caddy`, projet Compose principal `urbankiff`, réseau `URBANKIFF`.
- **`compose.agent.yml`** : redéfinit les services applicatifs pour l'agent. Le `docker-compose.yml` principal fige
  `container_name` partout, publie des ports fixes (`8000`, `3000`, `3050`…) et déclare les services
  d'infrastructure : le fichier d'agent ne doit rien en hériter. `DEVTEAM_COMPOSE_FICHIERS="compose.agent.yml"`
  (fichier autonome plutôt que surcharge : Compose ne sait pas retirer un `container_name` ni un port par
  surcharge). Services sur le réseau externe `URBANKIFF`, sans `container_name`, port publié seulement sur
  `127.0.0.1:${AGENT_PORT}` pour le service d'entrée du profil. Variables de l'agent injectées par `environment:`
  (elles priment sur `env_file`) : base Postgres, numéro Redis (`REDIS_ENDPOINT=redis://redis_cache:6379/<n>`),
  bucket, `AGENT_LOT`.
- **Cibles standard dans un worktree d'agent** : `make/standard.mk` appelle aujourd'hui le Compose principal. Quand
  `.agent.env` existe à la racine du worktree, `COMPOSE_RUN` doit viser le projet `urbankiff-ag-<lot>` et
  `compose.agent.yml`, avec les variables de `.agent.env` chargées, pour que les tests tournent sur la base du lot
  (et jamais sur celle de la stack principale).
- **Mesure des coûts** : section Point 7.

### Point 3 : isolation des données

| Ressource | Isolation par lot | Adaptateur |
| --- | --- | --- |
| Base Postgres | base `urbankiff_<lot>` ; base de test `test_urbankiff_<lot>` créée par Django | `postgres` (service `postgresDB`) |
| Cache et files Redis | numéros de base propres au lot (0 et 1 restent à la stack principale) | `redis` (service `redis`, conteneur `redis_cache`) |
| Stockage S3 (RustFS) | bucket `urbankiff-<lot>` | `s3` (endpoint `http://minio:9000`, identifiants de développement de `.env.template`) |
| Port hôte | un port par lot dans une plage | `port` |
| Emails | Mailhog partagé, sans isolation : le lanceur de tests Django remplace l'envoi par une boîte en mémoire | aucun |

Les adaptateurs du kit sont copiés dans `scripts/devteam-adaptateurs/` et appartiennent ensuite au projet. À
ajuster : l'adaptateur `postgres` écrit `DB_NAME`, qui est aussi une variable du `.env` racine (nom de la base de la
stack principale) ; il écrira `AGENT_DB_NAME` pour lever toute ambiguïté. La variable de bucket lue par l'api
(`MINIO_DEFAULT_BUCKETS` en local, `BUCKETEER_BUCKET_NAME` pour le stockage S3) est confirmée en lisant
`project/settings.py` et le code de stockage à la tâche concernée.

**Garde-fou** : `apps/api/project/test_runner.py`, déclaré par `TEST_RUNNER` dans `project/settings.py`. Quand
`AGENT_LOT` est défini, il refuse de lancer les tests si `DATABASES['default']['NAME']` n'est pas
`urbankiff_<AGENT_LOT>`. Il a ses propres tests. Hors agent (`AGENT_LOT` absent), le comportement est inchangé.

### Point 4 : `coverage-diff`

Décision du développeur : ajouter les outils. api : `coverage.py` (lancement des tests sous `coverage run`) et
`diff-cover` sur le rapport XML, comparé à `BASE`. panel : `craco test --coverage` (Jest inclus) produit un rapport
lcov, lu par `diff-cover`. `diff-cover` tourne dans un conteneur outil à version épinglée, pas dans les dépendances de
l'application. Cible `make coverage-diff BASE=<branche>`, seuil 100 % du code modifié (règle devteam), et
l'aiguillage est le même que `test-cible` (seules api et panel ont des tests).

### Point 7 : budget machine

Méthode de mesure : chaque profil lancé seul, en régime établi, puis pendant ses commandes les plus lourdes (tests,
typecheck) ; valeur retenue = pic observé arrondi. Les chiffres vont dans `devteam.agent.conf`, jamais ailleurs.
Marge laissée à la machine : 1 500 Mo (réponse du développeur). Mémoire Docker relevée le 2026-11-15 : 13,6 Go, à
remesurer avec `docker info` au moment de remplir le fichier.

### Remise au vert (préalable à `ci-ok`)

Décision du développeur : incluse dans cette mission, puisqu'un `ci-ok` rouge empêche toute fusion de lot. Une tâche
par chantier, dans cet ordre :

1. **Migrations** : générer les migrations manquantes de `comment` et `user` (`makemigrations`), relire qu'elles ne
   font qu'aligner l'état (pas de perte de données), `make migrations-check` vert.
2. **flake8** : corriger les 368 constats de `lint-api`. Corrections mécaniques (espaces, lignes vides, imports
   inutilisés) ; aucune modification de comportement ; la liste `--ignore` existante reste inchangée.
3. **ESLint nextjs** : réparer la configuration (`eslint.config.mjs` et `.eslintrc.json` coexistent ; l'erreur
   « Unexpected key "0" » vient de la configuration à plat), puis corriger les constats de `yarn lint:strict`.
4. **TypeScript nextjs** : corriger les 22 erreurs de `yarn type-check`.
5. **Tests api** : `apps.user.tests` (2 échecs `200 != 201`, 2 erreurs `NoneType`). Pour chaque test : trouver la
   cause ; si le test décrit mal le comportement voulu, corriger le test ; si le code est faux, corriger le code. Chaque
   choix est noté dans le plan et signalé au développeur.
6. **Test panel** : `src/App.test.js` (test par défaut de Create React App) ne démarre pas ; le faire démarrer ou le
   remplacer par un test réel minimal du rendu de l'application.
7. **Workflow en double** : supprimer `.github/workflows/nextjs-eslint.yml`, cassé (`npm ci` sans `package-lock`,
   branche `develop` inexistante) et remplacé par le job `nextjs` de `devteam-ci.yml`.
8. **Outillage de bascule** : supprimer `make/monorepo.mk` et sa ligne d'inclusion (prévu par la spec monorepo).

## 3. Hors périmètre

- Les tests de bout en bout (déclarés sans objet) et la couverture de tests au-delà du code modifié.
- La protection de branche (GitHub Free) et les environnements de secrets GitHub.
- Le déploiement, la production, les secrets versionnés (décision D3 de la spec monorepo).
- Les nouvelles fonctionnalités : la remise au vert ne change aucun comportement voulu.

## 4. Critère de fin

- `bash <plugin>/outils/diagnostic.sh <projet>` sort en 0 (neuf points `rempli`, structure `ok`), et
  `/devteam:conformite` ne propose plus rien à écrire.
- `make lint`, `make typecheck`, `make migrations-check` et `make test-cible T="apps/api/apps apps/panel/src"` verts
  sur la stack principale, puis dans un environnement `make agent-up LOT=essai PROFIL=complet BASE=development`.
- Le garde-fou refuse un lancement de tests d'agent sur la base de la stack principale (test dédié).
- Une PR de la mission a `ci-ok` vert.
