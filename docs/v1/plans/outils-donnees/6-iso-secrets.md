# Lot iso-secrets (contrôle d'iso, SMS actif partout, nouveaux secrets) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d'écart) : B7, B8, B9.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : rendre la preprod iso à la prod côté valeurs et secrets : `sms.actif: true` dans les deux environnements
(même compte Twilio), contrôle automatique qui échoue sur tout écart non autorisé entre `values-preprod.yaml` et
`values-prod.yaml` des deux charts, secrets `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` ajoutés, `MINIO_ROOT_USER` et
`MINIO_ROOT_PASSWORD` passés en saisie masquée, ensembles de clés des fichiers `variables-*.txt` verrouillés égaux.

**Architecture** : le contrôle d'iso est un petit module Ruby (`iso.rb`, bibliothèque standard seulement) appelé par
`controle.rb`, donc lancé par `make helm-test` / `make helm-controle` sans toucher à `make/helm.mk`. Il aplatit les deux
fichiers de valeurs en chemins pointés, écarte les écarts autorisés (`environnement`, `hosts.*`, tout chemin contenant
un segment `ressources`) et liste le reste. Un auto-test (`iso-test.rb`, appelé aussi par `controle.rb`) prouve qu'un
écart non autorisé fait échouer le contrôle. Le contrôle Twilio de `controle.rb` passe de « preprod inerte » à
« preprod comme prod : références au Secret, aucune valeur inerte ». La logique du chart (valeurs inertes quand
`sms.actif` est faux) reste en place, templates en lecture seule. Les listes de secrets restent cohérentes par bats.

**Stack** : Ruby (stdlib, conteneur `RUBY_IMAGE` de `make helm-transverses`), helm-unittest/helm (rendu, lecture
seule), shell + bats (`make secrets-test`), Markdown.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité ; § 2 objectif 7, § 5.1, § 5.5, § 8.3 lignes « Iso (lot 6) » et « Secrets (lots 5 et 6) »). Plan de la mission
`outils-donnees`, lot 6 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : (renseignée par le superviseur)
- **Branche** : `feature/outils-donnees-iso-secrets` · **Base** : `feature/outils-donnees` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 2

- [x] **Tâche 1** Secrets : nouveaux secrets, saisie masquée, clés des variables · `feature/outils-donnees-iso-secrets`
  - [x] Tests bats d'abord (`inventaire.bats`), vus en échec
  - [x] `secrets.txt`, `secrets-inventaire.txt`, `docs/v1/infra/secrets.md` (tableau des secrets)
- [ ] **Tâche 2** Module du contrôle d'iso et son auto-test
  - [ ] `iso-test.rb` d'abord (échec : module absent), puis `iso.rb`
  - [ ] Écart non autorisé détecté, écarts autorisés tolérés
- [ ] **Tâche 3** Brancher le contrôle d'iso sur les deux charts et adapter le contrôle Twilio
  - [ ] `controle.rb` d'abord (échec : preprod sans SMS), puis `values-preprod.yaml` (`sms.actif: true`)
  - [ ] Inventaire sans exception « inerte »
- [ ] **Tâche 4** Documentation (`secrets.md`, section « Iso preprod / prod » de `kubernetes.md`)
- [ ] **Tâche 5** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/helm/tests-transverses/**` (`controle.rb`, `secrets-inventaire.txt`, `iso.rb` [nouveau], `iso-test.rb` [nouveau])
- `infra/helm/urbankiff/values-preprod.yaml`
- `infra/helm/urbankiff/values-prod.yaml`
- `scripts/secrets/**` (`secrets.txt`, tests bats)
- `docs/v1/infra/secrets.md`
- `docs/v1/infra/kubernetes.md` (section « Iso preprod / prod » à créer, plus, B7, les lignes `sms.actif` du tableau « Variables et Secrets consommés » : seules lignes hors section autorisées)
- `docs/v1/plans/outils-donnees/6-iso-secrets.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md`, `CLAUDE.md`, `.claude/**`, `make/helm.mk`,
`make/secrets.mk`, `make/devteam.mk`, `make/standard.mk`, `infra/helm/urbankiff/templates/**` et
`infra/helm/urbankiff/values.yaml` (la logique des valeurs inertes Twilio y reste), tout `infra/helm/urbankiff-donnees/**`
(lots 3 et 4 : `hosts.*`, pgAdmin, restauration), `infra/deploiement/**` (lot 5 : `SECRET_KEYS`), les fichiers des
autres lots, les sections de `kubernetes.md` des lots 3 et 4.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test (`.claude/devteam.projet.md`, `CLAUDE.md`) : aucun mock de la base ni de l'ORM ; fabriques pour les
données ; ne jamais modifier le code de production pour faire passer un test (s'arrêter et le signaler) ; pas de
`retry` ni de contournement pour masquer une instabilité ; toutes les commandes passent par `make` (sur l'hôte :
`docker`, `make`, `git`, `gh` seulement : le Ruby tourne dans le conteneur de `make helm-test`, le bats dans celui de
`make secrets-test`). Ce lot ne touche aucun code Django : couverture de code sans objet, mais **chaque règle
nouvelle du contrôle a un test qui l'a vue échouer**.

- Aucune valeur de secret dans le dépôt, la documentation ou un journal : seulement des noms.
- Le contrat « Iso » (§ 8.3) est exact : écarts autorisés = `environnement`, `hosts.*`, toute clé sous `*.ressources.*`.
  Les hôtes de `urbankiff-donnees` (`hosts.db`, `hosts.stockage`, lot 3) tombent dans `hosts.*`. Aucun autre écart
  n'est ajouté à la liste.
- Le contrat « Secrets » est exact : `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` dans `secrets.txt` (type `saisie`) ;
  `MINIO_ROOT_USER` et `MINIO_ROOT_PASSWORD` en `saisie`. La liste `SECRET_KEYS` du script de déploiement (lot 5) est
  modifiée à l'identique par l'autre lot : ce lot ne la touche pas.
- Un contrôle qui ne peut pas s'exécuter (fichier de valeurs absent, YAML illisible) échoue, il ne passe pas en silence.

## Points de revue

1. Le contrôle d'iso lit **les deux charts** (`urbankiff` et `urbankiff-donnees`) et compare les fichiers de valeurs
   complets, y compris les clés présentes d'un seul côté ; l'auto-test prouve qu'un écart hors liste échoue.
2. La liste des écarts autorisés est exactement celle du contrat, écrite en un seul endroit (`iso.rb`).
3. Le contrôle Twilio exige les références `secretKeyRef` en preprod **et** en prod, et refuse toute valeur inerte
   dans les rendus ; plus aucune exception « inerte » dans le contrôle de l'inventaire des secrets.
4. `secrets.txt` : `MINIO_ROOT_*` en saisie, `PGADMIN_*` ajoutés, `secrets-inventaire.txt` à l'identique (plus
   `POSTGRES_PASSWORD`), `secrets.md` à jour ; les clés de `variables-prod.txt` et `variables-preprod.txt` sont les mêmes.
5. Le quota de requêtes (1 536 Mi) est contrôlé en plus des limites, avec auto-test (B9).
6. Aucun fichier d'un autre lot touché ; `kubernetes.md` : uniquement la section « Iso preprod / prod ».

---

### Tâche 1 : secrets (nouveaux, saisie masquée, clés des variables)

**Fichiers :**
- Modifier : `scripts/secrets/secrets.txt`, `infra/helm/tests-transverses/secrets-inventaire.txt`,
  `docs/v1/infra/secrets.md` (tableau « Secrets », lignes `MINIO_ROOT_*` et deux lignes nouvelles)
- Test : `scripts/secrets/tests/inventaire.bats`

**Interfaces :**
- Consomme : contrat « Secrets (lots 5 et 6) » ; format `NOM TYPE` de `secrets.txt` lu par `definir-secrets.sh`
  (type `saisie` : saisie masquée, vide = inchangé).
- Produit : `secrets.txt` avec `PGADMIN_EMAIL saisie`, `PGADMIN_MOT_DE_PASSE saisie`, `MINIO_ROOT_USER saisie`,
  `MINIO_ROOT_PASSWORD saisie` ; l'inventaire de contrôle (`secrets-inventaire.txt`) en reprend les noms.

- [ ] **Étape 1** : ajouter à `inventaire.bats` (sans modifier les tests existants) puis lancer `make secrets-test`,
  les voir échouer :
  - « contrat Secrets du lot iso-secrets » : `PGADMIN_EMAIL`, `PGADMIN_MOT_DE_PASSE`, `MINIO_ROOT_USER`,
    `MINIO_ROOT_PASSWORD` sont chacun `saisie` dans `secrets.txt` (`grep -q "^$n saisie"`), et aucun
    `MINIO_ROOT_*` n'est de type `aleatoire*` ;
  - « les noms de secrets.txt et de secrets-inventaire.txt coïncident » : les noms de `secrets.txt` (hors commentaires)
    plus `POSTGRES_PASSWORD` égalent, comme ensembles triés, les noms de
    `infra/helm/tests-transverses/secrets-inventaire.txt` ;
  - « variables-prod.txt et variables-preprod.txt ont les mêmes clés » : comparaison des ensembles de clés triés (déjà
    vrai : le test verrouille l'iso, spec § 5.1) ; ce test passe dès l'écriture, **le voir échouer** en ajoutant
    temporairement une clé à un seul fichier, puis revenir en arrière ;
  - « les noms de secrets figurent dans secrets.md » : déjà couvert par le premier test existant (il échouera tant que
    les deux nouveaux noms ne sont pas documentés).
- [ ] **Étape 2** : modifier `secrets.txt` (types `saisie` pour `MINIO_ROOT_*`, deux lignes `PGADMIN_*` `saisie`),
  `secrets-inventaire.txt` (deux noms ajoutés), et le tableau de `secrets.md` : `MINIO_ROOT_USER` et
  `MINIO_ROOT_PASSWORD` « saisie masquée (script), connus du développeur : login de la console du stockage » ;
  `PGADMIN_EMAIL` (login pgAdmin) et `PGADMIN_MOT_DE_PASSE` (mot de passe pgAdmin), colonnes « emplacement avant » et
  « révocation » : « — » ; ne jamais écrire de valeur.
- [ ] **Étape 3** : `make secrets-test` tout vert ; cocher l'Avancement ; commit d'une ligne
  (`feat: secrets PGADMIN_* et MINIO_ROOT_* en saisie masquee`).

---

### Tâche 2 : module du contrôle d'iso et son auto-test

**Fichiers :**
- Créer : `infra/helm/tests-transverses/iso.rb`, `infra/helm/tests-transverses/iso-test.rb`

**Interfaces :**
- Consomme : deux fichiers YAML de valeurs (`<chart>/values-prod.yaml`, `<chart>/values-preprod.yaml`).
- Produit : `Iso.ecarts(prod, preprod)` (Hash → liste de chaînes `chemin : prod=<v> preprod=<v>` pour chaque chemin
  aplati qui diffère, valeur absente d'un côté comprise, hors écarts autorisés) ;
  `Iso.autorise?(chemin)` : vrai pour `environnement`, tout chemin commençant par `hosts.`, tout chemin dont un
  segment vaut `ressources` ; `Iso.ecarts_fichiers(dossier_chart)` (lit les deux fichiers, lève une erreur claire si
  l'un manque ou est illisible) ; `Iso.sms_actif?(valeurs)`.

- [ ] **Étape 1** : écrire `iso-test.rb` (script autonome, `require_relative 'iso'`, sortie non nulle au premier
  échec) avec ces cas, et le lancer dans le conteneur Ruby (la commande exacte passe par `make helm-test` après la
  tâche 3 ; en attendant, ajouter l'appel dans `controle.rb` dès cette étape pour que l'échec « fichier `iso.rb`
  absent » soit visible par `make helm-test`) :
  - mêmes valeurs des deux côtés → aucun écart ;
  - écarts sur `environnement`, `hosts.web`, `hosts.db`, `hosts.stockage`, `api.ressources.limits.memory`,
    `postgres.ressources.requests.memory` → aucun écart ;
  - **écart non autorisé** (`sms.actif` différent, une clé `nextjs.replicas` différente, une clé `pgadmin.image`
    présente d'un seul côté, une valeur de liste différente) → chacun listé, et `Iso.ecarts` non vide ;
  - un chemin qui contient `ressources` comme sous-chaîne seulement (`ressourcesExtra.x`) n'est **pas** autorisé ;
  - `Iso.ecarts_fichiers` sur un dossier de test (fichiers écrits dans un répertoire temporaire du conteneur) avec un
    écart volontaire non autorisé → l'erreur remonte ; fichier absent → erreur claire ;
  - `sms.actif` : vrai/faux/absent.
- [ ] **Étape 2** : écrire `iso.rb` (stdlib, aplatissement récursif des Hash en chemins pointés, les tableaux et
  scalaires sont des feuilles comparées par égalité). La liste des écarts autorisés est une constante unique,
  commentée par le pourquoi (spec § 5.1).
- [ ] **Étape 3** : relancer, tout vert ; cocher l'Avancement ; commit (`feat: module du controle d'iso preprod prod`).

---

### Tâche 3 : brancher le contrôle sur les deux charts, adapter le contrôle Twilio, SMS actif en preprod

**Fichiers :**
- Modifier : `infra/helm/tests-transverses/controle.rb`, `infra/helm/urbankiff/values-preprod.yaml`
  (`values-prod.yaml` : seulement si un écart non autorisé existe, sinon inchangé)
- Test : `infra/helm/tests-transverses/controle.rb` (contrôles), `iso-test.rb`

**Interfaces :**
- Consomme : `Iso` (tâche 2) ; rendus `/rendu/<chart>-<env>.yaml` et valeurs `/charts/<chart>/values-<env>.yaml`.
- Produit : section `== Iso preprod / prod` de `controle.rb` : (a) auto-test d'`iso-test.rb` exécuté en premier (un
  échec du test est un échec du contrôle) ; (b) pour chaque chart de `/charts` ayant des fichiers `values-prod.yaml`
  et `values-preprod.yaml`, `verifie "iso <chart> : aucun écart non autorisé", Iso.ecarts_fichiers(...)` ;
  (c) `sms.actif` vaut `true` dans `urbankiff/values-prod.yaml` et `urbankiff/values-preprod.yaml` ; (d) la liste
  des charts est découverte (`Dir.glob`) et doit contenir exactement `urbankiff` et `urbankiff-donnees` (un chart
  oublié fait échouer). Section Twilio réécrite (voir étape 1).

- [ ] **Étape 1** (tests d'abord) : réécrire la section `== Twilio` de `controle.rb` pour l'iso : en **prod et en
  preprod**, `TWILIO_ACCOUNT_SID` et `TWILIO_AUTH_TOKEN` sont référencés par `secretKeyRef` et aucune valeur
  `desactive` n'apparaît dans les rendus ; dans le contrôle « aucune clé de l'inventaire des secrets en `value:` »,
  supprimer l'exception « valeur inerte » (constante `TWILIO` conservée pour le contrôle de référence). Ajouter la
  section d'iso décrite plus haut. Lancer `make helm-test` : **il échoue** (la preprod rend encore des valeurs
  inertes, `sms.actif: false`). Vérifier le message d'échec.
- [ ] **Étape 2** : mettre `sms.actif: true` dans `values-preprod.yaml` et remplacer le commentaire « les valeurs
  Twilio de preprod restent inertes » par une ligne disant que la preprod utilise le compte Twilio de la prod (spec
  § 5.1). Aucune autre clé de ce fichier ne change (la mémoire reste un écart autorisé).
- [ ] **Étape 2 bis** (B9, tests d'abord) : ajouter à `controle.rb` le contrôle du quota de **requêtes** de la preprod (constante `QUOTA_REQUETES_PREPROD_MI = 1536`) : même calcul que le quota de limites (régime établi, auxiliaire Barman, pod de mise à jour, plus gros Job) sur `resources.requests.memory`, avec un auto-test (calcul isolé dans une fonction testée sur des documents en mémoire : un total au-dessus de 1 536 Mi échoue, en dessous passe). L'écrire avant, le voir échouer, puis implémenter ; un dépassement réel est signalé au lot 3 (qui dimensionne pgAdmin pour tenir dans les deux quotas), pas contourné.
- [ ] **Étape 3** : preuve de l'écart (manuelle, non commitée) : modifier temporairement une clé non autorisée dans
  `values-preprod.yaml` (par exemple `nextjs.replicas: 2`), lancer `make helm-test`, vérifier l'échec nommant le
  chemin, puis annuler. Relancer `make helm-test` : tout vert, y compris le calcul de quota (pgAdmin du lot 3 y
  entrera au moment de la fusion : un dépassement est signalé au lot 3, pas contourné).
- [ ] **Étape 4** : cocher l'Avancement ; commit (`feat: controle d'iso preprod prod, SMS actif en preprod`).

---

### Tâche 4 : documentation

**Fichiers :**
- Modifier : `docs/v1/infra/secrets.md`, `docs/v1/infra/kubernetes.md` (section « Iso preprod / prod » **seulement** :
  nouvelle section, ajoutée avant « Points laissés aux lots voisins » ou en fin de fichier)

**Interfaces :**
- Consomme : contrat « Iso (lot 6) » ; décisions § 5.1 et § 5.5.
- Produit : documentation cohérente avec le code ; `inventaire.bats` reste vert.

- [ ] **Étape 1** : `secrets.md` : remplacer le paragraphe « Les valeurs Twilio de `preprod` restent factices… » par
  « La preprod utilise le même compte Twilio que la prod : `TWILIO_ACCOUNT_SID` et `TWILIO_AUTH_TOKEN` de `preprod`
  reçoivent les valeurs de la prod (saisie masquée) ; la preprod envoie de vrais SMS » ; compléter la section sur les
  secrets saisis avec la remarque que `MINIO_ROOT_*` sont désormais connus du développeur (changer la valeur d'un
  environnement déjà en service demande de redémarrer RustFS) ; vérifier qu'aucune valeur n'est écrite.
- [ ] **Étape 2** : `kubernetes.md`, section « Iso preprod / prod » : principe, liste exacte des écarts autorisés
  (`environnement`, `hosts.*`, `*.ressources.*`), où vit le contrôle (`controle.rb` + `iso.rb`, lancé par
  `make helm-controle`), comment le rendre vert ou ajouter un écart (modification du contrat de la spec, pas du test),
  `sms.actif: true` partout, égalité des ensembles de clés des `variables-*.txt` (testée par `make secrets-test`),
  mémoire et quota non alignés (décision du développeur). Ne pas toucher aux sections des autres lots ; corriger (B7, autorisé) les lignes « `sms.actif: true` … sinon inerte » (tableau « Variables et Secrets consommés ») et
  « `sms.actif: false` (preprod) ne neutralise que… » du tableau « Variables et Secrets consommés » (devenues fausses pour la preprod : `sms.actif: true` partout, valeur inerte seulement si `sms.actif` est faux). Ne modifier aucune autre ligne hors de la section.
- [ ] **Étape 3** : `make secrets-test` vert (le test de présence des noms dans `secrets.md`) ; cocher l'Avancement ;
  commit (`docs: iso preprod prod, secrets pgadmin et twilio`).

---

### Tâche 5 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make secrets-test` vert (bats : listes, inventaire, clés des variables, saisie masquée).
- [ ] `make helm-controle` vert (lint, helm-unittest des deux charts, contrôles transverses dont iso, Twilio et quota,
  garde, kubeconform prod et preprod).
- [ ] Preuve que le contrôle échoue : écart non autorisé introduit à la main dans `values-preprod.yaml` du chart
  `urbankiff`, puis dans celui de `urbankiff-donnees` s'il existe en base (échec attendu nommant le chemin), annulé
  ensuite ; l'auto-test d'`iso-test.rb` est vert dans la sortie de `make helm-test`.
- [ ] `make secrets-scan` : aucune valeur de secret dans le dépôt.
- [ ] `make lint` et `make typecheck` : sans objet pour ce lot (aucun fichier d'application modifié) ; couverture,
  `check-generated`, `migrations-check`, e2e : sans objet.
- [ ] Périmètre : `make devteam-perimetre LOT=iso-secrets PLAN=docs/v1/plans/outils-donnees/6-iso-secrets.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler
  (changement des `MINIO_ROOT_*` de la preprod déjà en service ;
  `SECRET_KEYS` et `inventaire-cles.bats` restent au lot 5, B8 : l'égalité stricte est rétablie après la fusion des lots 5 et 6).
