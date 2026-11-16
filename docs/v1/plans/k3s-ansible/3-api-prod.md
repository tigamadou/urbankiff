# Api de production (image gunicorn, santé) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A13 (les sondes du chart envoient un en-tête Host) ; A14 (fichiers statiques de l'admin hors mission).

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : produire l'image de prod de l'api (`--target prod`) : gunicorn sur le port 8000, utilisateur UID 10001,
écritures seulement dans `/tmp`, configuration dans `project/gunicorn.py`, et le point de santé `GET /api/health/`
(200 si la base répond, 503 sinon), sans changer l'image du Compose local.

**Architecture** : Dockerfile multi-étapes `base` → `prod` → `dev` (dernière étape, identique à l'image actuelle, donc
celle que `docker-compose.yml` et `compose.agent.yml` construisent sans `target`). Le point de santé est une vue DRF
publique qui exécute `SELECT 1` par la connexion Django réelle. La configuration gunicorn est un module Python
(`-c python:project.gunicorn`, déjà utilisé par le `Procfile`).

**Stack** : Python 3.9.13, Django, Django REST framework, gunicorn 20.1.0 (déjà dans `requirements.txt`), PostgreSQL,
Docker.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité). Plan de
la mission `k3s-ansible`, lot 3 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : issue `lot:api-prod` créée par le superviseur
- **Branche** : `feature/k3s-ansible-api-prod` · **Base** : `feature/k3s-ansible` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 1

- [ ] **Tâche 1** Point de santé `/api/health/` · `feature/k3s-ansible-api-prod`
  - [ ] Tests (200 avec la vraie base de test, 405, public, 503 base injoignable) écrits et vus en échec
  - [ ] Vue `health` et route
  - [ ] Tests verts
- [ ] **Tâche 2** Configuration gunicorn
  - [ ] Tests du module `project.gunicorn` écrits et vus en échec
  - [ ] `project/gunicorn.py`
  - [ ] Tests verts
- [ ] **Tâche 3** Dockerfile multi-étapes et `.dockerignore`
  - [ ] Construction des deux cibles
  - [ ] Étape `prod` : non root, `/tmp` seul en écriture
  - [ ] Dernière étape identique à l'image actuelle
- [ ] **Tâche 4** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `apps/api/Dockerfile`
- `apps/api/.dockerignore`
- `apps/api/project/gunicorn.py` (vide aujourd'hui)
- `apps/api/project/urls.py`
- `apps/api/project/views.py`
- `apps/api/project/test_health.py` [nouveau]
- `docs/v1/plans/k3s-ansible/3-api-prod.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-16-k3s-ansible.md` et tous les fichiers exclusifs des autres lots (notamment
  `apps/api/project/settings.py`, au lot `nettoyage`).
- `apps/api/requirements.txt` : gunicorn 20.1.0 y est déjà. Si une dépendance manque, **s'arrêter et le signaler**.
- `apps/api/project/wsgi.py`, `apps/api/project/test_runner.py`, `apps/api/project/tests.py`, `apps/api/Procfile`,
  `docker-compose.yml`, `compose.agent.yml`, `make/standard.mk`, `.claude/devteam.projet.md`.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : tests Django lancés par `make test-cible T=apps/api/...`
(le chemin `apps/api/project/test_health.py` devient le label `project.test_health`) ; le lanceur
`project.test_runner.AgentLotTestRunner` refuse toute base autre que `urbankiff_<lot>` quand `AGENT_LOT` est défini
(ne jamais contourner ce garde-fou) ; couverture par `make coverage-diff BASE=feature/k3s-ansible` ; lint par
`make lint-api` (flake8 avec `--ignore E501,E722,F821,W504`). Au minimum : aucun mock de la base ni de l'ORM ;
fabriques pour les données ; ne jamais modifier le code de production pour faire passer un test (s'arrêter et le
signaler) ; couverture de 100 % du code modifié ; pas de `retry` ni de contournement pour masquer une instabilité ;
toutes les commandes passent par `make`, sauf `docker` autorisé sur l'hôte pour construire et lancer l'image.

Contrat 8.3 de la spec, à respecter tel quel (s'il faut le changer, s'arrêter et le signaler) :

- étape `prod` : gunicorn sur le port 8000, UID 10001, écritures seulement dans `/tmp` ;
- dernière étape inchangée (Compose local : `runserver`, code monté en volume sur `/app`, utilisateur root) ;
- santé `GET /api/health/` → 200 si la base répond, 503 sinon ;
- workers : même image, commande `python manage.py runworkers` ; migrations : même image, commande
  `sh -c "python manage.py migrate && python manage.py loaddata fixtures/admin.json fixtures/mail.json && python manage.py prodseed"`
  (le lot ne les code pas : l'image doit seulement les permettre, voir tâche 3).

## Points de revue

1. L'étape finale du Dockerfile est bien celle du Compose local : `docker build apps/api` sans `--target` produit une
   image équivalente à l'actuelle (même contenu, pas d'`USER`, pas de `CMD` gunicorn).
2. Le point de santé est public (aucune authentification, pas de jeton OAuth lu), n'expose aucun détail d'erreur dans
   la réponse 503 et ne touche que la base (pas de Redis, pas de stockage : une panne de ceux-ci ne doit pas retirer
   l'api du service).
3. Le test 503 est honnête : panne réelle (connexion refusée par le pilote PostgreSQL), aucun mock de l'ORM ni du
   pilote, état de la connexion restauré en `finally`.
4. L'image `prod` n'écrit que dans `/tmp` (testée avec `--read-only --tmpfs /tmp`) et contient aucun secret (`.env`
   exclu par `.dockerignore`).

---

### Tâche 1 : point de santé `/api/health/`

**Fichiers :**
- Créer : `apps/api/project/test_health.py`
- Modifier : `apps/api/project/views.py`, `apps/api/project/urls.py`
- Test : `apps/api/project/test_health.py`

**Interfaces :**
- Consomme : la connexion `django.db.connection` (base PostgreSQL de test créée par Django, nom `test_urbankiff_<lot>`).
- Produit : `GET /api/health/` → `200 {"status": "ok"}` ; `503 {"status": "error"}` si la base ne répond pas ; vue
  `project.views.health`, route nommée `health`. Consommé par les sondes `readiness`/`liveness` du chart et par le
  contrôle de santé du script de déploiement (lots `charts` et `deploiement`).

Décisions de conception :

- Vue DRF `@api_view(['GET'])` avec `@authentication_classes([])` et `@permission_classes([AllowAny])` : les réglages
  par défaut exigent `IsAuthenticated` et lisent des jetons en base.
- Vérification : `with connection.cursor() as cursor: cursor.execute('SELECT 1')`. Attraper `django.db.Error` (couvre
  `OperationalError` et `InterfaceError`), journaliser un avertissement (`logger.warning(..., exc_info=True)`),
  répondre 503 avec un corps fixe.
- La route est déclarée **hors** du bloc `if settings.DEBUG:` de `urls.py` (le chemin `api/` y est pris par `api_root`
  seulement en DEBUG ; `api/health/` est une route distincte). Placer `path('api/health/', health, name='health')`
  dans `urlpatterns`, avant les `include('')` de `apps.file.urls` et `apps.user.urls`.

Test du cas « base indisponible » sans mocker l'ORM : **méthode retenue** : `TransactionTestCase` (pas d'enveloppe
`atomic`, donc la connexion peut être fermée) ; dans le test, fermer la connexion (`connection.close()`), changer dans
`connection.settings_dict` `HOST` en `127.0.0.1` et `PORT` en `1` (aucun service n'écoute : le pilote psycopg2 reçoit
un vrai refus de connexion), appeler le point de santé, puis dans un `finally` restaurer `HOST` et `PORT` d'origine et
refermer la connexion. Pourquoi c'est honnête : la panne est réelle et traverse tout le code Django et le pilote ;
seule la configuration de connexion change ; aucun `patch`, `Mock` ni `side_effect`. Solutions écartées : mocker
`connection.cursor` (interdit, et prouve seulement le `except`) ; arrêter ou bloquer la base partagée (infrastructure
commune à tous les agents, interdit). Contraintes : le refus doit être immédiat (loopback, port 1) pour ne pas
dépendre d'un délai ; un `TransactionTestCase` vide la base de test à sa fin (Django exécute les `TestCase` avant,
aucun effet sur eux).

- [ ] **Étape 1** : écrire `test_health.py` et le voir échouer (404 attendu) :
  - `HealthTests(TestCase)` : `GET /api/health/` sans authentification → 200 et corps `{"status": "ok"}` (la vraie base
    de test répond) ; `POST` → 405 ;
  - `HealthDatabaseDownTests(TransactionTestCase)` : cas décrit ci-dessus → 503, corps `{"status": "error"}`,
    `assertLogs` sur le journal de `project.views` au niveau WARNING, et le message de réponse ne contient ni nom
    d'hôte ni détail du pilote ; puis, dans le même test ou un test suivant, le point de santé répond de nouveau 200
    après restauration (prouve que la connexion est bien rétablie).
  - Lancer : `make test-cible T=apps/api/project/test_health.py` → échec attendu (404 sur la route absente).
- [ ] **Étape 2** : implémenter `health` dans `views.py` et la route dans `urls.py`. Pas d'autre changement dans ces
  fichiers.
- [ ] **Étape 3** : relancer `make test-cible T=apps/api/project/test_health.py` (tout vert) ; `make lint-api` vert ;
  cocher l'Avancement ; commit d'une ligne (par exemple `feat: add api health endpoint`).

---

### Tâche 2 : configuration gunicorn

**Fichiers :**
- Modifier : `apps/api/project/gunicorn.py` (aujourd'hui vide)
- Test : `apps/api/project/test_health.py` (classe `GunicornConfigTests(SimpleTestCase)`, ajoutée dans le même fichier :
  c'est le seul fichier de test du lot)

**Interfaces :**
- Consomme : la variable d'environnement facultative `WEB_CONCURRENCY` (nombre de workers).
- Produit : module `project.gunicorn`, chargé par `gunicorn project.wsgi -c python:project.gunicorn` (même appel que le
  `Procfile`) : `bind = '0.0.0.0:8000'`, `workers = int(WEB_CONCURRENCY, 2 par défaut)`, `worker_tmp_dir = '/tmp'`
  (fichiers de battement de cœur des workers : le système de fichiers racine est en lecture seule dans le cluster),
  `accesslog = '-'`, `errorlog = '-'` (journaux sur la sortie standard), `timeout` suffisant pour les envois de
  fichiers (valeur à choisir et justifier en une ligne de commentaire, le *pourquoi* seulement), `graceful_timeout`
  court. Le mémoire disponible est de 512 Mo (prod) et 384 Mo (preprod) pour le conteneur : deux workers par défaut,
  pas de `preload_app` sans mesure.

- [ ] **Étape 1** : écrire les tests, les voir échouer : importer `project.gunicorn` (`importlib`) et vérifier `bind`,
  `worker_tmp_dir == '/tmp'`, journaux sur `-`, `workers == 2` sans variable ; avec `patch.dict(os.environ,
  {'WEB_CONCURRENCY': '3'})` puis `importlib.reload`, `workers == 3`. Un `patch.dict` d'environnement n'est pas un mock
  de la base. Lancer `make test-cible T=apps/api/project/test_health.py` (échec attendu : attributs absents).
- [ ] **Étape 2** : écrire `project/gunicorn.py`. Ne pas importer `gunicorn` ni Django dans ce module (simple module de
  constantes).
- [ ] **Étape 3** : tests verts, `make lint-api` vert ; cocher l'Avancement ; commit d'une ligne (par exemple
  `feat: add gunicorn configuration`).

---

### Tâche 3 : Dockerfile multi-étapes et `.dockerignore`

**Fichiers :**
- Modifier : `apps/api/Dockerfile`, `apps/api/.dockerignore`
- Test : vérification par construction et lancement (tâche 4 les rejoue ; ici, une première passe)

**Interfaces :**
- Consomme : `project/gunicorn.py` (tâche 2), `project.wsgi`, le point de santé (tâche 1).
- Produit : l'image `ghcr.io/tigamadou/urbankiff-api` (construite par le lot `deploiement`, `--target prod`) ; port
  8000 ; UID/GID 10001 ; commande par défaut gunicorn ; les mêmes commandes workers et migrations du contrat 8.3 se
  lancent par `command:` dans le chart (le chart écrase `CMD` ; l'image n'y ajoute rien).

Structure du Dockerfile (ordre des étapes : la **dernière** doit être celle du Compose local) :

1. `FROM python:3.9.13-bullseye AS base` : contenu actuel inchangé (`WORKDIR /app`, `COPY . .`, installation des
   dépendances). Garder l'image de base épinglée telle quelle (décision de version laissée au lot ; ne pas monter la
   version de Python dans ce lot).
2. `FROM base AS prod` : `ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOME=/tmp` ; création du groupe et de
   l'utilisateur 10001 sans shell de connexion et sans répertoire personnel ; `chmod -R a+rX /app` (le code, copié par
   root, doit rester lisible par 10001 quel que soit le mode des fichiers du contexte) ; `USER 10001:10001` ;
   `EXPOSE 8000` ; `CMD ["gunicorn", "project.wsgi", "-c", "python:project.gunicorn"]`.
3. `FROM base AS dev` (**dernière étape**) : aucune instruction de plus. Résultat identique à l'image actuelle : root,
   pas de `CMD`, `docker-compose.yml` et `compose.agent.yml` fournissent leur propre `command`.

`.dockerignore` : garder les entrées actuelles, ajouter ce qui ne doit jamais entrer dans l'image : `.env.*` (dont
`.env.temp`), `**/__pycache__`, `.vscode`, `media/`, `staticfiles/`, `.git`, `*.md`. Ne pas exclure `fixtures/`,
`seed/`, `templates/`, `libs/`, `apps/`, `project/` (nécessaires, dont les fixtures du Job de migrations).

- [ ] **Étape 1** : lire l'image actuelle de référence (`docker build -t urbankiff-api-ref apps/api` sur la base
  `feature/k3s-ansible`, `docker image inspect` : `Config.User`, `Config.Cmd`, taille) pour comparer ensuite.
- [ ] **Étape 2** : écrire le Dockerfile et le `.dockerignore`.
- [ ] **Étape 3** : construire les deux cibles : `docker build --target prod -t urbankiff-api-prod-<lot>:test apps/api`
  puis `docker build -t urbankiff-api-dev-<lot>:test apps/api` ; vérifier que l'image sans cible a le même `Config.User`
  et `Config.Cmd` que la référence ; cocher l'Avancement ; commit d'une ligne (par exemple
  `feat: add prod stage to api Dockerfile`).

---

### Tâche 4 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint-api` vert (le lot ne touche ni nextjs ni panel : `make lint` complet non requis ; `make typecheck`
  sans objet pour l'api).
- [ ] Tests ciblés du lot : `make test-cible T=apps/api/project/test_health.py`. Lancer aussi
  `make test-cible T=apps/api/project` pour prouver que `tests.py` (garde-fou du lanceur) reste vert.
- [ ] `make coverage-diff BASE=feature/k3s-ansible` : 100 % du code modifié (`views.py`, `urls.py`, `gunicorn.py`).
- [ ] `make migrations-check` (le lot ne touche aucun modèle : doit rester vert) ; `make check-generated` : sans objet.
- [ ] e2e : sans objet (aucun test e2e dans le projet).
- [ ] Image de prod, sur l'hôte avec `docker` seulement :
  - [ ] `docker build --target prod -t urbankiff-api-prod-<lot>:verif apps/api` réussit ; `docker image inspect` →
    `Config.User` = `10001:10001`, `ExposedPorts` contient `8000/tcp`.
  - [ ] Lire dans le worktree les valeurs de `.agent.env` (`AGENT_DB_NAME`) ; la base `urbankiff_<lot>` existe si le
    profil `api` est levé (`agent-up`). Lancer l'image sur le réseau `URBANKIFF`, système de fichiers racine en lecture
    seule, nom de conteneur propre au lot : `docker run -d --name urbankiff-api-prod-<lot> --network URBANKIFF
    --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges --env-file apps/api/.env -e
    POSTGRES_DB=<AGENT_DB_NAME> -e POSTGRES_HOST=postgresDB -e POSTGRES_USER=… -e POSTGRES_PASSWORD=… …` (les identifiants
    viennent des variables de la stack, **jamais** copiés dans le plan, un log ou un message ; préférer un fichier
    d'environnement temporaire hors dépôt, supprimé après). **Jamais la base `urbankiff` de la stack principale** ni
    une base d'un autre lot.
  - [ ] Santé : `docker run --rm --network URBANKIFF curlimages/curl:8.11.1 -sS -o /dev/null -w '%{http_code}'
    http://urbankiff-api-prod-<lot>:8000/api/health/` → `200`.
  - [ ] Non root : `docker exec urbankiff-api-prod-<lot> id -u` → `10001` ; le processus gunicorn tourne sous 10001
    (`docker top`).
  - [ ] Écritures : conteneur toujours en `--read-only` sans erreur d'écriture dans `docker logs` (preuve que seul
    `/tmp` est écrit).
  - [ ] Cas 503 : second conteneur avec `POSTGRES_HOST=hote-inexistant` → `503`, corps `{"status":"error"}` et message
    d'avertissement dans les journaux sans mot de passe.
  - [ ] Rejouer avec `-e DJANGO_ENV=production` (valeur du chart en prod) et noter le résultat : `django_heroku` est
    activé dans ce mode et peut imposer `sslmode`/`ALLOWED_HOSTS`. Si le point de santé répond mal en mode `production`
    à cause de `settings.py` (lot `nettoyage`), **ne pas modifier `settings.py`** : le signaler dans le rapport.
  - [ ] Nettoyage : `docker rm -f` des conteneurs et `docker rmi` des images de vérification, aucun processus de fond
    laissé.
- [ ] Périmètre : `make devteam-perimetre LOT=api-prod PLAN=docs/v1/plans/k3s-ansible/3-api-prod.md BASE=origin/feature/k3s-ansible` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler (dont
  la méthode du test 503, le résultat en mode `production`, les écarts avec le contrat 8.3).
