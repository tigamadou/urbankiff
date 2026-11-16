# Charts Helm urbankiff-donnees et urbankiff — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A1 (pas de Secret ghcr-pull, valeur facultative image.secretTirage), A2 (label app.kubernetes.io/part-of: urbankiff, Cluster urbankiff-pg, Ingress urbankiff-api), A3 (identifiants PostgreSQL depuis le Secret urbankiff-pg-app généré par CloudNativePG), A4 (REDIS_ENDPOINT et MINIO_ENDPOINT construits), A5 (envFrom du Secret urbankiff-secrets et de la ConfigMap urbankiff-config ; wasabi.region et wasabi.bucket en valeurs), A6 (TWILIO_* inertes si sms.actif faux), A7, A9 (ni namespace ni quota dans le chart ; test : somme des limites preprod sous 2 Gio — le test attendu en échec disparaît), A10, A11, A13.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir les deux charts Helm du déploiement k3s (`urbankiff-donnees`, `urbankiff`), leurs valeurs
`prod` et `preprod`, les NetworkPolicies, quotas et durcissement, l'outillage `make helm-*` et les tests de rendu qui
prouvent les garanties de sécurité, sans rien déployer.

**Architecture** : deux charts indépendants à déployer dans cet ordre dans chaque namespace (`prod`, `preprod`).
`urbankiff-donnees` porte l'état (CloudNativePG, Redis, RustFS, sauvegardes, restauration), le refus réseau par défaut
et le quota ; `urbankiff` porte les applications (api, workers, Next, panel, migrations, Ingress). Les deux lisent le
Secret `urbankiff-secrets` créé avant eux par le script de déploiement. Les flux réseau sont décrits des deux côtés
(sortie de l'émetteur, entrée du destinataire) à partir de libellés communs (voir « Libellés » plus bas).

**Stack** : Helm 3, CloudNativePG + plugin Barman Cloud, cert-manager (annotation d'Ingress), Traefik (k3s), Redis,
RustFS, rclone, helm-unittest, kubeconform ; tout en conteneurs épinglés lancés par `make`.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité). Plan de
la mission `k3s-ansible`, lot 6 (`charts`) sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/k3s-ansible-charts` · **Base** : `feature/k3s-ansible` · **Profil** : `api`
- **Dépendances** : `socle` (inclusion automatique de `make/*.mk` par le `Makefile`) (lots qui doivent être fusionnés dans
  la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ✅ terminé (tâches 1 à 10)

- [x] **Tâche 1** Outillage `make helm-*` et squelette des tests · `feature/k3s-ansible-charts`
  - [x] `make/helm.mk` (lint, rendu, valider, test, paquet, schémas) avec images épinglées
  - [x] schémas CRD versionnés (CloudNativePG, Barman Cloud, cert-manager) dans `infra/helm/schemas/`
  - [x] test-garde de rendu qui échoue tant qu'aucun chart n'existe
- [x] **Tâche 2** Chart `urbankiff-donnees` : socle (helpers, valeurs, refus par défaut, quota, DNS)
- [x] **Tâche 3** `urbankiff-donnees` : cluster PostgreSQL, archivage WAL, sauvegarde quotidienne, restauration à un instant
- [x] **Tâche 4** `urbankiff-donnees` : Redis authentifié, RustFS et Job de bucket
- [x] **Tâche 5** `urbankiff-donnees` : CronJob rclone, Job de restauration, NetworkPolicies des données
- [x] **Tâche 6** Chart `urbankiff` : socle, api, workers, Job de migrations
- [x] **Tâche 7** `urbankiff` : Next, panel, Ingress, NetworkPolicies des applications
- [x] **Tâche 8** Valeurs `prod` et `preprod` et tests transverses (isolement, limites, durcissement, SMS)
- [x] **Tâche 9** Documentation `docs/v1/infra/kubernetes.md`
- [x] **Tâche 10** Vérification du lot

> Reprise : (vide). Écarts : quota de 2 Gio (A9, plus de test attendu en échec) ; sortie du Job de migrations placée dans urbankiff-donnees (crochet pre-install).

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/helm/**` [nouveau] : charts, valeurs, tests helm-unittest, schémas de validation
- `make/helm.mk` [nouveau]
- `docs/v1/infra/kubernetes.md` [nouveau]
- `docs/v1/plans/k3s-ansible/6-charts.md` (ce plan : Avancement)

## Fichiers en lecture seule

- `docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 5.1, 5.3, 5.4, 5.6, 5.10, 5.11, 8.3), `docs/v1/infra/secrets.md`,
  `docs/v1/infra/rotation-secrets.md`.
- `Makefile`, `.gitignore` (lot `socle`), `make/devteam.mk`, `make/standard.mk`, `make/secrets.mk`.
- `apps/api/project/settings.py` (variables lues par l'api ; lecture seule, modifié par `nettoyage`), `apps/api/Dockerfile`
  (lot `api-prod`), `apps/nextjs/Dockerfile`, `apps/panel/Dockerfile` (lot `fronts-prod`).
- `infra/ansible/**` (ne pas l'écrire : nom du ClusterIssuer, namespace de la plateforme), `infra/deploiement/**`,
  `infra/restauration/**`.
- Référence hors dépôt, lecture seule : `/Users/amadou/Devs/projects/steamy/infra/helm/` (reprendre la structure, **pas ses
  défauts** : pas de NetworkPolicy, Redis sans mot de passe, pas de `readOnlyRootFilesystem`).

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par `make` (sur l'hôte
seulement `docker`, `make`, `git`, `gh`) ; aucun mock de la base ni de l'ORM (sans objet ici : rien de Django) ; ne
jamais modifier le code de production pour faire passer un test (s'arrêter et le signaler) ; pas de `retry` ni de
contournement pour masquer une instabilité ; aucune valeur de secret dans le dépôt (`make secrets-scan` à zéro).
`make lint`/`make typecheck`/`make coverage-diff` ne couvrent pas les charts : le lot se vérifie par `helm-lint`,
`helm-test`, `helm-valider` (voir tâche 10) ; la couverture de 100 % se lit ici comme « chaque garantie du § 5.3 et 5.4
a un test de rendu ».

Contraintes propres au lot :

1. **Contrats 8.3 « Charts » exacts** : noms `urbankiff-donnees` et `urbankiff` (OCI
   `oci://ghcr.io/tigamadou/charts/<nom>`) ; namespaces `prod`/`preprod` ; Secret applicatif `urbankiff-secrets` (clés =
   noms de l'inventaire) ; Secret de lecture `ghcr-pull` ; valeurs `image.etiquette`, `secretsChecksum`,
   `environnement`, `sms.actif`, `restauration.active`, `restauration.prefixe` ; services `urbankiff-api:8000`,
   `urbankiff-nextjs:3000`, `urbankiff-panel:8080` ; hibernation par l'annotation `cnpg.io/hibernation` (le chart ne la
   pose pas : le script de déploiement la bascule ; un `helm upgrade` ne doit pas la défaire, donc jamais écrite dans un
   template sauf valeur explicite `postgres.hibernation`, absente par défaut).
2. **Contrats amont** : api sur 8000, utilisateur 10001, écritures dans `/tmp`, santé `GET /api/health/`, commandes
   workers et migrations exactement celles du contrat ; Next 3000, UID 10001, écritures `/tmp` et `/app/.next/cache` ;
   panel 8080, UID 10001, écritures `/tmp` ; images `ghcr.io/tigamadou/urbankiff-{api,nextjs,panel}` avec étiquettes
   `<version>` (api) et `<version>-<env>` (Next, panel) : valeur `image.etiquette` = la version, le suffixe
   `-<environnement>` est ajouté par le chart pour Next et panel.
3. **Aucun secret dans le dépôt, les valeurs ni les arguments** : tout via `secretKeyRef` ; aucun `value:` pour une clé
   de l'inventaire des secrets ; mots de passe jamais en ligne de commande (fichier de configuration écrit dans
   `/tmp` au démarrage pour Redis).
4. **Durcissement de tout pod rendu**, y compris Jobs, CronJobs et StatefulSets : `runAsNonRoot`, UID explicite non nul,
   `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`,
   `readOnlyRootFilesystem: true` avec `emptyDir` là où on écrit, sondes `readiness` et `liveness` sur les services
   durables, `requests` et `limits` mémoire sur **chaque conteneur** (init compris) ; `automountServiceAccountToken:
   false` sauf pour les pods qui parlent à l'API Kubernetes (PostgreSQL géré par CloudNativePG).
5. Le cluster PostgreSQL CloudNativePG est piloté par l'opérateur : son durcissement se règle dans la spec du `Cluster`
   (`securityContext`, `podSecurityContext`, `resources`), le test vérifie ces champs, et la limite de ce que
   l'opérateur impose est documentée.
6. Versions épinglées (images, helm, kubeconform, helm-unittest, PostgreSQL, rclone) lues dans `values.yaml` ou dans
   `make/helm.mk`, une seule fois chacune.
7. Documentation en français avec accents ; code, identifiants de chart et clés Helm sont ceux du contrat (français sans
   accent : `etiquette`, `restauration`).

### Libellés communs (interface interne aux deux charts)

Tous les pods portent `app.kubernetes.io/part-of: urbankiff` et `app.kubernetes.io/component` parmi : `api`, `workers`,
`nextjs`, `panel`, `migrations`, `redis`, `rustfs`, `rustfs-bucket`, `sauvegarde-fichiers`, `restauration`. Les pods
PostgreSQL portent `cnpg.io/cluster: urbankiff-pg` (posé par l'opérateur). Les NetworkPolicies ne s'appuient **que** sur
ces libellés et sur `podSelector` (même namespace) ; la seule `namespaceSelector` autorisée vise `kube-system`
(Traefik, CoreDNS) et le namespace de la plateforme (opérateur CloudNativePG). Nom du namespace de la plateforme :
valeur `reseau.namespacePlateforme` (défaut `plateforme`, § 5.1). Cluster PostgreSQL : `urbankiff-pg`, services
`urbankiff-pg-rw` ; Redis : `urbankiff-redis:6379` ; RustFS : `urbankiff-rustfs:9000`.

## Points de revue

1. Aucune politique ni règle (`namespaceSelector`, `ipBlock`) n'ouvre `prod` ↔ `preprod` : les sorties Internet
   excluent les plages du pod et du service k3s (valeur `reseau.cidrExclus`) ; test de rendu dédié.
2. Chaque pod rendu (y compris Jobs, init-conteneurs, hooks) a limites mémoire et `securityContext` conforme ; le test
   énumère tous les gabarits, pas seulement les Deployments.
3. Preprod : aucune variable ni Secret Twilio réel, `sms.actif: false` ; or `apps/api/apps/twilio/views.py` lit
   `os.environ['TWILIO_ACCOUNT_SID']` à l'import : la preprod doit fournir des valeurs inertes pour que l'api démarre
   (voir tâche 6).
4. Somme des limites mémoire de la preprod (api 384 + workers 256 + Next 384 + panel 64 + PostgreSQL 384 + Redis 64 +
   RustFS 192 = **1 728 Mi**) supérieure au quota de 1,5 Go (1 536 Mi) du § 5.4, sans compter le Job de migrations et le
   CronJob : conflit de la spec, voir tâche 8 (ne pas le masquer).
5. `REDIS_ENDPOINT` construit à partir de `REDIS_PASSWORD` sans jamais être une valeur du dépôt.
6. Annotation de checksum sur chaque Deployment et StatefulSet qui lit un secret ; `helm upgrade` d'un pod sans
   changement de secret ne redémarre rien.
7. Hooks de migration `pre-install,pre-upgrade` avec `hook-delete-policy: before-hook-creation,hook-succeeded` ;
   NetworkPolicies et Secrets nécessaires à ce Job existent **avant** lui (les politiques sont dans le chart des
   données, déployé avant).
8. Restauration future : le Job `restauration.active` est absent par défaut, ne s'exécute que sur demande et ne contient
   aucun secret en dur (§ 5.10).

---

### Tâche 1 : Outillage `make helm-*` et schémas

**Fichiers :**
- Créer : `make/helm.mk`, `infra/helm/schemas/` (schémas JSON des CRD `postgresql.cnpg.io` Cluster et ScheduledBackup,
  `barmancloud.cnpg.io` ObjectStore, `cert-manager.io` ; **versionnés dans le dépôt**, jamais téléchargés à la
  validation), `infra/helm/README.md` court (comment régénérer les schémas), `infra/helm/tests-garde/` (voir étape 1).
- Test : `infra/helm/tests-garde/` ; la forme du test d'outillage est laissée au constructeur (script `sh` exécuté en
  conteneur ou test helm-unittest).

**Interfaces :**
- Consomme : contrat « Inclusion make » (socle) ; versions épinglées choisies ici.
- Produit : cibles `helm-lint`, `helm-rendu ENV=<prod|preprod> [CHART=<nom>]`, `helm-valider ENV=…` (rendu puis
  kubeconform, `-strict`, `-ignore-missing-schemas` **interdit**, schémas locaux + schéma Kubernetes), `helm-test`
  (helm-unittest), `helm-paquet VERSION=…` (`helm package` vers `.superpowers/` ou un dossier ignoré ; la publication OCI
  appartient au lot `deploiement`), `helm-schemas` (régénère les schémas, seul chemin avec accès réseau, documenté).
  Tous les `docker run` montent le dépôt en lecture seule sauf le dossier de sortie.

- [x] **Étape 1** : écrire d'abord un test-garde : `make helm-lint` et `make helm-test` échouent proprement si
  `infra/helm/urbankiff*` est absent, et `make helm-rendu` sans `ENV` affiche le message d'usage (code 2, même style que
  `make/secrets.mk`). Le voir échouer.
- [x] **Étape 2** : récupérer et versionner les schémas CRD aux versions de l'opérateur et du plugin épinglées dans
  `infra/helm/README.md` (cette seule étape utilise le réseau, via `make helm-schemas`). Si un schéma manque (CRD sans
  schéma publié), le signaler.
- [x] **Étape 3** : implémenter `make/helm.mk` (`.PHONY`, `##` d'aide, variables d'images épinglées en tête).
- [x] **Étape 4** : relancer, vert ; vérifier que `make help` (si présent) liste les cibles ; cocher ; commit
  (`chore: outillage make helm`).

---

### Tâche 2 : `urbankiff-donnees` socle

**Fichiers :**
- Créer : `infra/helm/urbankiff-donnees/Chart.yaml`, `values.yaml`, `templates/_helpers.tpl`,
  `templates/reseau-defaut.yaml` (refus par défaut entrée et sortie, ouverture DNS vers `kube-system`/CoreDNS port 53
  UDP+TCP pour tous les pods), `templates/quota.yaml` (ResourceQuota conditionné par `quota.actif`).
- Test : `infra/helm/urbankiff-donnees/tests/socle_test.yaml`.

**Interfaces :**
- Consomme : `environnement`, `reseau.*`, `quota.limitesMemoire`.
- Produit : valeurs communes (`environnement`, `image` pour rclone et le client PostgreSQL, `secretName:
  urbankiff-secrets`, `secretsChecksum`, `wasabi.{region,endpoint,bucket,prefixeBase}`, `reseau.cidrExclus`,
  `reseau.namespacePlateforme`, `reseau.apiKubernetes` pour PostgreSQL, `quota`) ; helpers `urbankiff.labels`,
  `urbankiff.securityContextPod`, `urbankiff.securityContextConteneur` réutilisés par toutes les tâches du chart.

- [x] **Étape 1** : tests : `environnement` hors `prod|preprod` fait échouer le rendu (`fail`) ; une NetworkPolicy
  `default-deny` (Ingress et Egress, `podSelector: {}`) est rendue ; le quota n'existe que si `quota.actif`.
- [x] **Étape 2** : implémenter ; `helm-lint` et `helm-test` verts ; cocher ; commit.

---

### Tâche 3 : cluster PostgreSQL, WAL, sauvegarde, restauration à un instant

**Fichiers :**
- Créer : `templates/postgres-cluster.yaml` (`Cluster` `urbankiff-pg`, une instance, `local-path`, image
  `ghcr.io/cloudnative-pg/postgresql:<postgres.version>`), `templates/postgres-objectstore.yaml` (`ObjectStore`
  Barman Cloud vers Wasabi, endpoint régional, `retentionPolicy: 30d`, compression, chiffrement côté serveur si le plugin
  l'accepte), `templates/postgres-sauvegarde.yaml` (`ScheduledBackup` quotidien, méthode `plugin`).
- Test : `tests/postgres_test.yaml`.

**Interfaces :**
- Consomme : `postgres.version` (**valeur configurable**, défaut 15 ; l'exécutant la vérifie contre l'en-tête du dump à
  restaurer, § 5.11 : alignée ou supérieure, jamais inférieure ; le test refuse une version < 15), `wasabi.*`,
  Secret `urbankiff-secrets` (clés `WASABI_ACCESS_KEY_ID`, `WASABI_SECRET_ACCESS_KEY`, lues par `secretKeyRef` avec
  les noms de clés attendus par Barman).
- Produit : base `postgres.base` (variable `POSTGRES_DB`), propriétaire `postgres.utilisateur` (`POSTGRES_USER`), Secret
  généré par CloudNativePG `urbankiff-pg-app` (clés `username`, `password`, `host`, `dbname`) **consommé par le chart
  `urbankiff`** pour `POSTGRES_PASSWORD` : le script de déploiement ne crée pas de Secret `basic-auth` et un chart ne peut
  pas lire `urbankiff-secrets` au rendu sans `lookup`. `POSTGRES_PASSWORD` de l'inventaire n'est donc pas lu ; **à
  signaler** (lots `deploiement` et `nettoyage`), ne pas le contourner par `lookup`. Service d'écriture
  `urbankiff-pg-rw:5432`. Valeur `postgres.restauration` : `{ actif, instant, serveurSource }` ; rendue en
  `bootstrap.recovery` avec `recoveryTarget.targetTime` et `externalClusters` (plugin Barman), jamais active par défaut.

- [x] **Étape 1** : tests : sans `restauration`, bootstrap `initdb` avec la base et le propriétaire des valeurs ;
  archivage WAL (`isWALArchiver: true`) ; planification quotidienne ; rétention 30 jours ; ressources de la table
  § 5.4 par environnement (lues dans les valeurs, testées en tâche 8) ; `securityContext` du `Cluster` conforme ;
  avec `postgres.restauration.actif` : `bootstrap.recovery` présent avec `targetTime` ; `version < 15` : échec ;
  annotation `cnpg.io/hibernation` absente par défaut, présente avec `postgres.hibernation: "on"`.
- [x] **Étape 2** : implémenter ; `helm-lint`, `helm-test` ; `helm-valider ENV=preprod` valide `Cluster`,
  `ObjectStore`, `ScheduledBackup` avec les schémas de la tâche 1 ; cocher ; commit.

---

### Tâche 4 : Redis authentifié, RustFS, Job de bucket

**Fichiers :**
- Créer : `templates/redis.yaml` (StatefulSet + Service `urbankiff-redis`, AOF `appendonly yes`, volume de données,
  configuration `requirepass` écrite dans `/tmp/redis.conf` depuis `REDIS_PASSWORD` au démarrage ; sondes via
  `REDISCLI_AUTH`, jamais le mot de passe en argument), `templates/rustfs.yaml` (StatefulSet + Service
  `urbankiff-rustfs:9000`, console désactivée, identifiants `RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY` depuis
  `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`, image `rustfs/rustfs` épinglée comme le Compose local, `/data` en volume),
  `templates/rustfs-bucket-job.yaml` (Job de création idempotente du bucket `MINIO_DEFAULT_BUCKETS`, client `mc` ou
  `rclone` épinglé, hook `post-install,post-upgrade` ou Job rejouable, limites).
- Test : `tests/redis_test.yaml`, `tests/rustfs_test.yaml`.

**Interfaces :**
- Consomme : `redis.*`, `rustfs.*` (taille de volume, image), `secretsChecksum` (annotation de pod), table de limites §
  5.4.
- Produit : services ci-dessus ; checksum sur les deux StatefulSets ; bucket `rustfs.bucket` (valeur
  `MINIO_DEFAULT_BUCKETS` côté application).

- [x] **Étape 1** : tests : le mot de passe n'apparaît dans aucun `args`/`command` (seulement `secretKeyRef`) ; `requirepass`
  présent ; `appendonly yes` ; `readOnlyRootFilesystem` avec `emptyDir` sur `/tmp` ; volumes `/data` ; limites ;
  annotation de checksum ; Job du bucket avec limites et `securityContext`.
- [x] **Étape 2** : implémenter ; `helm-lint`, `helm-test`, `helm-valider ENV=preprod` ; cocher ; commit.

---

### Tâche 5 : CronJob rclone, Job de restauration, NetworkPolicies des données

**Fichiers :**
- Créer : `templates/sauvegarde-fichiers.yaml` (CronJob `sauvegarde-fichiers`, rclone épinglé : source RustFS en S3,
  destination Wasabi sous `fichiers/`, `concurrencyPolicy: Forbid`, historique de Jobs limité, configuration rclone
  par variables d'environnement `RCLONE_CONFIG_*` depuis les Secrets, aucune écriture de clé dans le dépôt),
  `templates/restauration-job.yaml` (rendu **seulement si** `restauration.active`), `templates/reseau-donnees.yaml`.
- Test : `tests/sauvegarde_test.yaml`, `tests/restauration_test.yaml`, `tests/reseau_donnees_test.yaml`.

**Interfaces :**
- Consomme : contrat « Restauration » : sauvegarde déposée sous `restauration/<date>/` du bucket Wasabi ; Job qui appelle
  `pg_restore --no-owner --no-privileges --schema=public`. Valeurs `restauration.active` (faux), `restauration.prefixe`
  (obligatoire si actif, `required`), `restauration.fichierDump` (défaut `base.dump`, format custom), `restauration.
  copierFichiers` (défaut vrai : les objets du préfixe `fichiers/` repartent dans RustFS), `restauration.purger` (défaut
  vrai : le préfixe temporaire est supprimé de Wasabi à la fin).
- Produit : un Job non-hook (`urbankiff-restauration`), en trois temps : init-conteneur rclone (récupère le préfixe de
  Wasabi), init-conteneur `pg_restore` (image PostgreSQL de `postgres.version`, mot de passe depuis `urbankiff-pg-app`),
  conteneur rclone (copie vers RustFS, puis purge). **À signaler au lot `restauration`** : nom du fichier de dump et
  structure du préfixe (`base.dump`, `fichiers/`) à aligner avec `infra/restauration/` et
  `docs/v1/infra/premier-deploiement-prod.md` ; le contrat 8.3 ne fixe que le préfixe `restauration/<date>/`.
  NetworkPolicies : entrée de PostgreSQL depuis api, workers, migrations, restauration, et depuis l'opérateur du
  namespace de la plateforme (ports 5432 et 8000) ; entrée de Redis (6379) depuis api, workers, migrations ; entrée de
  RustFS (9000) depuis api, workers, migrations, `rustfs-bucket`, `sauvegarde-fichiers`, `restauration` et **Next**
  seulement si le rendu serveur l'exige (à vérifier ; sinon refusé) ; sortie de PostgreSQL : 53, 443 (Wasabi, plages
  privées exclues par `reseau.cidrExclus`), et le port de l'API Kubernetes (`reseau.apiKubernetes`, 6443 vers l'IP du
  nœud) ; sortie de `sauvegarde-fichiers` et `restauration` : RustFS, 443 Wasabi, 53.

- [x] **Étape 1** : tests : CronJob rendu avec limites et `securityContext` ; absence de Job de restauration par
  défaut ; avec `restauration.active` sans `prefixe` → échec ; avec `active` et préfixe → Job avec `pg_restore
  --no-owner --no-privileges --schema=public` ; aucun secret en argument ; aucune politique du chart ne contient une
  `namespaceSelector` autre que `kube-system` et `reseau.namespacePlateforme` ; aucune `ipBlock` n'omet `cidrExclus` ;
  chaque flux listé ci-dessus a sa politique, rien de plus (test par liste exhaustive des politiques et de leurs ports).
- [x] **Étape 2** : implémenter ; `helm-lint`, `helm-test`, `helm-valider ENV=preprod` ; cocher ; commit.

---

### Tâche 6 : chart `urbankiff` : socle, api, workers, migrations

**Fichiers :**
- Créer : `infra/helm/urbankiff/Chart.yaml`, `values.yaml`, `templates/_helpers.tpl`, `templates/configmap.yaml`
  (variables **non secrètes** de l'inventaire : `DJANGO_ENV`, `ALLOWED_HOSTS`, `WEB_URL`, `API_URL`, `SMTP_SERVER`,
  `SMTP_PORT`, `MINIO_ENDPOINT` = `urbankiff-rustfs:9000`, `MINIO_DEFAULT_BUCKETS`, `FILES_CDN_ENDPOINT`,
  `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_HOST` = `urbankiff-pg-rw`), `templates/api.yaml`, `templates/workers.yaml`,
  `templates/migrations-job.yaml`.
- Test : `tests/api_test.yaml`, `tests/workers_test.yaml`, `tests/migrations_test.yaml`.

**Interfaces :**
- Consomme : image `ghcr.io/tigamadou/urbankiff-api:<image.etiquette>` (contrat api-prod) ; `ghcr-pull` en
  `imagePullSecrets` ; Secret `urbankiff-secrets` ; Secret `urbankiff-pg-app` (tâche 3) ; lecture de
  `apps/api/project/settings.py` pour la liste exacte des variables lues et les valeurs de `DJANGO_ENV` (`DEV`,
  production) : ne rien inventer, le constater.
- Produit : Deployments `urbankiff-api` (service `urbankiff-api:8000`, gunicorn déjà dans la commande de l'image,
  sondes `httpGet /api/health/` **avec en-tête `Host` valant le nom d'hôte public de l'api**, sinon Django refuse
  l'IP du pod via `ALLOWED_HOSTS`) et `urbankiff-workers` (commande du contrat) ; Job de migrations hook
  `pre-install,pre-upgrade` (commande du contrat exacte, même environnement que l'api) ; variables secrètes par
  `secretKeyRef` ; `REDIS_ENDPOINT` = `redis://:$(REDIS_PASSWORD)@urbankiff-redis:6379/0`, `REDIS_PASSWORD` déclaré
  **avant** `REDIS_ENDPOINT` dans `env` (dépendance d'expansion Kubernetes) ; `POSTGRES_PASSWORD` depuis
  `urbankiff-pg-app`/`password`. `sms.actif` : si vrai, `TWILIO_ACCOUNT_SID` et `TWILIO_AUTH_TOKEN` viennent du Secret ;
  si faux (preprod), valeurs inertes littérales (`desactive`) car l'api lit ces variables à l'import ; le contrat reste
  `sms.actif` (**à signaler** : seule la variable d'environnement est neutralisée, pas le code). Annotation
  `urbankiff.com/secrets-checksum: {{ .Values.secretsChecksum }}` sur les gabarits de pods de l'api et des workers.

- [x] **Étape 1** : tests : image et étiquette ; commande du Job de migrations identique au contrat ; hook et
  `hook-delete-policy` ; commande des workers ; `REDIS_ENDPOINT` construit et ordre des variables ; aucune clé secrète
  de l'inventaire en `value:` ; `sms.actif: false` neutralise Twilio, `true` l'expose par `secretKeyRef` ; checksum ;
  sondes avec en-tête `Host` ; limites et `securityContext` ; `emptyDir` sur `/tmp`.
- [x] **Étape 2** : implémenter ; `helm-lint`, `helm-test` ; cocher ; commit.

---

### Tâche 7 : Next, panel, Ingress, NetworkPolicies des applications

**Fichiers :**
- Créer : `templates/nextjs.yaml`, `templates/panel.yaml`, `templates/ingress.yaml`, `templates/reseau.yaml`.
- Test : `tests/nextjs_test.yaml`, `tests/panel_test.yaml`, `tests/ingress_test.yaml`, `tests/reseau_test.yaml`.

**Interfaces :**
- Consomme : images `…-nextjs:<image.etiquette>-<environnement>` et `…-panel:<…>-<environnement>` ; ports 3000 et 8080 ;
  `emptyDir` sur `/tmp` et, pour Next, `/app/.next/cache`.
- Produit : Deployments et Services `urbankiff-nextjs:3000`, `urbankiff-panel:8080` ; Ingress Traefik
  (`ingressClassName: traefik`, annotation `cert-manager.io/cluster-issuer: <ingress.clusterIssuer>`, défaut
  `letsencrypt` : **à aligner avec le ClusterIssuer du lot `ansible`**, nom non fixé par le contrat 8.3 ; à signaler)
  pour les trois hôtes (`hosts.web`, `hosts.api`, `hosts.panel`) avec un Secret TLS par hôte ; aucun hôte de stockage.
  NetworkPolicies : entrée api (8000), Next (3000), panel (8080) depuis Traefik de `kube-system` seulement, plus l'entrée
  de l'api depuis Next ; **entrée de Traefik vers les pods solveurs HTTP-01 de cert-manager** (libellé
  `acme.cert-manager.io/http01-solver: "true"`, port 8089) sinon le certificat n'est jamais émis ; sorties : api, workers
  et migrations → PostgreSQL 5432, Redis 6379, RustFS 9000, plus Internet 53, 443, 465 et 587 hors `cidrExclus` ; Next →
  api seulement (et Redis/RustFS si le code Next les appelle : vérifier dans `apps/nextjs`, sinon refusé) ; panel :
  aucune sortie (statique) ; workers : entrées aucune.

- [x] **Étape 1** : tests : trois hôtes et trois Secrets TLS ; aucun hôte `s3*` ; étiquette des fronts suffixée par
  l'environnement ; chaque flux du § 5.3 existe et rien d'autre (liste exhaustive) ; Next sans règle de sortie
  Internet ; panel sans sortie ; entrée du solveur HTTP-01 ; limites et `securityContext` ; checksum sur Next.
- [x] **Étape 2** : implémenter ; `helm-lint`, `helm-test`, `helm-valider ENV=preprod` ; cocher ; commit.

---

### Tâche 8 : valeurs `prod` et `preprod`, tests transverses

**Fichiers :**
- Créer : `infra/helm/urbankiff-donnees/values-prod.yaml`, `values-preprod.yaml`, `infra/helm/urbankiff/values-prod.yaml`,
  `values-preprod.yaml` ; `infra/helm/tests-transverses/` (tests exécutés par `make helm-test`, forme au choix :
  script de contrôle sur le rendu des deux charts pour les deux environnements, en conteneur).
- Valeurs : limites exactes du tableau § 5.4 (prod et preprod) ; `environnement`, hôtes (`urbankiff.com`,
  `api.urbankiff.com`, `panel.urbankiff.com` / préfixe `preprod.`), `sms.actif` (vrai en prod, **faux en preprod**),
  `quota.actif` seulement en preprod ; `wasabi.region` et `wasabi.bucket` obligatoires (`required`, valeurs fournies au
  déploiement, car variables GitHub non transmises par le script à ce jour : **à signaler** au lot `deploiement`).

**Interfaces :**
- Consomme : tout ce qui précède.
- Produit : le contrôle d'ensemble suivant, qui doit échouer si une garantie disparaît.

- [x] **Étape 1** : écrire les tests transverses, sur les quatre combinaisons (2 charts × `prod`/`preprod`) :
  1. aucun document NetworkPolicy ne référence l'autre environnement ni une `namespaceSelector` hors `kube-system` et
     plateforme ; toutes les `ipBlock` excluent les plages pod et service (`prod` ↔ `preprod` fermé) ;
  2. tout pod (Deployment, StatefulSet, Job, CronJob, `Cluster` CloudNativePG) a `requests` et `limits.memory` sur tous
     ses conteneurs et le `securityContext` durci complet ;
  3. preprod : `sms.actif` faux, aucune référence aux clés `TWILIO_*` du Secret ; prod : les deux clés référencées ;
  4. valeurs prod rendues sans erreur et validées par kubeconform (`make helm-valider ENV=prod`) ;
  5. aucun document `Secret` contenant une valeur ; aucun `value:` d'une clé de l'inventaire des secrets ;
  6. **somme des limites mémoire de la preprod en régime établi** comparée à `quota.limitesMemoire`.
- [x] **Étape 2** : constater le test 6. Avec la table du § 5.4 la somme est **1 728 Mi** pour un quota de **1 536 Mi** et le
  Job de migrations (rendu sous quota) n'a aucune marge : **s'arrêter et le signaler dans l'issue** (décision du
  développeur : relever le quota, diminuer des limites, ou exclure les Jobs). Ne pas modifier les limites de la spec ni
  le quota de sa propre initiative. En attendant la décision, laisser `quota.limitesMemoire: 1536Mi` (valeur de la spec)
  avec le test 6 marqué attendu en échec **et documenté**, jamais supprimé.
- [x] **Étape 3** : implémenter les valeurs ; `make helm-rendu ENV=prod` et `ENV=preprod` sans erreur ; tout vert sauf le
  point 6 documenté ; cocher ; commit.

---

### Tâche 9 : documentation `docs/v1/infra/kubernetes.md`

**Fichiers :**
- Créer : `docs/v1/infra/kubernetes.md`.

Contenu : rôle de chaque chart ; ordre de déploiement ; table des libellés ; tableau de toutes les NetworkPolicies
(source → destination, port) et du principe « sortie par port, pas par nom » (§ 5.3) ; limites et quota (table § 5.4,
conflit des 1,5 Go et sa décision) ; durcissement et limites imposées par CloudNativePG ; variables et Secrets
consommés (clé par clé, sans valeur), Secret `urbankiff-pg-app` ; hibernation preprod (annotation, effet, par qui) ;
`postgres.version` et règle de version (§ 5.11) ; restauration à un instant et Job `restauration.active` (valeurs,
préfixe, ce qui est purgé) ; utilisation des cibles `make helm-*` ; points laissés aux lots voisins (ClusterIssuer,
variables Wasabi, nom du fichier de dump).

- [x] Relire le document contre les chartes rendues (`make helm-rendu ENV=preprod`) : tout nom cité existe.
- [x] Cocher ; commit (`docs: kubernetes.md`).

---

### Tâche 10 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [x] `make helm-lint` vert (les deux charts, valeurs par défaut, `prod` et `preprod`).
- [x] `make helm-test` vert (helm-unittest et tests transverses), point 6 de la tâche 8 documenté ou levé par décision.
- [x] `make helm-rendu ENV=prod` et `make helm-rendu ENV=preprod` sans erreur ; `make helm-valider ENV=prod` et
  `ENV=preprod` (kubeconform strict, schémas CRD CloudNativePG, Barman Cloud et cert-manager) verts.
- [x] `make secrets-scan` à zéro (aucun secret dans le dépôt).
- [x] `make lint`, `make typecheck`, `make coverage-diff`, `make check-generated`, `make migrations-check` : sans objet pour
  ce lot (aucun code applicatif touché), le noter dans le rapport ; e2e : sans objet.
- [x] Périmètre : `make devteam-perimetre LOT=charts PLAN=docs/v1/plans/k3s-ansible/6-charts.md
  BASE=origin/feature/k3s-ansible` ; attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée,
  jamais le plan modifié pour la faire disparaître).
- [x] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler (liste
  de la tâche 9 + conflit de quota + `POSTGRES_PASSWORD` non lu + `sms.actif` neutralise la variable seulement).
