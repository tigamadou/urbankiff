# Restauration : inspection et répétition de la sauvegarde de prod — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A10 (restauration/<date>/base.dump au format custom et restauration/<date>/fichiers/).

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir, sur le poste du développeur, l'outillage qui inspecte la sauvegarde de prod du 2026-11-16 (base
et bucket) et répète sa restauration dans une base jetable, plus la procédure écrite du premier déploiement de la prod.

**Architecture** : deux scripts shell dans `infra/restauration/`, lancés par deux cibles `make` (`make/restauration.mk`).
Chaque script pilote des conteneurs jetables (PostgreSQL épinglé, réseau Docker interne sans port publié, nettoyage par
`trap`). Le rapport Markdown est écrit dans `infra/restauration/rapports/` (dossier ignoré par un `.gitignore` local au
dossier, donc dans le périmètre du lot) et ne contient que des noms de tables, des décomptes, des noms d'objets de
structure et des préfixes d'URL : jamais de valeur de ligne. Tests bats en conteneur (comme `secrets-test`), sur un dump
fabriqué par le test, sans aucune donnée réelle.

**Stack** : bash, bats (conteneur Alpine), `postgres:<version épinglée>` (client et serveur), `pg_dump`, `pg_restore`,
`psql`, image `api` du Compose pour migrer la base de test.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 5.10, § 5.11, § 8 ; elle fait autorité). Plan de la mission
`k3s-ansible`, lot 8 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : (renseignée par le superviseur)
- **Branche** : `feature/k3s-ansible-restauration` · **Base** : `feature/k3s-ansible` · **Profil** : api
- **Dépendances** : `socle` (lot 1) doit être fusionné dans la base avant de démarrer (inclusion des `make/*.mk`).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 7

- [x] **Tâche 1** Squelette : dossier ignoré, cible de tests, bibliothèque commune · `feature/k3s-ansible-restauration`
  - [x] test bats de la bibliothèque (détection de version, garde-fous d'arguments), échec constaté
  - [x] `infra/restauration/lib.sh`, `.gitignore` local, `make/restauration.mk` (cible `restauration-test`)
- [x] **Tâche 2** Fabrication du dump piégé pour les tests
  - [x] script `tests/fabriquer-dump.sh` : base Django migrée + pièges, `pg_dump -Fc`
  - [x] test bats : le dump est lisible par `pg_restore -l` et contient chaque piège
- [x] **Tâche 3** `inspecter-sauvegarde.sh` : partie base de données
  - [x] tests bats : chaque piège apparaît dans le rapport, aucune donnée personnelle
  - [x] implémentation du script
- [x] **Tâche 4** `inspecter-sauvegarde.sh` : partie bucket
  - [x] tests bats sur un dossier de bucket fabriqué
  - [x] implémentation
- [x] **Tâche 5** `repeter-sauvegarde.sh` : restauration répétée et comparaison des décomptes
  - [x] tests bats : décomptes égaux ; un écart provoqué est détecté
  - [x] implémentation
- [x] **Tâche 6** Cibles `make sauvegarde-inspecter` et `sauvegarde-repeter`
- [ ] **Tâche 7** Procédure `docs/v1/infra/premier-deploiement-prod.md`
- [ ] **Tâche 8** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/restauration/**` [nouveau] (scripts, tests, `.gitignore` local qui ignore `rapports/`)
- `make/restauration.mk` [nouveau]
- `docs/v1/infra/premier-deploiement-prod.md` [nouveau]
- `docs/v1/plans/k3s-ansible/8-restauration.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-16-k3s-ansible.md`, `.claude/devteam.projet.md`, `CLAUDE.md`, `.claude/CLAUDE.md`.
- `Makefile`, `.gitignore` (socle) ; `make/devteam.mk`, `make/standard.mk`, `make/secrets.mk`, `make/devteam-agent.mk`.
- `infra/helm/**` (lot charts : Job de restauration, valeurs `restauration.active` et `restauration.prefixe`),
  `infra/deploiement/**`, `infra/ansible/**`, `.github/workflows/**`.
- `docs/v1/infra/rotation-secrets.md`, `docs/v1/infra/secrets.md`.
- Modèles à lire, jamais à modifier : `apps/api/apps/file/models.py` (`File.url`), `apps/api/apps/post/models.py`
  (`Post.image`), `apps/api/apps/banner/models.py` (`Media.file`), `apps/api/apps/scrapper/models.py`
  (`Scrapper.image`) ; `apps/api/project/settings.py` (`FILES_CDN_ENDPOINT`, ligne 379, lue dans l'environnement ;
  valeur de prod attendue `https://api.urbankiff.com/file`).

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par des cibles `make` qui lancent
des conteneurs (sur l'hôte : `docker`, `make`, `git`, `gh`) ; aucun mock de la base : les tests restaurent dans un vrai
PostgreSQL jetable ; fabriques pour les données (le dump de test est fabriqué par le test, jamais commité) ; ne jamais
modifier le code de production pour faire passer un test (s'arrêter et le signaler) ; pas de `retry` ni de
contournement pour masquer une instabilité (attendre `pg_isready` est une attente, pas un `retry`). Le code de ce lot
est du shell : la « couverture de 100 % » s'entend comme **chaque branche du script exercée par au moins un test bats**
(piège présent/absent, version détectée/illisible, décomptes égaux/différents, dossier de bucket vide/non vide).

Contraintes propres au lot :

1. **Aucune donnée réelle** dans le dépôt, les tests, les journaux ni les rapports. Le rapport ne contient que : noms
   de tables, décomptes, version, noms de rôles/fonctions/déclencheurs/extensions (structure), préfixes d'URL
   (schéma + hôte + premier segment de chemin, sans la suite), types MIME et extensions de fichiers avec décomptes.
   Jamais de valeur de colonne, de nom de fichier de bucket ni de ligne de dump.
2. Le dump et le bucket sont montés **en lecture seule** ; le réseau Docker des conteneurs jetables est `--internal`,
   aucun port publié ; mot de passe PostgreSQL jetable généré à l'exécution, jamais écrit sur disque ni passé en
   argument visible (variable d'environnement du conteneur).
3. Tout conteneur, réseau et volume créé est supprimé en sortie (`trap EXIT`), y compris sur échec ; aucun processus de
   fond laissé en vie.
4. Version de l'image PostgreSQL de la base jetable : **détectée dans l'en-tête du dump** (« Dumped from database
   version ») et signalée dans le rapport ; image `postgres:<majeure détectée>` ; un dump plus récent que la version
   disponible épinglée fait échouer le script avec un message clair. Le client qui lit l'en-tête est une image
   `postgres` épinglée, au moins aussi récente que le dump.
5. Les cibles `make` ont un message d'usage (`Usage : make sauvegarde-inspecter DUMP=<chemin> [BUCKET=<dossier>]`) si
   `DUMP` manque, comme `ports-scan`.
6. Messages et commentaires en français ; noms de fichiers ASCII ; shell `set -euo pipefail`.

## Points de revue

1. Le rapport est exempt de toute donnée personnelle : relire les requêtes SQL du script (aucune ne sélectionne une
   valeur de colonne autre que le calcul d'un préfixe d'URL tronqué ; jamais le chemin complet).
2. Chaque piège du test (rôle, fonction en langage non sûr, déclencheur, extension, `COPY … FROM PROGRAM`, URL `s3.*`,
   fichier exécutable hors `uploads/`) apparaît dans une section dédiée du rapport, et le test échoue si on le retire.
3. La restauration répétée utilise exactement les options de la spec : `pg_restore --no-owner --no-privileges
   --schema=public`, identiques à celles du Job du chart (contrat « Restauration » de 8.3).
4. La comparaison des décomptes porte sur **toutes** les tables du schéma `public` (décompte exact `count(*)`, pas
   l'estimation de `pg_class`), comparés entre une source de référence et la base restaurée.
5. Nettoyage garanti des conteneurs et réseaux (`docker ps -a` et `docker network ls` propres après les tests).
6. La procédure de `premier-deploiement-prod.md` reprend les cinq étapes de la spec (§ 5.10) et rien n'est déployé dans
   `prod`.

---

### Tâche 1 : squelette, cible de tests, bibliothèque commune

**Fichiers :**
- Créer : `infra/restauration/.gitignore` (ignore `rapports/`), `infra/restauration/lib.sh`,
  `infra/restauration/tests/lib.bats`, `make/restauration.mk`
- Modifier : aucun fichier hors lot (le `Makefile` inclut déjà `make/*.mk` grâce au socle ; vérifier)
- Test : `infra/restauration/tests/lib.bats`

**Interfaces :**
- Consomme : contrat « Inclusion make » (socle) ; modèle de la cible `secrets-test` de `make/secrets.mk` (conteneur
  Alpine + bats). Les tests qui pilotent Docker montent le socket (`/var/run/docker.sock`) et installent le client
  `docker-cli` dans le conteneur de test.
- Produit : cible `make restauration-test` ; fonctions de `lib.sh` : `version_pg_du_dump <dump>` (lit l'en-tête via
  `pg_restore -l` dans un conteneur `postgres` épinglé), `demarrer_base_jetable <version>` (réseau interne, conteneur,
  attente `pg_isready`, noms exportés), `nettoyer` (pour `trap`), `ecrire_rapport` (chemin
  `infra/restauration/rapports/<date>-<nom>.md`).

- [ ] **Étape 1** : écrire `lib.bats` (version lue sur un dump minimal fabriqué par `pg_dump -Fc` d'une base vide ;
  dump absent ou non lisible → code non nul et message) ; lancer `make restauration-test`, constater l'échec.
- [ ] **Étape 2** : implémenter `lib.sh`, le `.gitignore` local, `make/restauration.mk` (cible `restauration-test`
  avec `.PHONY`, commentaire `##` comme les autres cibles).
- [ ] **Étape 3** : relancer, tout vert ; vérifier `git status` : `rapports/` n'apparaît pas ; cocher l'Avancement ;
  commit d'une ligne.

---

### Tâche 2 : fabrication du dump piégé

**Fichiers :**
- Créer : `infra/restauration/tests/fabriquer-dump.sh`, `infra/restauration/tests/dump.bats`
- Test : `infra/restauration/tests/dump.bats`

**Interfaces :**
- Consomme : `lib.sh` (tâche 1) ; l'image `api` du Compose et ses variables de base (`DB_NAME`, `DB_USER`,
  `DB_PASSWORD`, hôte PostgreSQL : à lire dans `apps/api/project/settings.py` et `.env.template`, sans les
  modifier) pour exécuter `python manage.py migrate` contre la base jetable (conteneur rattaché au même réseau
  Docker ; le conteneur de l'api est lancé par `docker compose run --rm --no-deps` avec les variables de base
  surchargées). Les modèles `File`, `Post`, `Media` (banner), `Scrapper` fournissent les tables et colonnes d'URL.
- Produit : `fabriquer-dump.sh <sortie.dump>` : base Django réellement migrée, quelques lignes **fabriquées** (fabrique
  SQL minimale : URL de la forme `https://api.example.test/file/x.png`, jamais de donnée réelle) dans `File.url`,
  `post.image`, `banner.Media.file`, `scrapper.image`, dont des URL `https://s3.example.test/...` et
  `https://s30.example.test/...` ; pièges : un rôle (`piege_role`), une fonction PL/pgSQL appelant
  `COPY … FROM PROGRAM` dans son corps, une fonction en langage non sûr si disponible (`plpython3u` absent de l'image
  officielle : sinon une fonction `SECURITY DEFINER`, signalée comme suspecte), un déclencheur sur une table Django,
  l'extension `pg_trgm` (ou `hstore`), une table de tâches planifiées factice `cron.job` (schéma `cron`) ; sortie
  `pg_dump -Fc` (format custom).

- [ ] **Étape 1** : écrire `dump.bats` : après fabrication, `pg_restore -l` liste les tables Django, la fonction
  piège, le déclencheur, l'extension ; le test échoue (script absent).
- [ ] **Étape 2** : implémenter `fabriquer-dump.sh` (attente de disponibilité, `migrate`, insertions, pièges,
  `pg_dump`).
- [ ] **Étape 3** : relancer, vert ; cocher ; commit.

Point d'alerte : si `migrate` ne peut pas tourner depuis le conteneur de test sans toucher un fichier hors lot (par
exemple `.env`), **s'arrêter et le signaler** ; repli accepté par le lot : générer le schéma des quatre tables à partir
de `manage.py sqlmigrate`, jamais à la main.

---

### Tâche 3 : `inspecter-sauvegarde.sh`, partie base de données

**Fichiers :**
- Créer : `infra/restauration/inspecter-sauvegarde.sh`, `infra/restauration/tests/inspecter-base.bats`
- Test : `infra/restauration/tests/inspecter-base.bats`

**Interfaces :**
- Consomme : `lib.sh`, `fabriquer-dump.sh` (tâche 2). Spec § 5.11.
- Produit : `inspecter-sauvegarde.sh <dump> [<dossier-bucket>]` ; rapport Markdown avec les sections :
  1. **Version** : version PostgreSQL du dump (détectée, signalée) et version de l'image jetable ; rappel que la
     version du chart `urbankiff-donnees` doit être égale ou supérieure.
  2. **Tables et décomptes** : toutes les tables de `public` (et des autres schémas non système) avec `count(*)`.
  3. **Rôles** : rôles non système (noms et attributs : superutilisateur, connexion), objets possédés (décompte).
  4. **Fonctions et procédures hors schémas Django** : schéma, nom, langage, `SECURITY DEFINER` ; les langages non
     sûrs (`plpython3u`, `plperlu`, `pltclu`, `c`) sont marqués suspects.
  5. **Extensions** (`pg_extension`) avec version.
  6. **Déclencheurs** non internes : table, nom, fonction appelée.
  7. **Objets suspects** : occurrences de `COPY … FROM PROGRAM` / `COPY … TO PROGRAM` recherchées dans la sortie texte
     de `pg_restore -f -` (corps de fonctions et schéma, décompte seulement ; l'historique des commandes n'est pas
     dans un dump, le dire dans le rapport) ; tâches planifiées : extension `pg_cron`, table `cron.job`, schéma
     `cron`, `pgagent` (décompte de tâches, jamais leur commande).
  8. **Préfixes d'URL distincts** : pour `File.url` (`file_file`), `post.image` (`post_post`), `banner.Media.file`,
     `scrapper.image` (noms de tables relevés dans les modèles et vérifiés dans le dump), préfixe = schéma + hôte +
     premier segment de chemin (`regexp_replace`), décompte par préfixe ; les préfixes dont l'hôte commence par `s3`
     ou `s30` sont signalés « à réécrire ou à valider » ; le préfixe attendu est celui de `FILES_CDN_ENDPOINT` de
     prod (`https://api.urbankiff.com/file`), comparé.
  9. **Bucket** (si `<dossier-bucket>` fourni) : voir tâche 4 ; sinon la mention « non inspecté ».
  Code de sortie 0 même si des pièges sont trouvés (le rapport est la sortie) ; 2 pour un mauvais usage ; non nul pour
  une restauration en échec.

- [ ] **Étape 1** : écrire `inspecter-base.bats` : fabriquer le dump, lancer le script, vérifier dans le rapport la
  présence de `piege_role`, de la fonction `FROM PROGRAM`, du déclencheur, de l'extension, de `cron.job`, des préfixes
  `s3.example.test` (marqués à réécrire) et `api.example.test`, de la version, des décomptes attendus ; vérifier
  qu'**aucune valeur de ligne** (une valeur sentinelle `SENTINELLE_PERSONNELLE` insérée dans une colonne de nom ou
  d'e-mail du dump de test) n'apparaît dans le rapport ; cas d'un dump sans piège : sections vides, mention « aucun » ;
  cas d'un dump illisible : échec propre. Constater l'échec.
- [ ] **Étape 2** : implémenter le script (restauration dans la base jetable **sans** `--schema=public` pour tout
  voir, mais avec `--no-owner --no-privileges` ; les rôles sont lus dans le dump via `pg_restore -f -` car les rôles
  d'un cluster ne sont pas dans un dump `-Fc` de base : ne signaler que ce qui y figure — `OWNER TO`, `GRANT`, `ALTER
  DEFAULT PRIVILEGES` — et le dire dans le rapport).
- [ ] **Étape 3** : relancer, vert ; cocher ; commit.

---

### Tâche 4 : `inspecter-sauvegarde.sh`, partie bucket

**Fichiers :**
- Créer : `infra/restauration/tests/inspecter-bucket.bats`
- Modifier : `infra/restauration/inspecter-sauvegarde.sh`
- Test : `infra/restauration/tests/inspecter-bucket.bats`

**Interfaces :**
- Consomme : tâche 3. Spec § 5.11 (« liste des types de fichiers et des fichiers hors du préfixe `uploads/` »).
- Produit : section Bucket du rapport, calculée dans un conteneur jetable (dossier monté en lecture seule, aucun
  réseau) : décompte par type MIME (`file --mime-type`) ; décompte et taille totale des fichiers **hors `uploads/`**
  (par répertoire de premier niveau, sans nom de fichier) ; **exécutables** : bit d'exécution, binaires ELF/Mach-O,
  scripts (`text/x-shellscript`, `x-php`, `x-python`…), extensions `.sh .php .py .exe .so` (décomptes par extension) ;
  liens symboliques ; fichiers dont le type MIME ne correspond pas à l'extension (images attendues sous `uploads/`) ;
  préfixe `uploads/` absent signalé.

- [ ] **Étape 1** : écrire le test : dossier fabriqué (images factices `uploads/a.png`, un script `.sh` exécutable
  hors `uploads/`, un fichier `.php` dans `uploads/`, un lien symbolique) ; vérifier chaque ligne du rapport et
  l'absence des noms de fichiers ; dossier vide ; dossier inexistant → échec propre. Constater l'échec.
- [ ] **Étape 2** : implémenter.
- [ ] **Étape 3** : relancer, vert ; cocher ; commit.

---

### Tâche 5 : `repeter-sauvegarde.sh`

**Fichiers :**
- Créer : `infra/restauration/repeter-sauvegarde.sh`, `infra/restauration/tests/repeter.bats`
- Test : `infra/restauration/tests/repeter.bats`

**Interfaces :**
- Consomme : `lib.sh`, `fabriquer-dump.sh`. Contrat « Restauration » de 8.3 (mêmes options que le Job du chart).
- Produit : `repeter-sauvegarde.sh <dump>` : (1) base de **référence** : restauration complète du dump (comme à
  l'inspection) ; (2) base **cible** : `pg_restore --no-owner --no-privileges --schema=public` ; (3) comparaison du
  `count(*)` exact de chaque table du schéma `public` entre référence et cible ; (4) rapport Markdown (tableau table /
  source / restauré / égal) ; code de sortie 0 seulement si tous les décomptes sont égaux et qu'aucune table n'a
  disparu ; message final « Restauration répétée : décomptes égaux » ou la liste des tables en écart.

- [ ] **Étape 1** : écrire `repeter.bats` : décomptes égaux sur le dump fabriqué (code 0) ; écart provoqué (le test
  utilise une variable de test documentée `REPETER_TEST_SUPPRIMER=<table>` interdite hors du mode test — ou, mieux,
  un second dump fabriqué dans lequel une table est vidée après `pg_dump` ne peut pas exister : préférer un dump dont
  une table est déclarée dans un schéma autre que `public`, ce qui doit apparaître comme « hors périmètre » et non
  comme écart) ; vérifier le code non nul avec une base cible tronquée par le test (appel direct de la fonction de
  comparaison de `lib.sh` avec deux jeux de décomptes différents). Constater l'échec.
- [ ] **Étape 2** : implémenter ; la fonction de comparaison vit dans `lib.sh` pour être testable seule.
- [ ] **Étape 3** : relancer, vert ; cocher ; commit.

---

### Tâche 6 : cibles `make`

**Fichiers :**
- Modifier : `make/restauration.mk`
- Test : `infra/restauration/tests/make.bats`

**Interfaces :**
- Consomme : scripts des tâches 3 à 5 ; `Makefile` du socle (inclusion automatique de `make/restauration.mk`).
- Produit : `make sauvegarde-inspecter DUMP=<chemin> [BUCKET=<dossier>]`, `make sauvegarde-repeter DUMP=<chemin>`
  (chemins absolus résolus par `abspath` ; message d'usage si `DUMP` manque ; le rapport est écrit dans
  `infra/restauration/rapports/`, dossier ignoré) ; `.PHONY` complet ; chaque cible avec un commentaire `##`.

- [ ] **Étape 1** : test : `make sauvegarde-inspecter` sans `DUMP` → code 2 et usage ; avec `DUMP` inexistant → échec
  propre ; `make -n` des deux cibles montre les scripts attendus. Constater l'échec.
- [ ] **Étape 2** : implémenter.
- [ ] **Étape 3** : relancer, vert ; `make help` (s'il existe) liste les cibles ; cocher ; commit.

---

### Tâche 7 : procédure `premier-deploiement-prod.md`

**Fichiers :**
- Créer : `docs/v1/infra/premier-deploiement-prod.md`

**Interfaces :**
- Consomme : spec § 5.10 « Après la mission » et § 5.11 ; contrat « Restauration » et « Charts » de 8.3 (valeurs
  `restauration.active` et `restauration.prefixe` ; Job du chart qui lance `pg_restore --no-owner --no-privileges
  --schema=public`) ; lecture du chart `infra/helm/**` (lot charts, déjà fusionné ou non : si ses valeurs diffèrent du
  contrat, signaler, ne pas inventer).
- Produit : procédure en français, ordonnée, avec une commande ou une action par étape et un contrôle après chacune :
  0. **Préalables** : chantier Firebase et connexion Google terminé ; `make sauvegarde-inspecter` et
     `make sauvegarde-repeter` faits sur la sauvegarde du 2026-11-16, rapport validé par le développeur (décision sur
     les URL `s3*`), version PostgreSQL du chart alignée sur celle du rapport ; secrets `prod` posés ; DNS non encore
     basculé ;
  1. dépôt du dump dans le bucket Wasabi de prod sous `restauration/<date>/` (chiffrement côté serveur, depuis le
     poste, via l'outil choisi par le développeur : l'identifiant d'accès n'est jamais écrit dans le dépôt ni en
     argument) ;
  2. déploiement de `urbankiff-donnees` avec `restauration.active=true` et `restauration.prefixe=restauration/<date>/`,
     suivi du Job (`kubectl logs` via le compte de déploiement ou l'accès administrateur du développeur), contrôle des
     décomptes avec ceux du rapport de répétition, puis **suppression du fichier temporaire de Wasabi** et retour à
     `restauration.active=false` ;
  3. copie des objets du bucket dans RustFS (même mécanisme que le Job, préfixe `restauration/<date>/bucket/`), puis
     suppression du temporaire ; contrôle par comparaison avec la section Bucket du rapport ;
  4. changement du mot de passe de l'administrateur `prodseed` existant (par la commande Django prévue, sans mot de
     passe en argument ni dans l'historique du shell) ;
  5. DNS : `urbankiff.com`, `api.urbankiff.com`, `panel.urbankiff.com` vers A, puis contrôle TLS (cert-manager) et
     `/api/health/` ;
  6. retour arrière : ce qui se défait à chaque étape (le dump source reste sur le poste ; base vide recréable) ;
  7. rotation : rappel de `docs/v1/infra/rotation-secrets.md` (secrets ayant transité).
  Le document rappelle que rien de ce qui est décrit n'est exécuté par la mission.

- [ ] **Étape 1** : relire la spec et le chart pour vérifier les noms de valeurs, de Secrets et de chemins.
- [ ] **Étape 2** : rédiger ; contrôle de cohérence avec `make secrets-scan` (aucun secret, aucune donnée réelle).
- [ ] **Étape 3** : cocher ; commit.

---

### Tâche 8 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make restauration-test` vert (toutes les suites bats) ; `docker ps -a`, `docker network ls` et `docker volume ls`
  sans reste des tests.
- [ ] `make lint` et `make typecheck` verts (ils ne couvrent pas le shell : la qualité du shell est portée par
  `restauration-test`).
- [ ] Tests ciblés du lot : `make restauration-test` tient lieu de `make test-cible` (aucun test Django dans ce lot ;
  `make test-cible` sans objet).
- [ ] `make coverage-diff` : sans objet (aucun code Python ou JavaScript modifié) ; revue manuelle que chaque branche
  des scripts a un test.
- [ ] `make check-generated` et `make migrations-check` : sans objet (aucun modèle modifié).
- [ ] e2e du lot : sans objet (aucune UI, aucun e2e dans le projet).
- [ ] `make secrets-scan` à zéro ; recherche d'une donnée réelle ou d'une URL de prod dans les tests : aucune hors
  `https://api.urbankiff.com/file` (valeur publique attendue de `FILES_CDN_ENDPOINT`).
- [ ] Périmètre : `make devteam-perimetre LOT=restauration PLAN=docs/v1/plans/k3s-ansible/8-restauration.md
  BASE=origin/feature/k3s-ansible` ; attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée,
  jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler.
