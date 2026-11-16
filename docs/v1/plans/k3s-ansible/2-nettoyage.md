# Lot nettoyage (imgproxy, ancien déploiement, code obsolète, secrets) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A3 (retirer POSTGRES_PASSWORD de secrets.txt, POSTGRES_USER et POSTGRES_DB des variables, notés « générés par CloudNativePG »), A4 (retirer MINIO_ENDPOINT des variables, noté « construit par le chart »), A6 (inventaire : valeurs Twilio de preprod factices), A12 (retirer la cible hotes-scan de make/secrets.mk, ajouté aux fichiers du lot).

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : retirer imgproxy, l'ancien déploiement (scp, Compose de prod, Caddy de prod, sauvegardes et MinIO de
déploiement) et le code de stockage obsolète ; aligner les listes de secrets et l'inventaire sur le contrat « Secrets »
de la spec (§ 8.3) ; garder la stack locale et l'environnement d'agent fonctionnels.

**Architecture** : suppressions et retouches de configuration seulement, sans fonctionnalité nouvelle. Le Compose
local reste l'unique Compose du dépôt. Les listes `scripts/secrets/*.txt` et `docs/v1/infra/secrets.md` restent
cohérentes entre elles (test bats `inventaire.bats`).

**Stack** : Docker Compose, shell + bats (`make secrets-test`), Django (`settings.py`), CRA (panel), Markdown.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité, § 5.6,
§ 5.9, § 8). Plan de la mission `k3s-ansible`, lot 2 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : (renseignée par le superviseur)
- **Branche** : `feature/k3s-ansible-nettoyage` · **Base** : `feature/k3s-ansible` · **Profil** : complet
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 5

- [x] **Tâche 1** Retirer imgproxy partout · `feature/k3s-ansible-nettoyage`
  - [x] Compose, `devteam.agent.conf`, `.claude/devteam.projet.md`, `.env.template`
  - [x] `IMGPROXY_SETUP.md`, `generate_imgproxy_url.py`, `useSignedUrl.js`
  - [x] Listes de secrets et inventaire (`IMGPROXY_KEY`, `IMGPROXY_SALT`)
- [x] **Tâche 2** Retirer l'ancien déploiement et réécrire le README
  - [x] `deploys/`, `caddyprod/`, Compose de prod, `apps/backup_service/`, `apps/minio/`
  - [x] `README.md`
- [x] **Tâche 3** Retirer le code de stockage obsolète (`BUCKETEER_AWS_*`, `REACT_APP_MINIO_*`)
- [x] **Tâche 4** Contrat « Secrets » : Wasabi, déploiement, `REDIS_ENDPOINT`
- [x] **Tâche 5** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `docker-compose.yml`
- `compose.agent.yml`
- `devteam.agent.conf`
- `.claude/devteam.projet.md`
- `.env.template`
- `README.md`
- `IMGPROXY_SETUP.md` [suppression]
- `generate_imgproxy_url.py` [suppression]
- `deploys/**` [suppression]
- `caddyprod/**` [suppression]
- `configs/caddy/**`
- `apps/backup_service/**` [suppression]
- `apps/minio/**` [suppression]
- `apps/api/docker-compose-prod.yml` [suppression]
- `apps/nextjs/docker-compose-prod.yml` [suppression]
- `apps/panel/docker-compose-prod.yml` [suppression]
- `apps/api/project/settings.py`
- `apps/api/env.template`
- `apps/api/.env.temp`
- `apps/panel/.env.development`
- `apps/panel/src/utility/hooks/**`
- `scripts/secrets/**`
- `make/secrets.mk` (arbitrage A12 : retrait de la cible hotes-scan)
- `docs/v1/infra/secrets.md`
- `docs/v1/plans/k3s-ansible/2-nettoyage.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-16-k3s-ansible.md`, `docs/v1/infra/rotation-secrets.md`.
- `.github/workflows/devteam-ci.yml`, `make/devteam.mk`, `make/standard.mk`, `make/secrets.mk`,
  `make/devteam-agent.mk`, `Makefile`, `.gitignore`, `.gitleaks.toml`, `sh/**`, `init.sh`.
- `configs/pgadmin/**` : **ne pas supprimer** (utilisé par le Compose local).
- `apps/api/apps/file/**` (`libs.py`, `tasks.py`, `tests.py` lisent `settings.AWS_*`), `apps/api/requirements*.txt`.
- Fichiers exclusifs des autres lots (`apps/api/Dockerfile`, `apps/nextjs/Dockerfile`, `apps/panel/Dockerfile`, etc.).
- Fichiers `.env` locaux ignorés par git (`.env`, `apps/api/.env`, `apps/panel/.env`) : ne pas les committer ; les
  régénérer à la main dans le worktree si une vérification l'exige.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par `make` (sur l'hôte :
`docker`, `make`, `git`, `gh` seulement) ; aucun mock de la base ni de l'ORM ; ne jamais modifier le code de
production pour faire passer un test (s'arrêter et le signaler) ; pas de `retry` ni de contournement ; couverture de
100 % du code modifié (le seul code Python modifié est une suppression dans `settings.py`) ; messages de commit en ASCII.
Ce lot ne crée aucune fonctionnalité : chaque suppression est précédée d'une recherche (`grep` via conteneur ou lecture
des fichiers) prouvant qu'aucun code vivant ne lit ce qui est retiré. Aucune valeur de secret dans les fichiers ;
`make secrets-scan` doit rester à zéro.

## Points de revue

1. Aucune référence résiduelle à `imgproxy`, `IMGPROXY_*`, `deploys/`, `caddyprod`, `docker-compose-prod`,
   `backup_service`, `apps/minio`, `uploadDeploys` dans les fichiers du lot (les mentions historiques dans les anciens
   plans et specs ne sont pas du ressort du lot).
2. `settings.py` : `libs.py` et `tasks.py` de l'app `file` lisent encore `settings.AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY` et `AWS_STORAGE_BUCKET_NAME` à l'import : ces trois noms doivent rester définis (à `None`),
   seule la lecture des variables `BUCKETEER_*` et le basculement vers `S3Boto3Storage` disparaissent.
3. `configs/pgadmin` intact ; `configs/caddy/Caddyfile` ne perd que ce qui ne sert plus (le bloc `s3`/`s30` local
   reste : le README s'en sert pour déposer les fichiers de `dummy_data`).
4. `scripts/secrets/secrets.txt` et `variables-*.txt` cohérents avec `docs/v1/infra/secrets.md` (`inventaire.bats`) ;
   contrat 8.3 « Secrets » respecté à la lettre.
5. Le README ne décrit plus les anciens workflows ni les applications supprimées.

---

### Tâche 1 : retirer imgproxy partout

**Fichiers :**
- Supprimer : `IMGPROXY_SETUP.md`, `generate_imgproxy_url.py`, `apps/panel/src/utility/hooks/useSignedUrl.js`
- Modifier : `docker-compose.yml` (service `imgproxy`), `devteam.agent.conf` (`DEVTEAM_SERVICES_INFRA` perd
  `imgproxy`), `.claude/devteam.projet.md` (liste des services d'infrastructure de la section `agent_env`),
  `.env.template` (bloc « ImgProxy Configuration » commenté), `scripts/secrets/secrets.txt` (lignes `IMGPROXY_KEY`,
  `IMGPROXY_SALT`), `docs/v1/infra/secrets.md` (les deux lignes `IMGPROXY_*`)
- Test : `make secrets-test` (cohérence listes / inventaire)

**Interfaces :**
- Consomme : état actuel (imgproxy référencé par `docker-compose.yml`, `devteam.agent.conf`, `.claude/devteam.projet.md`,
  `.env.template`, `secrets.txt`, `secrets.md`, `useSignedUrl.js`).
- Produit : plus aucune référence imgproxy dans le périmètre du lot ; `DEVTEAM_SERVICES_INFRA="postgresDB redis minio
  mailhog caddy"`. Les fichiers `.env` locaux ignorés peuvent encore contenir `IMGPROXY_*` : sans effet.

- [ ] **Étape 1** : prouver qu'aucun code ne lit imgproxy (recherche de `useSignedUrl`, `signUrl`, `REACT_APP_IMGPROXY_*`,
  `IMGPROXY`, `1055` dans `apps/panel/src`, `apps/nextjs`, `apps/api`, `configs/`, `compose.agent.yml`). Un lecteur
  vivant → s'arrêter et signaler. Lancer `make secrets-test` : vert avant modification (base de référence).
- [ ] **Étape 2** : retirer les lignes `IMGPROXY_KEY` / `IMGPROXY_SALT` de `secrets.txt` **avant** l'inventaire pour voir
  `inventaire.bats` rester vert dans les deux sens (nom retiré de la liste, donc l'inventaire peut le perdre) ; puis
  retirer les deux lignes de l'inventaire. `make secrets-test` vert.
- [ ] **Étape 3** : supprimer le service `imgproxy` de `docker-compose.yml` (vérifier qu'aucun `depends_on` ni `links`
  ne le cite), les trois fichiers, le bloc de `.env.template`, la mention dans `devteam.agent.conf` et
  `.claude/devteam.projet.md`.
- [ ] **Étape 4** : `docker compose config` via `make` n'existe pas : valider le Compose par `make start` en tâche 5 ;
  ici, relire le diff. Cocher l'Avancement ; commit `chore: remove imgproxy`.

---

### Tâche 2 : retirer l'ancien déploiement et réécrire le README

**Fichiers :**
- Supprimer : `deploys/**`, `caddyprod/**`, `apps/api/docker-compose-prod.yml`, `apps/nextjs/docker-compose-prod.yml`,
  `apps/panel/docker-compose-prod.yml`, `apps/backup_service/**`, `apps/minio/**`
- Modifier : `README.md`
- Test : recherche de références résiduelles + `make lint`

**Interfaces :**
- Consomme : tâche 1 (Compose déjà allégé).
- Produit : un seul Compose (`docker-compose.yml`) et `compose.agent.yml` ; README sans les lignes `apps/minio`,
  `apps/backup_service`, sans la section « Releases et déploiements » (workflows `<app>-deploy-to-prod.yml`, déploiement
  de `minio`), qui renvoie à la spec `docs/v1/specs/2026-11-16-k3s-ansible.md` pour le déploiement k3s.

- [ ] **Étape 1** : rechercher les références aux dossiers à supprimer dans les fichiers **hors lot** (`Makefile`,
  `make/*.mk`, `sh/`, `init.sh`, `.github/`, `.gitignore`, `.gitleaks.toml`) et dans `docker-compose.yml`,
  `compose.agent.yml`, `.env.template`. Constats connus : `make/secrets.mk` (lecture seule) a une cible `hotes-scan` qui
  lit `caddyprod/CaddyFile`, et `.gitignore` cite `apps/backup_service/` ; `sh/install.sh` cite `minio` et
  `backup_service` dans un commentaire. **Ne pas y toucher** : signaler dans l'issue (voir « Points à signaler »).
  `.gitleaks.toml` : si une règle ou exception cite un fichier supprimé, signaler.
- [ ] **Étape 2** : supprimer les dossiers et fichiers listés (`git rm -r`), ne pas toucher à `configs/pgadmin`.
- [ ] **Étape 3** : réécrire `README.md` : retirer les deux lignes du tableau et la section « Releases et déploiements »,
  garder les instructions locales (`make init`, `make start-b` à vérifier dans le `Makefile`, `make seed`, accès S3 local
  et URL locales). Corriger toute commande citée qui n'existe pas. Pas de valeur de secret ajoutée.
- [ ] **Étape 4** : `make lint` vert ; recherche des mots-clés (point de revue 1) vide dans le périmètre ; cocher
  l'Avancement ; commit `chore: remove legacy deployment files`.

---

### Tâche 3 : retirer le code de stockage obsolète

**Fichiers :**
- Modifier : `apps/api/project/settings.py` (bloc « FILE SETTINGS »), `apps/panel/.env.development` (lignes
  `REACT_APP_MINIO_*`), `apps/api/env.template` et `apps/api/.env.temp` (contrôle seulement : ne retirer que ce qui
  correspond à l'obsolète ; `MINIO_*` et `REDIS_ENDPOINT` du local restent, ils servent à la stack locale)
- Test : `apps/api/apps/file/tests.py` (existant, lecture seule) ; `make test-cible T=apps/api/apps`

**Interfaces :**
- Consomme : constat de la tâche 1 (rien dans le panel ne lit `REACT_APP_IMGPROXY_*`) ; inventaire (§ obsolètes).
- Produit : `settings.py` sans `BUCKETEER_*` ni `DEFAULT_FILE_STORAGE`/`STATICFILES_STORAGE` S3 ; `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_STORAGE_BUCKET_NAME` restent définis (`None`) pour `apps/file/libs.py` (lecture seule) ;
  panel sans `REACT_APP_MINIO_*` dans `.env.development`.

- [ ] **Étape 1** : prouver par recherche que rien ne lit `process.env.REACT_APP_MINIO_*` (`apps/panel/src`) et que
  seuls `apps/file/libs.py`, `tasks.py`, `tests.py` consomment `settings.AWS_*`. Lancer
  `make test-cible T=apps/api/apps` : vert avant modification.
- [ ] **Étape 2** : modifier `settings.py` : supprimer les lectures `BUCKETEER_*`, `AWS_DEFAULT_REGION`, `AWS_LOCATION`,
  `AWS_DEFAULT_ACL`, `AWS_QUERYSTRING_AUTH` et le `if AWS_ACCESS_KEY_ID:` ; conserver les trois noms lus par `libs.py`
  à `None`. Ne pas toucher à `MINIO_STORAGE_*`. `test_signed_file` reste ignoré (`skipIf`), comme aujourd'hui.
- [ ] **Étape 3** : retirer les quatre lignes `REACT_APP_MINIO_*` de `apps/panel/.env.development` (le Compose local copie
  ce fichier en `.env` au démarrage du panel).
- [ ] **Étape 4** : `make test-cible T=apps/api/apps` et `make lint` verts ; `make coverage-diff
  BASE=feature/k3s-ansible` (lignes supprimées, rien à couvrir) ; cocher l'Avancement ; commit
  `chore: remove obsolete S3 storage settings`.

---

### Tâche 4 : contrat « Secrets » (Wasabi, déploiement, `REDIS_ENDPOINT`)

**Fichiers :**
- Modifier : `scripts/secrets/secrets.txt`, `scripts/secrets/variables-prod.txt`, `scripts/secrets/variables-preprod.txt`,
  `docs/v1/infra/secrets.md`
- Test : `scripts/secrets/tests/inventaire.bats` (existant ; ajouter un test si besoin), `make secrets-test`

**Interfaces :**
- Consomme : contrat « Secrets (nettoyage) » du § 8.3 de la spec ; tâche 1 (`IMGPROXY_*` déjà retirés).
- Produit (lu par le lot `deploiement`, en lecture seule) : `secrets.txt` contient `WASABI_ACCESS_KEY_ID` et
  `WASABI_SECRET_ACCESS_KEY` (type `saisie`) ; les fichiers `variables-*.txt` contiennent `WASABI_REGION` et
  `WASABI_BUCKET` ; l'inventaire documente `DEPLOY_SSH_KEY` (secret), `DEPLOY_HOST` et `DEPLOY_KNOWN_HOSTS`
  (variables), **posés par le développeur à la mise en service, absents de `secrets.txt` et des `variables-*.txt`** ;
  `REDIS_ENDPOINT` documenté « construit par le chart à partir de `REDIS_PASSWORD` ».

- [ ] **Étape 1** : test d'abord : dans `inventaire.bats`, ajouter un test vérifiant que `WASABI_ACCESS_KEY_ID`,
  `WASABI_SECRET_ACCESS_KEY`, `WASABI_REGION`, `WASABI_BUCKET` figurent dans les listes (grep), qu'aucun
  `IMGPROXY_*` ne figure dans les listes, et que `DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS` figurent dans
  l'inventaire. `make secrets-test` : échec attendu.
- [ ] **Étape 2** : ajouter les deux secrets à `secrets.txt` (type `saisie`, clés Wasabi non générables) ; ajouter
  `WASABI_REGION=` et `WASABI_BUCKET=` aux deux fichiers de variables. **Valeurs inconnues du planificateur** : région et
  nom de bucket Wasabi sont une décision du développeur (un bucket par environnement attendu) ; utiliser les valeurs
  fournies dans l'issue, sinon s'arrêter et poser la question (ne rien inventer qui parte ensuite dans GitHub).
  Retirer `REACT_APP_MINIO_ENDPOINT` des deux fichiers de variables et de l'inventaire (rien dans le panel ne le lit,
  vérifié en tâche 3) ; **ne pas retirer `MINIO_ENDPOINT`** (voir « Points à signaler »).
- [ ] **Étape 3** : mettre à jour `docs/v1/infra/secrets.md` : lignes `WASABI_*` (secrets) avec colonnes d'usage
  (sauvegardes CloudNativePG et copie des fichiers vers Wasabi), nouvelle valeur « saisie masquée (script) » ;
  `WASABI_REGION` et `WASABI_BUCKET` dans les variables ; nouvelle section « Secrets et variables de déploiement » pour
  `DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS` (posés à la main par le développeur, hors script ; mentionner la
  clé de déploiement du poste) ; ligne `REDIS_ENDPOINT` : « construit par le chart » ; mettre à jour la règle d'en-tête
  sur les secrets de déploiement ; retirer `BUCKETEER_*` / `REACT_APP_MINIO_*` de la table des anciens secrets en
  indiquant « code retiré par le lot nettoyage ». Aucune valeur dans le document (le test « aucune valeur » de bats
  le vérifie).
- [ ] **Étape 4** : `make secrets-test` vert ; `make secrets-scan` à zéro ; cocher l'Avancement ; commit
  `feat: add wasabi and deploy secrets to inventory`.

---

### Tâche 5 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make secrets-test` vert ; `make secrets-scan` à zéro.
- [ ] `make lint` et `make typecheck` verts.
- [ ] Tests ciblés : `make test-cible T=apps/api/apps` vert.
- [ ] `make coverage-diff BASE=feature/k3s-ansible` : 100 % du code modifié (aucune ligne ajoutée en Python).
- [ ] `make migrations-check` vert ; `make check-generated` : sans objet.
- [ ] Stack locale depuis le dépôt principal : `make start` puis `make stack-check` vert (services démarrés, api et front
  répondent via Caddy), sans le service `imgproxy` ; `configs/pgadmin` intact.
- [ ] Environnement d'agent du profil complet : `make agent-up LOT=nettoyage PROFIL=complet BASE=feature/k3s-ansible`
  démarre (api, workers, migrations, nextjs, panel) et `DEVTEAM_SERVICES_INFRA` sans `imgproxy` ne casse pas le
  lanceur ; `make agent-status` ; puis `make agent-down LOT=nettoyage` (aucun processus laissé).
- [ ] e2e : sans objet (aucun test e2e).
- [ ] Recherche finale des mots-clés (point de revue 1) vide dans le périmètre du lot.
- [ ] Périmètre : `make devteam-perimetre LOT=nettoyage PLAN=docs/v1/plans/k3s-ansible/2-nettoyage.md
  BASE=origin/feature/k3s-ansible` ; attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée,
  jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler.

## Points à signaler dans l'issue (hors périmètre, à ne pas corriger depuis ce lot)

- `make/secrets.mk` (cible `hotes-scan`, `CADDYFILE_PROD := caddyprod/CaddyFile`) casse quand `caddyprod/` disparaît :
  à retirer ou adapter par le propriétaire du fichier.
- `.gitignore` cite `apps/backup_service/` ; `sh/install.sh` cite `minio` et `backup_service` dans un commentaire.
- `apps/api/apps/file/libs.py` (code S3 `boto3` mort, lit `settings.AWS_*`) et `requirements*.txt` (`boto3`,
  `django-storages`) : nettoyage possible dans un lot futur.
- `MINIO_ENDPOINT` des fichiers de variables désigne `s3*.urbankiff.com:9000`, nom public supprimé par la spec : le
  chart (lot `charts`) fournit le point d'accès interne ; décision à confirmer pour le retirer ou le renommer.
