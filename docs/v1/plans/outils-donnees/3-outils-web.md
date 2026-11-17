> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d'écart) : B5, B6, B9.

# Outils web (pgAdmin et console RustFS) — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : exposer en HTTPS, sur des sous-domaines (`db`, `stockage`), pgAdmin 4 préconfiguré sur la base
`urbankiff-pg` et la console de RustFS, dans les deux environnements, sans pod de plus pour la console, en tenant dans
le quota de la preprod.

**Architecture** : tout vit dans le chart `urbankiff-donnees`. Un Deployment `urbankiff-pgadmin` (composant `pgadmin`,
libellé `part-of: urbankiff`) avec une ConfigMap `servers.json` ; la console s'active sur le StatefulSet `urbankiff-rustfs`
existant (port 9001, Service enrichi). Un Ingress par outil (cert-manager, classe Traefik) porte deux Middlewares
Traefik (limitation de débit, en-têtes HSTS) via l'annotation `router.middlewares`. NetworkPolicies ajoutées dans un
fichier à part (`reseau-outils.yaml`) : les politiques existantes de `reseau-donnees.yaml` (lecture seule) ne sont pas
modifiées, les NetworkPolicies étant additives. Pas d'authentification Traefik : le login de l'outil est la seule barrière.

**Stack** : Helm 3, helm-unittest, kubeconform, Traefik (CRD `traefik.io/v1alpha1`), cert-manager, pgAdmin 4
(`dpage/pgadmin4`, version épinglée), RustFS ; tout en conteneurs lancés par `make helm-*`.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité). Plan de la mission `outils-donnees`, lot 3 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/outils-donnees-outils-web` · **Base** : `feature/outils-donnees` · **Profil** : `api`
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 4

- [x] **Tâche 1** Valeurs, hôtes et helpers · `feature/outils-donnees-outils-web`
  - [x] sections `hosts`, `ingress`, `pgadmin`, `rustfs.console` de `values.yaml`, hôtes dans `values-preprod.yaml` et `values-prod.yaml`
  - [x] helper d'origine Traefik et de libellés, `valeurs-communes.yaml`
- [x] **Tâche 2** Console RustFS sur le StatefulSet existant
- [x] **Tâche 3** pgAdmin 4 : ConfigMap, Deployment, Service
- [ ] **Tâche 4** Middlewares Traefik, Ingress et schéma CRD pour kubeconform
- [ ] **Tâche 5** NetworkPolicies des outils
- [ ] **Tâche 6** Quota de la preprod et documentation
- [ ] **Tâche 7** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/helm/urbankiff-donnees/templates/pgadmin.yaml` [nouveau]
- `infra/helm/urbankiff-donnees/templates/outils-ingress.yaml` [nouveau]
- `infra/helm/urbankiff-donnees/templates/outils-middlewares.yaml` [nouveau]
- `infra/helm/urbankiff-donnees/templates/reseau-outils.yaml` [nouveau]
- `infra/helm/urbankiff-donnees/templates/rustfs.yaml`
- `infra/helm/urbankiff-donnees/templates/_helpers.tpl`
- `infra/helm/urbankiff-donnees/values-preprod.yaml`
- `infra/helm/urbankiff-donnees/values-prod.yaml`
- `infra/helm/urbankiff-donnees/values.yaml` (sections `hosts`, `ingress`, `pgadmin`, `rustfs.console` seulement)
- `infra/helm/urbankiff-donnees/tests/outils_test.yaml` [nouveau]
- `infra/helm/urbankiff-donnees/tests/rustfs_test.yaml`
- `infra/helm/urbankiff-donnees/tests/valeurs-communes.yaml`
- `infra/helm/schemas/traefik.io/middleware_v1alpha1.json` [nouveau] (schéma CRD pour kubeconform ; arbitrage B6)
- `docs/v1/infra/outils-donnees.md` [nouveau]
- `docs/v1/infra/kubernetes.md` (section « Outils web » seulement)
- `docs/v1/plans/outils-donnees/3-outils-web.md` (ce plan : Avancement)

## Fichiers en lecture seule

La spec ; `CLAUDE.md`, `.claude/**` ; `make/helm.mk`, `make/standard.mk`, `make/devteam.mk` ; `infra/helm/tests-transverses/**`
(lot 6 : `controle.rb`, `secrets-inventaire.txt`) ; `infra/helm/urbankiff/**` (modèle d'Ingress : `templates/ingress.yaml`,
`templates/_helpers.tpl`) ; dans `infra/helm/urbankiff-donnees` : `templates/reseau-donnees.yaml`, `reseau-defaut.yaml`,
`postgres-*.yaml`, `redis.yaml`, `restauration-job.yaml`, `rustfs-bucket-job.yaml`, `sauvegarde-fichiers.yaml`, les autres
tests, et dans `values.yaml` toutes les sections hors `hosts`, `ingress`, `pgadmin`, `rustfs.console` (la section
`restauration` est au lot 4) ; `docs/v1/infra/kubernetes.md` hors section « Outils web » ; `infra/ansible/**` (le droit
`middlewares` du Role est au lot 7) ; `scripts/secrets/**` et `infra/deploiement/**` (liste des secrets, lots 5 et 6).

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par `make` (sur l'hôte :
`docker`, `make`, `git`, `gh`) ; helm-unittest sans mock ; fichiers de tests en français ; commits ASCII en Conventional
Commits ; aucun secret dans le dépôt. Au minimum : ne jamais modifier le code de production pour faire passer un test
(s'arrêter et le signaler) ; pas de `retry` ni de contournement ; couverture : chaque nouvelle branche de template (outil
absent, hôte manquant) a son test. Le code Django n'est pas touché : `coverage-diff`, `migrations-check`, `check-generated`
et e2e sont sans objet.

Contraintes propres au lot (spec §§ 2, 3, 5.4, 5.5, 8.3) :

- Contrat 8.3 « Outils web » : valeurs `hosts.db`, `hosts.stockage`, `ingress.classe`, `ingress.clusterIssuer` ;
  Deployment `urbankiff-pgadmin` avec `app.kubernetes.io/part-of: urbankiff` ; console sur un port de console du
  StatefulSet existant ; Middlewares `traefik.io/v1alpha1` (limitation de débit, en-têtes). Un changement de contrat : s'arrêter.
- Contrat « Secrets » : `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` lus par `secretKeyRef` dans `urbankiff-secrets`
  (`.Values.secretName`), jamais en `value:` ; la liste des secrets n'est pas modifiée ici.
- Aucun Secret rendu par le chart ; aucun port autre que 443 exposé ; port S3 9000 reste interne ; aucune authentification Traefik.
- Hôtes uniquement dans `values-<env>.yaml` : `hosts.db` = `preprod.db.urbankiff.com` / `db.urbankiff.com`,
  `hosts.stockage` = `preprod.stockage.urbankiff.com` / `stockage.urbankiff.com`. Écarts preprod/prod limités à `hosts.*`
  et `*.ressources.*` (contrat Iso) : mêmes valeurs `pgadmin.*`, `ingress.*`, `rustfs.console.*` dans les deux, sauf
  `pgadmin.ressources` éventuellement.
- Quota preprod : limite mémoire de pgAdmin choisie pour que `make helm-controle` passe (marge d'environ 450 Mi) ;
  **s'il ne passe pas, le plan s'arrête et le signale, aucun contournement** (ni baisse des autres composants, ni
  modification de `controle.rb`).
- Les contrôles transverses existants doivent rester verts : pod durci (`runAsNonRoot`, UID non nul, seccomp
  `RuntimeDefault`, pas de jeton de compte de service), conteneurs (init compris) avec `readOnlyRootFilesystem`,
  `drop: [ALL]`, requests et limits mémoire ; Deployment avec sondes, empreinte `urbankiff.com/secrets-checksum`, libellé
  `part-of` ; aucun hôte d'Ingress ne commence par `s3`.

## Points de revue

1. pgAdmin : non root (UID 10001 comme les autres pods), système de fichiers en lecture seule, seuls `/var/lib/pgadmin`,
   `/tmp` et les dossiers de travail de pgAdmin sont des `emptyDir` ; aucun mot de passe dans le rendu (ni ConfigMap, ni
   args) ; `servers.json` sans mot de passe.
2. Mot de passe de la base : fichier de mots de passe (clé `pgpass` du Secret `urbankiff-pg-app`, généré par CloudNativePG)
   copié par un init container en `0600` dans un `emptyDir` (libpq ignore un fichier lisible par le groupe, or `fsGroup`
   change les droits des volumes de Secret). Vérifier à la revue que la copie et le `PassFile` / `PGPASSFILE` sont cohérents.
3. NetworkPolicies : Traefik → pgAdmin (80 ou port choisi), Traefik → console (9001), pgAdmin → PostgreSQL 5432, **et rien
   d'autre** ; `postgres-entree` (lecture seule) n'autorise pas le composant `pgadmin` : l'entrée côté PostgreSQL est
   donc ajoutée dans `reseau-outils.yaml`, sans toucher `reseau-donnees.yaml`. Pas de sortie Internet pour pgAdmin
   (vérification des mises à jour désactivée).
4. Middlewares : limitation de débit (valeurs `ingress.limiteDebit.*`) et HSTS (`ingress.hsts.*`) appliqués aux deux Ingress ;
   aucun middleware d'authentification. L'annotation `router.middlewares` utilise `<namespace>-<nom>@kubernetescrd`
   avec `.Release.Namespace`.
5. Quota : pgAdmin est à 320 Mi de limite (proposition) ; la console tourne dans les 192 Mi de RustFS en preprod : si le
   contrôle ou la revue conclut que c'est trop juste, le signaler (la hausse de `rustfs.ressources` est un écart autorisé
   mais consomme la marge) plutôt que de l'absorber en silence.
6. Fichiers hors § 8.2 : `infra/helm/schemas/traefik.io/middleware_v1alpha1.json` ne figure dans aucun lot ; sans lui
   `make helm-valider` (kubeconform strict) échoue sur le Middleware. Ajout validé par l'arbitrage B6. `make/helm.mk` n'est pas modifié (la variable
   `SCHEMAS_LISTE` se surcharge en ligne de commande).
7. Risques d'exécution à vérifier après la PR finale, sur la preprod réelle (spec § 7), pas par les tests de rendu :
   démarrage de pgAdmin en lecture seule, prise en compte du fichier de mots de passe en mode serveur, console RustFS
   servie derrière un seul hôte HTTPS alors que le S3 reste interne, IP source vue par la limitation de débit derrière
   le service de Traefik.

---

### Tâche 1 : valeurs, hôtes et helpers

**Fichiers :**
- Modifier : `infra/helm/urbankiff-donnees/values.yaml` (sections `hosts`, `ingress`, `pgadmin`, `rustfs.console`),
  `values-preprod.yaml`, `values-prod.yaml`, `templates/_helpers.tpl`, `tests/valeurs-communes.yaml`
- Créer : `infra/helm/urbankiff-donnees/tests/outils_test.yaml` (premier cas)
- Test : `make helm-unittest CHART=urbankiff-donnees`

**Interfaces :**
- Consomme : modèle `infra/helm/urbankiff/templates/ingress.yaml` et helper `urbankiff.origineTraefik` du chart
  `urbankiff` (à recopier, les charts sont indépendants) ; helpers existants `urbankiff.labels`, `urbankiff.selecteur`.
- Produit : valeurs `hosts.db`, `hosts.stockage` (vides par défaut, fournies par `values-<env>.yaml`), `ingress.classe:
  traefik`, `ingress.clusterIssuer: letsencrypt`, `ingress.limiteDebit.{moyenne,rafale}`, `ingress.hsts.secondes`,
  `pgadmin.{image,port,ressources,...}`, `rustfs.console.{actif,port}` ; helper `urbankiff.origineTraefik`.

- [ ] **Étape 1** : dans `tests/outils_test.yaml` (`suite: outils`, `values: [valeurs-communes.yaml]`), écrire un test
  qui rend `templates/outils-ingress.yaml` avec `hosts.db` vide et attend `failedTemplate` « hosts.db est obligatoire »
  ; étendre `tests/valeurs-communes.yaml` avec `hosts.db: preprod.db.urbankiff.com` et `hosts.stockage:
  preprod.stockage.urbankiff.com`. Lancer `make helm-unittest CHART=urbankiff-donnees` : le voir échouer.
- [ ] **Étape 2** : ajouter dans `values.yaml` (et seulement là) : `hosts: {db: "", stockage: ""}`, `ingress:` (classe,
  clusterIssuer, limiteDebit moyenne 20 / rafale 50, hsts secondes 31536000), `pgadmin:` (image épinglée
  `dpage/pgadmin4:<version>` choisie par le constructeur, port, `ressources` requests 160Mi / limits 320Mi), et
  `rustfs.console: {actif: true, port: 9001}` sans toucher le reste de `rustfs`. Ajouter `hosts.db` et
  `hosts.stockage` à `values-preprod.yaml` et `values-prod.yaml` (seul écart autorisé, avec `pgadmin.ressources` si besoin).
- [ ] **Étape 3** : ajouter `urbankiff.origineTraefik` à `_helpers.tpl` (copie de celui du chart `urbankiff`).
- [ ] **Étape 4** : cocher l'Avancement ; commit d'une ligne (`feat: valeurs et hotes des outils web`).

---

### Tâche 2 : console RustFS sur le StatefulSet existant

**Fichiers :**
- Modifier : `infra/helm/urbankiff-donnees/templates/rustfs.yaml`, `infra/helm/urbankiff-donnees/tests/rustfs_test.yaml`

**Interfaces :**
- Consomme : `rustfs.console.actif`, `rustfs.console.port` (tâche 1).
- Produit : conteneur `rustfs` avec `RUSTFS_CONSOLE_ENABLE=true` et `RUSTFS_CONSOLE_ADDRESS=0.0.0.0:<port>`, port nommé
  `console`, Service `urbankiff-rustfs` exposant `console` en plus de `s3` (9000 inchangé et interne) ; sondes inchangées
  (tcp sur `s3`). Aucun pod de plus.

- [ ] **Étape 1** : mettre à jour `rustfs_test.yaml` : le cas « console désactivée, aucun hôte public » devient « console
  activée sur 9001 » (env `RUSTFS_CONSOLE_ENABLE: "true"` et `RUSTFS_CONSOLE_ADDRESS`, port `console` du conteneur et du
  Service, port `s3` toujours 9000) ; ajouter un cas `rustfs.console.actif=false` qui rend la console désactivée et sans
  port `console` ; conserver les assertions de durcissement, de volumes et de limites existantes. Les voir échouer.
- [ ] **Étape 2** : implémenter dans `rustfs.yaml` (conditionner l'env, le port du conteneur et le port du Service à
  `rustfs.console.actif`).
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff-donnees` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 3 : pgAdmin 4 (ConfigMap, Deployment, Service)

**Fichiers :**
- Créer : `infra/helm/urbankiff-donnees/templates/pgadmin.yaml`
- Modifier : `infra/helm/urbankiff-donnees/tests/outils_test.yaml`

**Interfaces :**
- Consomme : `pgadmin.*` (tâche 1) ; Secret `.Values.secretName` clés `PGADMIN_EMAIL`, `PGADMIN_MOT_DE_PASSE` ; Secret
  `urbankiff-pg-app` (clé `pgpass`) ; Service `urbankiff-pg-rw` ; helpers `securityContextPod` / `securityContextConteneur`.
- Produit : ConfigMap `urbankiff-pgadmin-config` (`servers.json` : serveur `urbankiff-pg`, hôte `urbankiff-pg-rw`, port
  5432, base et utilisateur de `postgres.base` / `postgres.utilisateur`, `SSLMode: prefer`, `PassFile`), Deployment
  `urbankiff-pgadmin` (1 réplique, stratégie `Recreate`, labels `urbankiff.labels` composant `pgadmin`, annotation
  `urbankiff.com/secrets-checksum`, `automountServiceAccountToken: false`), Service `urbankiff-pgadmin`.

- [ ] **Étape 1** : dans `outils_test.yaml`, écrire les tests (les voir échouer) : kinds et noms ; libellé
  `part-of: urbankiff` et composant `pgadmin` ; `PGADMIN_DEFAULT_EMAIL` et `PGADMIN_DEFAULT_PASSWORD` par `secretKeyRef`
  (`PGADMIN_EMAIL`, `PGADMIN_MOT_DE_PASSE` de `urbankiff-secrets`), aucune de ces variables en `value:` ; durcissement
  (`runAsNonRoot`, UID 10001, seccomp, `readOnlyRootFilesystem: true`, `drop: [ALL]`, requests et limits mémoire, sondes,
  empreinte) ; seuls des `emptyDir` hors fichier de mots de passe et `servers.json` montés en écriture ; le mot de passe
  vient du Secret `urbankiff-pg-app` (aucune valeur littérale), `servers.json` n'en contient pas ; vérification des mises
  à jour désactivée.
- [ ] **Étape 2** : implémenter `pgadmin.yaml` : init container (même image, mêmes limites, durci) copiant `pgpass` du
  Secret vers un `emptyDir` en `0600` ; conteneur pgAdmin avec `PGADMIN_CONFIG_SERVER_MODE`, `PGADMIN_SERVER_JSON_FILE`,
  `PGPASSFILE`, désactivation de la vérification de version, `emptyDir` pour `/var/lib/pgadmin`, `/tmp` et les autres
  dossiers de travail que le démarrage en lecture seule exige (à relever en lançant l'image, voir Points de revue 7).
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff-donnees` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 4 : Middlewares Traefik, Ingress et schéma CRD

**Fichiers :**
- Créer : `infra/helm/urbankiff-donnees/templates/outils-middlewares.yaml`, `templates/outils-ingress.yaml`,
  `infra/helm/schemas/traefik.io/middleware_v1alpha1.json`
- Modifier : `infra/helm/urbankiff-donnees/tests/outils_test.yaml`

**Interfaces :**
- Consomme : `hosts.db`, `hosts.stockage`, `ingress.*` (tâche 1) ; Services `urbankiff-pgadmin` et `urbankiff-rustfs:console`
  (tâches 2 et 3) ; droit `middlewares` du Role `deploy` (lot 7, contrat 8.3).
- Produit : Middlewares `urbankiff-outils-limite-debit` (`rateLimit`, critère IP source) et `urbankiff-outils-entetes`
  (`headers` : HSTS `stsSeconds`, `stsIncludeSubdomains`, `forceSTSHeader`, plus `contentTypeNosniff`, `frameDeny`),
  `traefik.io/v1alpha1` ; Ingress `urbankiff-pgadmin` et `urbankiff-stockage` (cert-manager, TLS, secrets
  `urbankiff-db-tls` et `urbankiff-stockage-tls`, annotation `traefik.ingress.kubernetes.io/router.middlewares`).

- [ ] **Étape 1** : tests (les voir échouer) : hôte manquant (`hosts.db`, `hosts.stockage`) refusé ; deux Ingress avec
  `ingressClassName` et annotation `cert-manager.io/cluster-issuer` issus des valeurs, TLS par hôte, backends sur les
  bons Services et ports ; annotation `router.middlewares` listant les deux Middlewares avec le namespace de la release ;
  Middlewares : `apiVersion: traefik.io/v1alpha1`, valeurs de `rateLimit` et HSTS issues des valeurs ; **aucun**
  middleware `basicAuth` / `forwardAuth` / `digestAuth` ; hôtes distincts des hôtes `s3*` ; aucun port autre que 443 (pas
  d'annotation d'entrypoint non TLS).
- [ ] **Étape 2** : implémenter les deux templates.
- [ ] **Étape 3** : obtenir le schéma kubeconform : `make helm-schemas SCHEMAS_LISTE=traefik.io/middleware_v1alpha1`
  (surcharge de la variable : ne régénère que ce fichier ; seule cible avec accès réseau). Si la cible ne produit pas
  le fichier, **s'arrêter et le signaler** (pas d'écriture manuelle d'un schéma). Vérifier que
  `make helm-valider ENV=preprod CHART=urbankiff-donnees` passe.
- [ ] **Étape 4** : `make helm-unittest CHART=urbankiff-donnees` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 5 : NetworkPolicies des outils

**Fichiers :**
- Créer : `infra/helm/urbankiff-donnees/templates/reseau-outils.yaml`
- Modifier : `infra/helm/urbankiff-donnees/tests/outils_test.yaml`

**Interfaces :**
- Consomme : `urbankiff.origineTraefik`, `urbankiff.selecteur`, libellé `cnpg.io/cluster: urbankiff-pg`, politiques par défaut
  (`default-deny`, `autoriser-dns`) de `reseau-defaut.yaml`.
- Produit : `pgadmin-entree` (Traefik → pgAdmin sur son port), `stockage-console-entree` (Traefik → composant `rustfs`
  port 9001), `pgadmin-sortie` (pgAdmin → pods `cnpg.io/cluster: urbankiff-pg` port 5432, seule sortie), `postgres-entree-pgadmin`
  (entrée de PostgreSQL depuis le composant `pgadmin`, port 5432, car `postgres-entree` ne le liste pas). Libellé
  `part-of: urbankiff`.

- [ ] **Étape 1** : tests (les voir échouer) : chaque politique existe avec les bons sélecteurs et ports ; Traefik désigné
  par `kube-system` et `app.kubernetes.io/name: traefik` (les contrôles transverses n'acceptent que `kube-system` et
  `cnpg-system`) ; aucune sortie vers Internet (pas d'`ipBlock`) pour pgAdmin ; aucune règle d'entrée hors Traefik vers la
  console ; aucune règle ne cite `prod` ou `preprod`.
- [ ] **Étape 2** : implémenter `reseau-outils.yaml`.
- [ ] **Étape 3** : `make helm-unittest CHART=urbankiff-donnees` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 6 : quota de la preprod et documentation

**Fichiers :**
- Créer : `docs/v1/infra/outils-donnees.md`
- Modifier : `docs/v1/infra/kubernetes.md` (section « Outils web » seulement, créée par ce lot)

**Interfaces :**
- Consomme : sortie de `make helm-controle` (ligne « limites en régime établi … ») et `make helm-rendu ENV=preprod CHART=urbankiff-donnees`.
- Produit : documentation des outils (usage de pgAdmin et de la console, connexion préconfigurée, secrets `PGADMIN_EMAIL`,
  `PGADMIN_MOT_DE_PASSE`, `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` comme login de la console, **enregistrements DNS à
  créer** : `db`, `stockage`, `preprod.db`, `preprod.stockage` sous `urbankiff.com`, limites de la limitation de débit,
  absence d'authentification Traefik et conséquence) ; section « Outils web » de `kubernetes.md` (Deployment, console,
  Middlewares, NetworkPolicies, quota recalculé).

- [ ] **Étape 1** : lancer `make helm-controle` ; relever la ligne de quota. Attendu : régime 1 728 + pgAdmin,
  total ≤ 3 072 Mi (avec 320 Mi : 2 944 Mi). Relever aussi à la lecture du rendu (`make helm-rendu`) la somme des
  **requêtes** mémoire de la preprod et la comparer au quota de 1 536 Mi : le lot 6 ajoute ce contrôle à `controle.rb` (B9) ; tant qu'il n'est pas fusionné, la vérification manuelle des requêtes reste obligatoire et se reporte dans la documentation et le rapport. pgAdmin est dimensionné pour tenir dans les limites ET les requêtes.
- [ ] **Étape 2** : **si le total dépasse 3 072 Mi ou si les requêtes dépassent 1 536 Mi : s'arrêter, ne rien contourner
  (ni baisser un autre composant, ni modifier `controle.rb`), passer l'issue en `etat:bloque` et signaler le chiffre.**
- [ ] **Étape 3** : rédiger les deux documents (français, avec accents, convention du projet) ; recalculer dans « Outils
  web » le quota (régime, marge restante). Ne pas toucher les autres sections de `kubernetes.md`.
- [ ] **Étape 4** : cocher l'Avancement ; commit d'une ligne (`docs: outils web de la base et du stockage`).

---

### Tâche 7 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make helm-controle` vert (lint des deux charts avec les valeurs prod et preprod, helm-unittest, garde, contrôles
  transverses dont quota et durcissement, kubeconform strict des deux environnements, Middleware compris).
- [ ] Rendu relu : `make helm-rendu ENV=prod CHART=urbankiff-donnees` et `ENV=preprod` ; vérifier que les hôtes sont ceux
  de la spec § 5.4, qu'aucun Secret n'est rendu et qu'aucun mot de passe n'apparaît.
- [ ] `make lint` et `make typecheck`, `make coverage-diff`, `make migrations-check`, `make check-generated`, e2e :
  sans objet (aucun code applicatif touché) ; le noter dans le rapport.
- [ ] `make secrets-scan` : aucun secret dans le dépôt.
- [ ] Périmètre : `make devteam-perimetre LOT=outils-web PLAN=docs/v1/plans/outils-donnees/3-outils-web.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler
  (requêtes du quota, risques d'exécution du Points de revue 7, enregistrements DNS à créer par le développeur).
