# Jobs de données (restauration, après restauration, export anonymisé) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d'écart) : B1, B3, B4, B5, B7, B10, B11.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir les trois Jobs Helm de la restauration rejouable et de la copie anonymisée : `urbankiff-restauration`
(chart `urbankiff-donnees`, rendu à la demande, remise à zéro du schéma `public`, sans purge), `urbankiff-apres-restauration`
et `urbankiff-export-anonyme` (chart `urbankiff`), avec leurs valeurs, leurs tests helm-unittest et leur documentation.

**Architecture** : aucun Job n'est rendu par un `helm upgrade` ordinaire : chacun est absent tant que sa valeur
déclencheuse est vide (`restauration.prefixe`, `apresRestauration.actif`, `exportAnonyme.prefixe` + `exportAnonyme.bucketCible`).
Le script de déploiement (lot 5) les rend à la demande par `helm template --show-only`, les crée, les suit, les supprime.
Le Job d'export de la prod fait travailler les données réelles **uniquement dans le pod** : `pg_dump` de la base de prod,
restauration dans un PostgreSQL temporaire (sidecar natif, `127.0.0.1`, `emptyDir`), `python manage.py anonymiser`, nouveau
`pg_dump`, dépôt de la seule version anonymisée dans le bucket Wasabi de la preprod, avec uniquement les fichiers cités par le contenu public de la base anonymisée (B1). Les NetworkPolicies existantes sont
réutilisées par le libellé `app.kubernetes.io/component` du pod (voir Points de revue 2 et 3) : le lot ne possède pas
`reseau-donnees.yaml` ni `reseau.yaml`.

**Stack** : Helm 3, helm-unittest, kubeconform, rclone, PostgreSQL (`ghcr.io/cloudnative-pg/postgresql`), image api ;
tout en conteneurs lancés par `make helm-*`.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité). Plan de la mission `outils-donnees`, lot 4 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/outils-donnees-jobs-donnees` · **Base** : `feature/outils-donnees` · **Profil** : `api`
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer). Les commandes
  `reecrire_urls` (lot 1) et `anonymiser` (lot 2) sont consommées telles que décrites au § 8.3, sans être implémentées ici ;
  aucun test de ce lot ne les exécute (helm-unittest vérifie le texte des commandes).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 4

- [x] **Tâche 1** Job de restauration : remise à zéro du schéma, sans purge, rendu à la demande · `feature/outils-donnees-jobs-donnees`
  - [x] tests `restauration_test.yaml` réécrits (échec attendu)
  - [x] `restauration-job.yaml` et section `restauration` de `values.yaml`
- [x] **Tâche 2** Job après restauration (chart `urbankiff`)
  - [x] tests `apres_restauration_test.yaml`
  - [x] `apres-restauration-job.yaml` et valeurs `apresRestauration`
- [x] **Tâche 3** Job d'export anonymisé (chart `urbankiff`)
  - [x] tests `export_anonyme_test.yaml`
  - [x] `export-anonyme-job.yaml` et valeurs `exportAnonyme`, `image.postgres`, `wasabi`
- [ ] **Tâche 4** Documentation : section « Restauration et copie » de `kubernetes.md`
- [ ] **Tâche 5** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/helm/urbankiff-donnees/templates/restauration-job.yaml`
- `infra/helm/urbankiff-donnees/tests/restauration_test.yaml`
- `infra/helm/urbankiff-donnees/values.yaml` (section `restauration` seulement)
- `infra/helm/urbankiff/templates/apres-restauration-job.yaml` [nouveau]
- `infra/helm/urbankiff/templates/export-anonyme-job.yaml` [nouveau]
- `infra/helm/urbankiff/values.yaml`
- `infra/helm/urbankiff/tests/apres_restauration_test.yaml` [nouveau]
- `infra/helm/urbankiff/tests/export_anonyme_test.yaml` [nouveau]
- `docs/v1/infra/kubernetes.md` (section « Restauration et copie » seulement, plus la puce « Job de restauration d'une sauvegarde déposée » de « PostgreSQL, version et restauration », devenue fausse : voir Points de revue 6)
- `docs/v1/plans/outils-donnees/4-jobs-donnees.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec (§ 5.2, 5.3, 5.6, 6, 8), `CLAUDE.md`, `.claude/**`, `make/helm.mk`, `make/devteam.mk`, `make/standard.mk`.
- `infra/helm/urbankiff-donnees/templates/_helpers.tpl` (possédé par le lot 3) et `infra/helm/urbankiff/templates/_helpers.tpl` :
  un helper manquant est **dupliqué localement dans le template** ou signalé, jamais ajouté ici.
- `infra/helm/urbankiff-donnees/templates/reseau-donnees.yaml`, `infra/helm/urbankiff/templates/reseau.yaml`, leurs tests,
  `infra/helm/urbankiff-donnees/values-*.yaml` et `infra/helm/urbankiff/values-*.yaml` (lots 3 et 6),
  `infra/helm/tests-transverses/**` (lot 6), `infra/helm/urbankiff/tests/valeurs-communes.yaml`,
  `infra/helm/urbankiff-donnees/tests/valeurs-communes.yaml`, `infra/helm/urbankiff/templates/migrations-job.yaml`
  (modèle du Job api).
- Les fichiers exclusifs des autres lots : `infra/deploiement/**`, `apps/api/apps/**`, `infra/ansible/**`, etc.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par `make` (sur l'hôte :
`docker`, `make`, `git`, `gh`) ; aucun mock ; ne jamais modifier le code de production pour faire passer un test
(s'arrêter et le signaler) ; pas de `retry` ni de contournement. Ici : le « code » est du YAML Helm, la couverture se
traduit par un test helm-unittest par condition de rendu et par garantie de sécurité ; `make coverage-diff`,
`make migrations-check`, `make lint` (flake8 api) et `make typecheck` sont **sans objet** (aucun fichier Python, aucune
migration) sauf si le lead dit le contraire ; les vérifications utiles sont `make helm-lint`, `make helm-unittest`,
`make helm-controle`.

- Aucun secret en `value:` ni en argument littéral de `command`/`args` : tout passe par `secretKeyRef`/`configMapKeyRef`
  ou par une substitution de shell (`$(cat …)`, `$VAR`). `controle.rb` le vérifie (ses regex portent sur `password|secret|token|key = <non $>`).
- Durcissement identique aux Jobs existants : `automountServiceAccountToken: false`, `securityContextPod`,
  `securityContextConteneur` (lecture seule, aucune capacité, non root), requests **et** limits mémoire sur chaque conteneur
  (init compris), `backoffLimit: 0`, `activeDeadlineSeconds`, `restartPolicy: Never`, aucune annotation `helm.sh/hook`.
- Libellés : `urbankiff.labels` sur le Job **et** sur le gabarit du pod (part-of et component obligatoires pour `controle.rb`).
- Chaque Job est **absent par défaut** (`hasDocuments: count: 0`), et les rendus de `make helm-lint`/`helm-valider` sans
  valeur supplémentaire restent inchangés.
- Le Job ne supprime jamais rien dans Wasabi (aucune purge) et n'écrit jamais la base réelle hors du pod.

## Points de revue

1. **Remise à zéro du schéma `public`** : `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` avec
   `ON_ERROR_STOP`, précédée d'un contrôle que l'utilisateur applicatif possède le schéma (`pg_has_role(current_user,
   nspowner, 'USAGE')`, qui couvre l'appartenance implicite à `pg_database_owner` de PostgreSQL 15). Échec explicite si ce
   n'est pas le cas (spec § 6 : « le constructeur vérifie, sinon il le signale »). Le schéma recréé appartient à
   l'utilisateur applicatif. Aucune extension n'est installée par les modèles (grep fait à la rédaction du plan), donc le
   `CASCADE` n'emporte rien que `pg_restore --schema=public` ne recrée pas.
2. **Réutilisation des NetworkPolicies par le libellé de composant** : `postgres-entree`, `redis-entree`, `rustfs-entree`
   et `migrations-sortie`/`restauration-sortie` (chart `urbankiff-donnees`, lot 3 ou personne) listent des composants
   exacts. Pour ne pas toucher aux fichiers d'autres lots, le pod de `urbankiff-apres-restauration` porte
   `app.kubernetes.io/component: migrations` (même flux : PostgreSQL, Redis, RustFS, Internet 443/465/587) et le pod de
   `urbankiff-export-anonyme` porte `component: restauration` (même flux : PostgreSQL, RustFS, Internet 443). Les Jobs
   eux-mêmes gardent leur propre composant. Un commentaire dans chaque template dit pourquoi. Si le lead préfère des
   NetworkPolicies dédiées, elles relèvent du propriétaire de `reseau-donnees.yaml` : signaler, ne pas contourner.
3. **Aucune donnée réelle hors du pod d'export** : seul le conteneur final `deposer` reçoit les identifiants Wasabi ;
   `anonymiser` ne reçoit **aucune** référence à `urbankiff-pg-app` (sinon il pourrait viser la base de prod) et se
   branche sur `127.0.0.1` ; le dump source est supprimé avant le dépôt ; le Job refuse de se rendre hors de `prod`.
4. **Quota de la preprod** : le plus gros Job compté par `controle.rb` est le plus gros **conteneur** de limite mémoire
   (256 Mi aujourd'hui, celui des migrations). Aucun conteneur des trois Jobs ne doit dépasser 256 Mi en preprod pour que
   la marge (environ 450 Mi) reste inchangée ; au-delà, signaler. Les Jobs ne sont pas rendus par défaut : `controle.rb` ne les
   voit donc que si on les active (voir tâche 5).
5. **Cohérence des commandes avec le contrat 8.3** : texte exact de `apres-restauration` (migrate, reecrire_urls, prodseed,
   clearcache) et journaux de fin `restauration terminée` / `export terminé`, repris par le script du lot 5.
6. **Puce obsolète de `kubernetes.md`** : la puce décrivant `restauration.active`/`purger` est dans la section « PostgreSQL,
   version et restauration », qui n'est pas la section du lot. Elle décrit le chemin supprimé : la remplacer par un renvoi
   vers « Restauration et copie ». Si le lead juge que c'est hors section, la laisser et le signaler.

---

### Tâche 1 : Job de restauration (remise à zéro du schéma, sans purge, rendu à la demande)

**Fichiers :**
- Modifier : `infra/helm/urbankiff-donnees/templates/restauration-job.yaml`, `infra/helm/urbankiff-donnees/values.yaml` (section `restauration`)
- Test : `infra/helm/urbankiff-donnees/tests/restauration_test.yaml` (réécrit)

**Interfaces :**
- Consomme : helpers existants du chart (`urbankiff.labels`, `urbankiff.securityContextPod`, `urbankiff.securityContextConteneur`,
  `urbankiff.wasabiBucket`, `urbankiff.rcloneWasabiEnv`, `urbankiff.rcloneRustfsEnv`, `urbankiff.environnement`) ; Secret
  `urbankiff-pg-app` ; ConfigMap `urbankiff-config` (`MINIO_DEFAULT_BUCKETS`) ; image `postgres` de `image.postgres`/`postgres.version`.
- Produit : Job `urbankiff-restauration`, composant `restauration`, rendu **seulement si `restauration.prefixe` est non vide**
  (rendu par `helm template … --show-only templates/restauration-job.yaml --set restauration.prefixe=<préfixe>`) ; journal
  final `restauration terminée` ; valeurs `restauration.prefixe` (défaut `""`) et `restauration.fichierDump` (défaut
  `base.dump`) ; **disparition** de `restauration.active`, `restauration.purger` et `restauration.copierFichiers`
  (la copie des fichiers est systématique quand `fichiers/` existe : `copierFichiers` n'est pas au contrat, le signaler au lot 5).

- [ ] **Étape 1** : réécrire `restauration_test.yaml` (suite `restauration`, `valeurs-communes.yaml`), le voir échouer :
  - absent par défaut ; absent avec `restauration.prefixe: ""` ;
  - `restauration.active: true` n'a plus d'effet (absent) ;
  - échec de rendu si le préfixe ne correspond pas à `^restauration/[0-9]{4}-[0-9]{2}-[0-9]{2}(-prod-anonyme)?/?$`
    (`errorPattern: "restauration.prefixe"`), y compris un préfixe avec espace, guillemet, `;`, `..` ou `$` ;
  - préfixe `restauration/2026-12-01/` et `restauration/2026-11-17-prod-anonyme/` acceptés (le suffixe est celui de la copie anonymisée) ;
  - `metadata.name: urbankiff-restauration`, `isKind Job`, aucune annotation `helm.sh/hook`, composant `restauration`
    sur le gabarit, `backoffLimit: 0`, `restartPolicy: Never` ;
  - ordre exact des initContainers : `recuperer` (rclone copy `wasabi:$(WASABI_BUCKET)/restauration/2026-12-01` vers
    `/restauration`), `remise-a-zero` (image PostgreSQL, `psql` avec `ON_ERROR_STOP`), `pg-restore`
    (`pg_restore --no-owner --no-privileges --schema=public --dbname=$(PGDATABASE) /restauration/base.dump`) ;
  - le conteneur `remise-a-zero` : texte contenant `DROP SCHEMA public CASCADE` puis `CREATE SCHEMA public`, et le contrôle de
    propriété (`pg_has_role`) avec le message d'échec ; connexion par `PGHOST=urbankiff-pg-rw`, `PGUSER`/`PGPASSWORD`/`PGDATABASE`
    en `secretKeyRef` sur `urbankiff-pg-app` ;
  - le conteneur final `fichiers` : `rclone copy /restauration/fichiers "rustfs:$BUCKET"` seulement si le dossier existe
    (`[ -d /restauration/fichiers ]`, message sinon : une sauvegarde sans fichiers est valide), **aucun** `rclone purge`, **aucun**
    `rclone sync`, **aucun** `delete`, et `echo restauration terminée` en dernier (regex sur `args[0]`) ;
  - aucun secret en `value:`/argument ; durcissement complet sur les trois initContainers et le conteneur ; limites mémoire présentes ;
  - cas jamais purgé : `notMatchRegex` `purge|sync|delete` sur tous les `command`/`args`/scripts du Job.
- [ ] **Étape 2** : implémenter. Condition `{{- if .Values.restauration.prefixe -}}` (plus `restauration.active`), validation du
  préfixe par `regexMatch` + `fail` avec le message citant `restauration.prefixe`, `trimSuffix "/"` conservé. Script du conteneur
  `remise-a-zero` en `sh -c` : **attention** à `$$` (PID en shell) dans un bloc `DO $$ … $$` ; utiliser un script `psql` lu sur
  l'entrée standard par un heredoc entre guillemets (`<<'SQL'`) ou une chaîne en guillemets simples. Section `restauration`
  de `values.yaml` : `prefixe: ""`, `fichierDump: base.dump`, commentaire mis à jour (rendu à la demande par l'action `restaurer`,
  plus de purge, la sauvegarde reste dans Wasabi). Ne toucher à aucune autre section de `values.yaml`.
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff-donnees` vert ; `make helm-lint` vert ; cocher l'Avancement ; commit
  d'une ligne (`feat: job de restauration rejouable (remise a zero du schema public, sans purge)`).

---

### Tâche 2 : Job après restauration (chart `urbankiff`)

**Fichiers :**
- Créer : `infra/helm/urbankiff/templates/apres-restauration-job.yaml`
- Modifier : `infra/helm/urbankiff/values.yaml`
- Test : `infra/helm/urbankiff/tests/apres_restauration_test.yaml`

**Interfaces :**
- Consomme : `migrations-job.yaml` comme modèle ; helpers du chart `urbankiff` (`urbankiff.imageApi`, `urbankiff.imagePullSecrets`,
  `urbankiff.envFrom`, `urbankiff.envApp`, `urbankiff.labels`, contextes de sécurité) ; commandes `reecrire_urls` (lot 1,
  contrat 8.3) et `prodseed`/`clearcache` existantes.
- Produit : Job `urbankiff-apres-restauration`, rendu **seulement si `apresRestauration.actif=true`** ; valeurs
  `apresRestauration.actif: false` et `apresRestauration.ressources` (requests 128Mi, limits 256Mi, pour ne pas dépasser le plus gros
  Job de la preprod) ; journal Kubernetes par la sortie des commandes (le script du lot 5 lit l'état du Job).

- [ ] **Étape 1** : écrire `apres_restauration_test.yaml` (`valeurs-communes.yaml`), le voir échouer :
  - absent par défaut ; rendu avec `apresRestauration.actif: true` ;
  - `metadata.name: urbankiff-apres-restauration`, composant du Job `apres-restauration`, composant **du pod** `migrations`
    (Points de revue 2), aucune annotation de crochet, `backoffLimit: 0`, `restartPolicy: Never`, `activeDeadlineSeconds` borné ;
  - commande exacte du contrat 8.3 : `["sh", "-c", "python manage.py migrate && python manage.py reecrire_urls && python manage.py prodseed && python manage.py clearcache"]`
    (pas de `loaddata` : les fixtures viennent du dump) ;
  - image `ghcr.io/tigamadou/urbankiff-api:1.2.3` (image de l'api de la version déployée), `envFrom` du Secret et de la ConfigMap,
    `env` identique à celui de l'api (`POSTGRES_PASSWORD` par `secretKeyRef` sur `urbankiff-pg-app`, TWILIO inertes si `sms.actif`
    faux), durcissement, volume `tmp`, limite mémoire 256Mi.
- [ ] **Étape 2** : implémenter en dupliquant la structure de `migrations-job.yaml` (condition `{{- if .Values.apresRestauration.actif -}}`,
  `ressources` de `apresRestauration`) ; commentaire de template sur le libellé de composant du pod. Ajouter la section
  `apresRestauration` à `values.yaml`, hors des sections existantes.
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 3 : Job d'export anonymisé (chart `urbankiff`)

**Fichiers :**
- Créer : `infra/helm/urbankiff/templates/export-anonyme-job.yaml`
- Modifier : `infra/helm/urbankiff/values.yaml`
- Test : `infra/helm/urbankiff/tests/export_anonyme_test.yaml`

**Interfaces :**
- Consomme : commandes `anonymiser` et `lister_fichiers_publics` (lot 2, contrat 8.3 et B1 : code 2 sans `ANONYMISATION_AUTORISEE=1` et `POSTGRES_HOST` en `127.0.0.1`/`localhost` ; la seconde écrit une clé d'objet par ligne sur la sortie standard, relative à la racine du bucket) ;
  helpers du chart `urbankiff` ; Secret `urbankiff-pg-app` (base de prod, lue seulement par le conteneur de dump source) ;
  Secret `urbankiff-secrets` (`WASABI_ACCESS_KEY_ID`, `WASABI_SECRET_ACCESS_KEY`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`) ;
  ConfigMap `urbankiff-config` (`MINIO_DEFAULT_BUCKETS`). Les helpers rclone du chart `urbankiff-donnees` ne sont pas disponibles
  dans ce chart : **dupliquer** localement dans le template les blocs `env` rclone (remotes `wasabi` et `rustfs`), sans modifier `_helpers.tpl`.
- Produit : Job `urbankiff-export-anonyme`, rendu **seulement si `exportAnonyme.prefixe` et `exportAnonyme.bucketCible` sont non vides**,
  **échec de rendu si `environnement` ≠ `prod`** (une fois le rendu demandé : le rendu preprod par défaut doit rester valide) ;
  dépôt sous `<bucketCible>/<prefixe>base.dump` et `<bucketCible>/<prefixe>fichiers/` ; journal final `export terminé` ; valeurs
  `exportAnonyme.{prefixe,bucketCible,ressources,pgTemp.ressources,tailleTravail}`, `image.postgres`, `exportAnonyme.versionPostgres`
  (défaut 15, aligné sur `postgres.version` de l'autre chart), `wasabi.region`, `wasabi.endpoint`.

Structure du pod (ordre des initContainers, vérifié par les tests ; ordre : `pg-temp`, `dump-source`, `restaurer-temp`, `anonymiser`, `lister-fichiers`, `dump-anonyme`) :

0. `pg-temp` : PostgreSQL temporaire, **sidecar natif** (`restartPolicy: Always`, Kubernetes 1.36 sur le serveur), image PostgreSQL,
   `initdb` dans un `emptyDir` avec mot de passe aléatoire généré dans le pod (`/dev/urandom`, fichier du volume de travail,
   jamais en argument), `listen_addresses=127.0.0.1`, `unix_socket_directories=/tmp`, `startupProbe` `pg_isready -h 127.0.0.1`.
   Contraintes à régler à l'exécution : l'image CloudNativePG ne connaît que l'UID 26 pour `initdb` (pas d'entrée `passwd` pour
   10001) : surcharger `runAsUser: 26` et `runAsGroup: 10001` sur ce conteneur seulement (non root, lecture seule, `emptyDir`
   écrits via `fsGroup: 10001`, `umask` donnant le groupe en lecture sur le fichier de mot de passe).
1. `dump-source` : `pg_dump --format=custom` de la base de prod (`PGHOST=urbankiff-pg-rw`, identifiants par `secretKeyRef` sur
   `urbankiff-pg-app`) vers `/travail/source.dump`.
2. `restaurer-temp` : `pg_restore --no-owner --no-privileges -h 127.0.0.1` dans la base temporaire.
3. `anonymiser` : image api ; **aucune** référence à `urbankiff-pg-app` ; `env` : `ANONYMISATION_AUTORISEE=1`,
   `POSTGRES_HOST=127.0.0.1`, `POSTGRES_DB`/`POSTGRES_USER` de la base temporaire ; mot de passe lu dans le fichier du pod
   (`POSTGRES_PASSWORD=$(cat /travail/mdp) python manage.py anonymiser`, substitution de shell, pas de littéral) ;
   `envFrom` Secret + ConfigMap (le code lit ses réglages à l'import ; `envFrom` ne contient pas de `POSTGRES_*`, l'`env` explicite l'emporte).
4. `lister-fichiers` : image api, **mêmes `env` que `anonymiser`** (base temporaire anonymisée, `ANONYMISATION_AUTORISEE=1`, aucune référence à `urbankiff-pg-app`) ; `POSTGRES_PASSWORD=$(cat /travail/mdp) python manage.py lister_fichiers_publics > /travail/fichiers.txt`, échec si la liste est vide ou si la commande échoue (B1).
5. `dump-anonyme` : `pg_dump --format=custom` de la base temporaire vers `/travail/anonyme.dump`, puis **suppression de
   `/travail/source.dump`**.
6. conteneur `deposer` (rclone, **seul** à recevoir les identifiants Wasabi) : `rclone copyto /travail/anonyme.dump
   wasabi:$CIBLE/<prefixe>base.dump`, contrôle de présence/taille après copie, `rclone copy --files-from /travail/fichiers.txt rustfs:$BUCKET
   wasabi:$CIBLE/<prefixe>fichiers` (jamais le bucket entier), `echo export terminé`. Aucun `purge`/`sync`/`delete`.

- [ ] **Étape 1** : écrire `export_anonyme_test.yaml` (`valeurs-communes.yaml`, `environnement: prod` par `set` dans les cas utiles),
  le voir échouer :
  - absent par défaut, absent avec seulement `prefixe`, absent avec seulement `bucketCible` ;
  - **échec** (`failedTemplate`, `errorPattern` citant `prod`) avec `environnement: preprod` + `prefixe` + `bucketCible` ; le rendu
    preprod sans valeurs d'export reste vide (pas d'échec) ;
  - validation : préfixe `restauration/2026-11-17-prod-anonyme/` accepté ; préfixe sans suffixe `-prod-anonyme`, avec `..`, espace ou
    caractère de shell refusé ; `bucketCible` non conforme à `^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$` refusé ;
  - `metadata.name: urbankiff-export-anonyme`, composant du Job `export-anonyme`, composant **du pod** `restauration`
    (Points de revue 2), `backoffLimit: 0`, `activeDeadlineSeconds` borné, aucune annotation de crochet ;
  - ordre et noms des initContainers 0 à 5 (`lister-fichiers` entre `anonymiser` et `dump-anonyme`), `pg-temp` avec `restartPolicy: Always`, `startupProbe` présente, `runAsUser: 26` limité à ce conteneur ;
  - `lister-fichiers` : même garde-fou que `anonymiser` (`ANONYMISATION_AUTORISEE` = `"1"`, `POSTGRES_HOST` = `127.0.0.1`, aucun `secretKeyRef` sur `urbankiff-pg-app`), commande `python manage.py lister_fichiers_publics`, sortie redirigée vers `/travail/fichiers.txt` ;
  - `deposer` copie avec `--files-from /travail/fichiers.txt` (regex sur le script) et **aucune copie du bucket entier** : `notMatchRegex` d'un `rclone copy rustfs:$BUCKET` sans `--files-from` ;
  - `anonymiser` : `ANONYMISATION_AUTORISEE` = `"1"`, `POSTGRES_HOST` = `127.0.0.1`, aucun `secretKeyRef` sur `urbankiff-pg-app`, image api ;
  - **identifiants** : `urbankiff-pg-app` référencé par `dump-source` seulement ; clés `WASABI_*` référencées par `deposer` seulement ;
  - `dump-source` supprimé avant le dépôt (regex `rm` dans `dump-anonyme`) ; le dépôt cible `wasabi:$CIBLE/restauration/…/base.dump`
    et `…/fichiers` avec `CIBLE` valant `bucketCible` ; aucun `purge|sync|delete` ;
  - `export terminé` dernière commande ; limites mémoire sur tous les conteneurs ; durcissement, `emptyDir` avec `sizeLimit` pour `travail`.
- [ ] **Étape 2** : implémenter le template et les valeurs (`exportAnonyme`, `image.postgres: ghcr.io/cloudnative-pg/postgresql`,
  `wasabi: {region: "", endpoint: ""}` requis par `required` quand le Job est rendu). Ne rien déplacer ni renommer des sections existantes de `values.yaml`.
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff` vert ; `make helm-lint` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 4 : Documentation « Restauration et copie »

**Fichiers :**
- Modifier : `docs/v1/infra/kubernetes.md` (nouvelle section « Restauration et copie » ; remplacement de la puce obsolète, Points de revue 6)

**Interfaces :**
- Consomme : le rendu final des trois Jobs (noms, conditions, journaux, libellés des pods).
- Produit : la description à jour pour le lot 5 (script) et les relecteurs.

- [ ] **Étape 1** : rédiger la section (français, avec accents) : les trois Jobs, leur condition de rendu, le rendu à la demande par
  `helm template --show-only` (commande type avec `--set restauration.prefixe=…`), le déroulé interne de chacun, la remise à zéro du
  schéma et son contrôle de propriété, l'absence de purge, le dépôt Wasabi conservé, la règle « préfixe accepté », la règle
  « export refusé hors prod », le libellé de composant réutilisé pour les NetworkPolicies, les valeurs exposées, les écarts au contrat
  (`copierFichiers` supprimé, `wasabi.region` requis par l'export : le script doit passer `--set wasabi.region=…` au rendu), le calcul
  du quota (les Jobs tournent application arrêtée ; plus gros conteneur 256 Mi).
- [ ] **Étape 2** : remplacer la puce « Job de restauration d'une sauvegarde déposée » de « PostgreSQL, version et restauration » par un renvoi.
- [ ] **Étape 3** : cocher l'Avancement ; commit d'une ligne (`docs: restauration et copie anonymisee`).

---

### Tâche 5 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make helm-controle` (lint, helm-unittest des deux charts, garde, kubeconform prod et preprod) : vert. `make lint`,
  `make typecheck`, `make coverage-diff`, `make check-generated`, `make migrations-check` : sans objet (aucun Python ni migration) ;
  le noter dans le rapport.
- [ ] **Rendu avec les Jobs activés** (par défaut absents, donc non vus par `controle.rb` et kubeconform) : relancer
  `make helm-transverses HELM_SET='--set reseau.apiKubernetes.cidr=192.0.2.10/32 --set image.etiquette=0.0.0-test --set wasabi.region=eu-central-2 --set wasabi.bucket=urbankiff-test --set secretsChecksum=test --set restauration.prefixe=restauration/2026-12-01/ --set apresRestauration.actif=true'`
  puis `make helm-valider ENV=prod CHART=urbankiff HELM_SET='<mêmes valeurs> --set exportAnonyme.prefixe=restauration/2026-11-17-prod-anonyme/ --set exportAnonyme.bucketCible=bucket-preprod-test'`
  (et `ENV=preprod` pour les deux autres Jobs, `CHART=urbankiff-donnees` pour la restauration). Attendu : contrôles transverses OK, quota
  inchangé (plus gros conteneur 256 Mi), kubeconform sans erreur. **Tout dépassement du quota est signalé, pas contourné.**
- [ ] Vérifier à la main dans le rendu que `urbankiff-export-anonyme` ne référence `urbankiff-pg-app` que dans `dump-source`
  et les clés `WASABI_*` que dans `deposer`.
- [ ] Périmètre : `make devteam-perimetre LOT=4 PLAN=docs/v1/plans/outils-donnees/4-jobs-donnees.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler (dont ce qui ne
  se vérifie que sur le cluster réel après la PR finale : `initdb` en UID 26 avec système de fichiers en lecture seule, remise à zéro du
  schéma par l'utilisateur applicatif de CloudNativePG).
