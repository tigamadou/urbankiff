# Déploiement (script serveur, outillage poste, workflow CI) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A1 (aucun ghcr-pull ni GHCR_PULL_* ; documenter le passage des paquets GHCR en public), A2 (cibles de preprod-arret), A3 (POSTGRES_PASSWORD n'est plus transmis), A5 (stdin porte secrets et variables ; Secret urbankiff-secrets + ConfigMap urbankiff-config ; --set wasabi.region et wasabi.bucket ; relecture de la ConfigMap sans entrée ; variables lues par gh variable list sur le poste), A8 (environnement en premier argument, commande dans SSH_ORIGINAL_COMMAND, /etc/urbankiff/deploy.<env>.env), A11 (charts-publier dans ce lot).

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir le chemin de déploiement par version vers le cluster k3s : un script serveur à commande forcée
SSH (`urbankiff-deploy.sh`), les cibles `make` du poste du développeur (images, charts, déploiement, Secrets du
cluster, arrêt et démarrage de la preprod), le workflow GitHub `deploiement.yml`, leurs tests et leur documentation.

**Architecture** : le script serveur est le seul point d'entrée du compte `deploy` (`SSH_ORIGINAL_COMMAND`) ; il lit
`/etc/urbankiff/deploy.env`, valide tout, crée les Secrets à partir de l'entrée standard (ou réutilise ceux du
namespace), tire les deux charts OCI de GHCR, déploie les données sans `--atomic` puis l'application avec
`--atomic --wait`, et contrôle `/api/health/`. Le poste et la CI appellent le même script par SSH ; la CI lui envoie
les secrets sur l'entrée standard, le poste non. Modèle : `steamy-deploy.sh` et `deploy.yml` de steamy, durcis
(allow-list de clés, sous-commandes preprod, aucune valeur en argument).

**Stack** : bash, bats (faux `ssh`, `helm`, `kubectl`, `docker`, `curl`, `flock`), GNU Make, Docker buildx, `gh`,
GitHub Actions, actionlint en conteneur.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité). Plan
de la mission `k3s-ansible`, lot 7 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/k3s-ansible-deploiement` · **Base** : `feature/k3s-ansible` · **Profil** : `api`
- **Dépendances** : `socle` (inclusion des `make/*.mk` par le `Makefile`), à fusionner dans la base avant de démarrer.
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 5

- [x] **Tâche 1** Script serveur : squelette, commande forcée, semver, verrou, configuration · `feature/k3s-ansible-deploiement`
  - [x] bats : faux binaires et cas de refus
  - [x] implémentation
- [x] **Tâche 2** Script serveur : entrée standard, Secrets, empreinte, réutilisation sans entrée
  - [x] bats : validation, taille, clés, aucune fuite
  - [x] implémentation
- [x] **Tâche 3** Script serveur : charts, déploiement des données puis de l'application, santé, arrêt et démarrage preprod
  - [x] bats : ordre des appels, `--atomic`, santé, préprod
  - [x] implémentation
- [x] **Tâche 4** Poste : `make/deploiement.mk` (images, charts, déploiement, secrets-cluster, preprod, tests)
  - [x] bats : faux `docker`, `gh`, `ssh`
  - [x] implémentation
- [ ] **Tâche 5** Workflow `deploiement.yml` et actionlint
- [ ] **Tâche 6** Documentation `docs/v1/infra/deploiement.md`
- [ ] **Tâche 7** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/deploiement/**` [nouveau] (script `urbankiff-deploy.sh`, tests bats dans `infra/deploiement/tests/`, faux binaires dans `infra/deploiement/tests/fakes/`)
- `make/deploiement.mk` [nouveau]
- `.github/workflows/deploiement.yml` [nouveau]
- `docs/v1/infra/deploiement.md` [nouveau]
- `docs/v1/plans/k3s-ansible/7-deploiement.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-16-k3s-ansible.md`, `docs/v1/infra/rotation-secrets.md`, `docs/v1/infra/secrets.md`.
- `scripts/secrets/**` (listes `secrets.txt`, `variables-prod.txt`, `variables-preprod.txt`, `definir-secrets.sh` et ses
  tests : modèle de la saisie masquée) ; le lot `nettoyage` les modifie en parallèle.
- `.github/workflows/devteam-ci.yml`, `make/devteam.mk`, `make/standard.mk`, `make/secrets.mk`, `Makefile`
  (inclusion des `make/*.mk` faite par `socle`).
- Fichiers exclusifs des lots `ansible` (copie le script vers `/usr/local/bin/urbankiff-deploy` ; kubeconfig,
  `deploy.env`), `charts` (noms des charts, valeurs, Secrets), `api-prod`, `fronts-prod` (arguments de construction).
- Référence hors dépôt, à ne pas modifier : `steamy/infra/deploy/steamy-deploy.sh`, `steamy/.github/workflows/deploy.yml`.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par des cibles
`make` qui lancent des conteneurs (sur l'hôte : `docker`, `make`, `git`, `gh` seulement) ; la CI du dépôt est
`ci-ok` ; commits en ASCII, Conventional Commits ; pas de commentaires inutiles dans le code (le *pourquoi* seulement).
Au minimum : aucun mock de la base ni de l'ORM (sans objet ici : le lot n'a pas de code applicatif) ; ne jamais
modifier le code de production pour faire passer un test ; tous les chemins du script couverts par un test bats
(équivalent de la couverture à 100 % : chaque branche de `case`/`if` a un test) ; pas de `retry` pour masquer une
instabilité ; toutes les commandes passent par `make`.

Contraintes propres au lot (anti-objectifs de la spec) :

- **Aucune valeur de secret** en argument de commande, en sortie, dans un log, sur disque (ni fichier temporaire sur
  le poste ; côté serveur, un répertoire temporaire `umask 077` supprimé par `trap` est toléré comme dans steamy, mais
  jamais l'entrée standard dans un fichier du poste ou de la CI hors `$RUNNER_TEMP` nettoyé en `always()`). Variante
  préférée pour le serveur : lire l'entrée dans une variable ou un tube et passer à `kubectl` par `--from-env-file=/dev/stdin`.
- Le script ne fait **confiance à rien** de `SSH_ORIGINAL_COMMAND` : motif strict, jamais `eval`, jamais de valeur
  interpolée dans un shell.
- Contrats 8.3 à respecter à la lettre : images `ghcr.io/tigamadou/urbankiff-{api,nextjs,panel}` étiquettes
  `sha-<12>`, `<version>` (api), `<version>-<env>` (Next, panel) ; charts `oci://ghcr.io/tigamadou/charts/<nom>`
  (`urbankiff-donnees`, `urbankiff`) ; Secrets `urbankiff-secrets` et `ghcr-pull` ; valeurs `image.etiquette`,
  `secretsChecksum`, `environnement` ; serveur : `/etc/urbankiff/deploy.env` (`URBANKIFF_ENV`, `GHCR_OWNER`,
  `NAMESPACE`), kubeconfig `/home/deploy/.kube/<env>`, script installé en `/usr/local/bin/urbankiff-deploy` ;
  arguments de construction `NEXT_PUBLIC_BACKEND_URL`, `NEXT_PUBLIC_BACKEND_URL_FRONT`, `NEXT_PUBLIC_GOOGLE_CLIENT_ID`,
  `BACKEND_URL` (Next), `REACT_APP_BACKEND_URL`, `REACT_APP_IMAGEKIT_ENDPOINT` (panel). Un contrat à changer : s'arrêter
  et signaler.
- Versions épinglées pour toute image de conteneur utilisée (bats, actionlint, helm, buildx) ; valeurs choisies à la
  tâche concernée, notées dans la doc.
- Le premier déploiement de **prod** est hors mission : le workflow et les cibles le permettent, mais aucun test ni
  aucune étape de ce lot ne déploie dans le namespace `prod`.

## Points de revue

1. Aucune valeur de secret n'apparaît en argument, en sortie ni dans le journal des faux binaires (test à repère
   unique, sur les trois chemins : script serveur, `secrets-cluster`, workflow).
2. Le script refuse tout ce qui n'est pas `deploy <semver>`, `preprod-arret`, `preprod-demarrage` ; pré-release refusée
   quand `URBANKIFF_ENV=prod` ; `preprod-*` refusés hors preprod.
3. Sans entrée standard, aucun appel `kubectl` ne crée, ne modifie ni ne supprime de Secret (test sur le journal du
   faux `kubectl`).
4. `urbankiff-donnees` sans `--atomic`, `urbankiff` avec `--atomic --wait`, dans cet ordre, avec attente de
   CloudNativePG entre les deux.
5. Workflow : permissions minimales, environnement GitHub `prod` pour la release, concurrence par environnement sans
   annulation, secrets seulement sur l'entrée standard du SSH, nettoyage en `always()`, actions épinglées.
6. Cohérence de la liste de clés du script avec `scripts/secrets/secrets.txt` (voir tâche 2 ; le lot `nettoyage` la
   modifie).

---

### Tâche 1 : script serveur, squelette et refus

**Fichiers :**
- Créer : `infra/deploiement/urbankiff-deploy.sh`, `infra/deploiement/tests/deploy-commande.bats`,
  `infra/deploiement/tests/fakes/{kubectl,helm,curl,flock,date}` (faux binaires : journalisent leurs arguments dans
  `$FAKE_LOG`, la longueur de l'entrée standard et jamais son contenu, sur le modèle de `scripts/secrets/tests/fakes/gh`).
- Test : `infra/deploiement/tests/deploy-commande.bats`.

**Interfaces :**
- Consomme : `/etc/urbankiff/deploy.env` (contrat Serveur ; chemin surchargeable par `URBANKIFF_DEPLOY_ENV` pour les
  tests seulement, jamais lu depuis l'environnement SSH : le compte `deploy` est en commande forcée et `restrict`,
  documenter la raison dans la doc), variable `SSH_ORIGINAL_COMMAND`.
- Produit : script `urbankiff-deploy.sh` (codes de sortie : 0 succès, 1 erreur, 2 commande refusée), fonctions `log`
  (stderr, horodatée, sans valeur) et `die`.

- [ ] **Étape 1** : écrire les tests bats, les voir échouer : commande vide, inconnue (`ls`, `deploy`, `deploy 1.0`,
  `deploy 1.0.0; id`, `deploy $(id)`, retour à la ligne), `deploy` sans version, `deploy v1.2.3` (préfixe `v` accepté
  et retiré), pré-release `1.2.3-rc.1` acceptée en preprod et **refusée en prod**, `preprod-arret` et
  `preprod-demarrage` refusés si `URBANKIFF_ENV=prod`, `deploy.env` absent ou incomplet (`URBANKIFF_ENV`, `GHCR_OWNER`,
  `NAMESPACE`) → erreur, `URBANKIFF_ENV` hors `prod|preprod` → erreur, verrou déjà pris (faux `flock` en échec) →
  « un déploiement est déjà en cours », `KUBECONFIG` vaut `~/.kube/<env>` (le contrat Serveur).
- [ ] **Étape 2** : implémenter `set -euo pipefail`, `umask 077`, lecture de la configuration (sans `source` d'un
  fichier non validé : analyse ligne à ligne des trois clés, valeurs `[a-z0-9-]` pour `NAMESPACE`, `[A-Za-z0-9-]`
  pour `GHCR_OWNER`), motif strict `^(deploy v?(X.Y.Z(-pre)?)|preprod-arret|preprod-demarrage)$`, règle prod,
  `flock -n` sur `/var/lock/urbankiff-deploy.lock`.
- [ ] **Étape 3** : relancer, tout vert via `make deploiement-test` (cible créée en tâche 4 ; d'ici là, lancer bats par
  la commande Docker identique à celle de `secrets-test`) ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 2 : script serveur, entrée standard, Secrets, empreinte

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh`.
- Créer : `infra/deploiement/tests/deploy-secrets.bats`.

**Interfaces :**
- Consomme : tâche 1 ; entrée standard facultative `NOM=valeur` (contrat Script), ≤ 64 Ko ; noms de secrets de
  `scripts/secrets/secrets.txt` (après `nettoyage` : `SECRET_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`,
  `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `TWILIO_ACCOUNT_SID`,
  `TWILIO_AUTH_TOKEN`, `SOCIAL_AUTH_GOOGLE_OAUTH2_KEY`, `SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET`,
  `DJANGO_SUPERUSER_PASSWORD`, `WASABI_ACCESS_KEY_ID`, `WASABI_SECRET_ACCESS_KEY`).
- Produit : Secrets `urbankiff-secrets` (clés = noms de l'inventaire) et `ghcr-pull` dans `$NAMESPACE` ; variable
  interne `secretsChecksum` (empreinte SHA-256 tronquée) ; mode « entrée présente / absente ».

- [ ] **Étape 1** : écrire les tests, les voir échouer. Détection de l'entrée : terminal ou tube vide (`[ -t 0 ]` ou
  lecture de 0 octet) = « sans entrée ». Cas : entrée > 64 Ko → refus sans aucun appel à `kubectl` (lire 65537 octets
  au plus et refuser au-delà, pas de troncature silencieuse comme `head -c` de steamy) ; ligne mal formée
  (`minuscule=x`, sans `=`, nom inconnu hors allow-list, valeur contenant un retour chariot) → refus et message qui
  nomme la **ligne** (numéro) mais jamais la valeur ; clé obligatoire absente → refus qui nomme la clé ; clés
  `GHCR_PULL_USER` et `GHCR_PULL_TOKEN` (voir risque en fin de plan) extraites vers `ghcr-pull` et **absentes** de
  `urbankiff-secrets` ; entrée complète → `kubectl create secret generic urbankiff-secrets … --dry-run=client -o yaml |
  kubectl apply -f -` dans le bon namespace, valeurs transmises par `--from-env-file=/dev/stdin` (ou fichier
  `umask 077` supprimé par `trap`), **jamais en argument** ; valeur à repère unique (`Valeur-Repere-Xq7=avec espace`,
  avec `=` et espace, comme le test de `definir-secrets.bats`) : le journal des faux binaires et `$output` ne la
  contiennent jamais, y compris en échec (`set -x` interdit, test qui vérifie que le script n'active jamais `xtrace`) ;
  empreinte : change si une valeur change, stable à contenu identique, indépendante de l'ordre des lignes ; **sans
  entrée** : aucun appel `kubectl create|apply|delete|patch` sur les Secrets, l'empreinte est recalculée à partir de
  `kubectl get secret urbankiff-secrets -o json` (jamais écrite ni affichée), erreur claire si le Secret n'existe pas
  (« premier déploiement : fournir les Secrets, voir `make secrets-cluster` »).
- [ ] **Étape 2** : implémenter. Le message d'erreur ne cite jamais le contenu d'une ligne. `unset` des variables de
  valeurs après usage.
- [ ] **Étape 3** : relancer, tout vert ; cocher l'Avancement ; commit d'une ligne.
- [ ] **Étape 4** (cohérence) : test bats `inventaire-cles.bats` qui compare l'allow-list du script à
  `scripts/secrets/secrets.txt` du dépôt, en tolérant les clés `GHCR_PULL_*`. Si le lot `nettoyage` n'est pas encore
  fusionné dans la base (liste ancienne : `IMGPROXY_*`, sans `WASABI_*`), marquer le test `skip` avec la raison, le
  signaler dans l'issue et le réactiver à la tâche 7 ; ne jamais modifier `scripts/secrets/**`.

---

### Tâche 3 : script serveur, charts, déploiements, santé, preprod

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh`.
- Créer : `infra/deploiement/tests/deploy-helm.bats`, `infra/deploiement/tests/deploy-preprod.bats`.

**Interfaces :**
- Consomme : tâche 2 ; charts `oci://ghcr.io/$GHCR_OWNER/charts/{urbankiff-donnees,urbankiff}` (contrat Charts) avec
  `values-$URBANKIFF_ENV.yaml` ; valeurs `image.etiquette`, `secretsChecksum`, `environnement` ; annotation
  CloudNativePG `cnpg.io/hibernation` (hibernation preprod) ; URL de santé `https://<hôte api>/api/health/` où l'hôte
  est lu dans l'`Ingress` du namespace (`kubectl get ingress -o jsonpath`), pas dans l'entrée utilisateur.
- Produit : commandes `deploy`, `preprod-arret`, `preprod-demarrage` complètes ; code de sortie non nul si la santé
  échoue.

- [ ] **Étape 1** : écrire les tests, les voir échouer. Ordre des appels du journal : `helm registry login`
  (jeton lu sur l'entrée de `--password-stdin`, `HELM_REGISTRY_CONFIG` dans le répertoire temporaire ; sans entrée
  standard : jeton relu du Secret `ghcr-pull`) → `helm pull` des deux charts à la version demandée (échec → « chart
  introuvable », arrêt avant tout `upgrade`) → `helm upgrade --install urbankiff-donnees` **sans** `--atomic` mais avec
  `--wait` → `kubectl wait cluster.postgresql.cnpg.io/… --for=condition=Ready` → `helm upgrade --install urbankiff`
  avec `--atomic --wait --timeout` et `--set image.etiquette=<version>`, `--set secretsChecksum=<empreinte>`,
  `--set environnement=<env>`. Si l'attente de CloudNativePG échoue : l'application n'est pas déployée. Santé : faux
  `curl` qui échoue deux fois puis réussit → succès ; échec permanent → sortie non nulle après au plus 2 minutes (faux
  `date`/`sleep` pour ne pas attendre vraiment). `preprod-arret` : `kubectl scale --replicas=0` des Deployments et
  StatefulSets applicatifs du namespace `preprod` (sélection par label du chart, à confirmer avec le lot `charts` sinon
  signaler) et annotation `cnpg.io/hibernation=on` du `Cluster` ; `preprod-demarrage` : l'inverse (`off`, puis remise à
  l'échelle de ce qui avait été arrêté ; pour retrouver les valeurs d'origine, annoter chaque ressource à l'arrêt avec
  `urbankiff.com/replicas-avant`). Aucune suppression de PVC ni de Secret (test sur le journal). Idempotence :
  `preprod-arret` répété ne change rien.
- [ ] **Étape 2** : implémenter. Un seul `trap` nettoie le répertoire temporaire ; messages `log` sans valeur.
- [ ] **Étape 3** : relancer, tout vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 4 : poste, `make/deploiement.mk`

**Fichiers :**
- Créer : `make/deploiement.mk`, `infra/deploiement/tests/make-deploiement.bats`, `infra/deploiement/tests/fakes/{docker,gh,ssh}`
  (les faux journalisent les arguments, la longueur de l'entrée, jamais le contenu ; ne pas dupliquer dans
  `scripts/secrets/tests/fakes`, lecture seule).
- Test : `infra/deploiement/tests/make-deploiement.bats` (lance `make -n` et `make` avec `PATH` des faux).

**Interfaces :**
- Consomme : `Makefile` du socle (inclusion de `make/deploiement.mk`) ; contrat Images (étiquettes, constructions
  `linux/amd64`) ; arguments de construction des fronts ; variables GitHub de l'environnement lues par
  `gh variable list --env <env> --repo <depot> --json name,value` ; clé de déploiement du poste (agent SSH
  `SSH_AUTH_SOCK`, hôte `DEPLOY_HOST` lu dans les variables GitHub de l'environnement, `DEPLOY_KNOWN_HOSTS`).
- Produit : cibles (toutes avec ligne `##` d'aide et validation d'usage code 2, comme `secrets-definir`) :
  - `images-publier VERSION=<v> ENV=<prod|preprod>` : connexion à GHCR avec le jeton de `gh` (par entrée standard,
    jamais en argument) ; `buildx --platform linux/amd64` ; **api construite une fois** sous `sha-<12>` et `<version>`
    (pré-release) puis, pour une release, **réétiquetage** de l'image de la pré-release validée par
    `docker buildx imagetools create --tag` (même digest, refus s'il n'existe pas d'image `sha-<12>` du commit) ; Next
    et panel **par environnement** avec les variables de l'environnement GitHub passées en `--build-arg`, étiquetés
    `<version>-<env>` ; une variable de construction absente de l'environnement → échec nommé, avant tout build ;
  - `charts-publier VERSION=<v>` : `helm package --version --app-version` puis `helm push` OCI vers
    `oci://ghcr.io/tigamadou/charts` (helm en conteneur épinglé, `infra/helm/{urbankiff-donnees,urbankiff}` en lecture
    seule) ;
  - `deploiement ENV=<env> VERSION=<v>` : `ssh deploy@<hôte> "deploy <version>"` **sans entrée** (`< /dev/null`, avec
    `-o IdentitiesOnly=yes -o StrictHostKeyChecking=yes` et le fichier de hôtes connus) ; ne publie rien lui-même ;
  - `secrets-cluster ENV=<env>` : lit la liste des noms dans `scripts/secrets/secrets.txt` (lecture seule) et, pour
    chaque nom, la valeur en **saisie masquée** (`read -rs` sur `/dev/tty`, surchargeable par `SECRETS_TTY` pour les
    tests, comme `definir-secrets.sh`) ; construit le flux `NOM=valeur` **dans un tube** vers l'entrée standard de
    `ssh … "deploy <version>"` (donc la cible prend aussi `VERSION=`), sans fichier, sans export, sans argument ;
    saisie vide = nom omis ; saisie interrompue → rien n'est envoyé ;
  - `preprod-arret`, `preprod-demarrage` : `ssh deploy@<hôte> "preprod-arret"` (resp. `preprod-demarrage`) avec la clé
    et l'hôte de la preprod ;
  - `deploiement-test` : bats en conteneur (comme `secrets-test`) sur `infra/deploiement/tests` ; `deploiement-lint` :
    `shellcheck` en conteneur épinglé sur `infra/deploiement/urbankiff-deploy.sh` ; `workflow-lint` : actionlint (tâche 5).

- [ ] **Étape 1** : écrire les tests, les voir échouer : usage invalide → code 2 sans appel aux faux ; `images-publier`
  ENV=preprod construit api, Next et panel avec les bonnes étiquettes et `--platform linux/amd64` ; ENV=prod ne
  construit **pas** l'api mais crée l'étiquette `<version>` par `imagetools create`, construit Next et panel avec
  `<version>-prod` ; variable manquante → échec avant build ; le jeton `gh auth token` n'apparaît pas dans les
  arguments du faux docker (connexion par `--password-stdin`) ; `secrets-cluster` : repère unique absent de tous les
  journaux et de `$output`, longueur reçue sur l'entrée du faux ssh égale à celle attendue, aucun fichier créé dans
  `$BATS_TEST_TMPDIR` ni dans le dépôt (`git status --porcelain` vide), interruption → faux ssh non appelé ;
  `deploiement` : entrée du faux ssh vide, commande exacte `deploy <version>` ; `preprod-*` : commande exacte.
- [ ] **Étape 2** : implémenter. Les cibles lisent les valeurs du projet (dépôt `tigamadou/urbankiff`, propriétaire GHCR)
  dans des variables Make en tête de fichier, pas ailleurs. Images utilisées : `docker`, `helm`, `shellcheck` à
  versions épinglées.
- [ ] **Étape 3** : relancer, tout vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 5 : workflow `deploiement.yml`

**Fichiers :**
- Créer : `.github/workflows/deploiement.yml`.
- Test : `make workflow-lint` (actionlint épinglé en conteneur : `rhysd/actionlint` à version fixe, monté en lecture
  seule sur `.github/workflows/`) ; un test bats `workflow.bats` qui vérifie par `grep` les invariants (pas de
  `${{ secrets.* }}` dans une ligne `run:` ou dans `env:` d'une étape autre que « secrets → entrée standard », jamais de
  `set -x`, `if: always()` sur le nettoyage, actions épinglées par version).

**Interfaces :**
- Consomme : `make images-publier`, `make charts-publier` (mêmes cibles que le poste, pour un seul chemin de
  construction) ; secrets et variables GitHub des environnements `prod` et `preprod` (`DEPLOY_SSH_KEY`,
  `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS`, les 14 secrets de l'inventaire, `WASABI_*`) ; contrat Script.
- Produit : workflow `release: [prereleased, released]`.

- [ ] **Étape 1** : écrire le test des invariants et lancer actionlint sur un workflow vide pour voir l'échec.
- [ ] **Étape 2** : implémenter, dans le style de `devteam-ci.yml` (commentaire d'en-tête, `name`, `concurrency`) et sur
  le modèle de steamy : job `meta` (tag `vX.Y.Z[-rc.N]`, pré-release → `preprod`, release → `prod`, release portant un
  suffixe refusée, sortie `version`, `environnement`, `sha`) ; job `images` (`packages: write`, étiquette `sha-<12>`,
  api construite une fois ou réétiquetée, Next et panel par environnement, via `make images-publier`) ; job `charts`
  (`make charts-publier`) ; job `deployer` : `needs: [meta, images, charts]`, `environment` de l'environnement
  calculé (donc approbation du développeur pour `prod`), `concurrency.group: deploiement-<env>` avec
  `cancel-in-progress: false`, `timeout-minutes`, clé SSH écrite dans `$RUNNER_TEMP` en `0600` (secret passé par `env:`
  de cette seule étape), secrets de l'environnement envoyés par un tube dans `ssh … "deploy $VERSION"` **sans fichier
  intermédiaire** (si inévitable : `$RUNNER_TEMP`, `umask 077`) ; étape `Nettoyage` en `if: always()` supprimant la clé
  et tout fichier de secrets ; `permissions: contents: read` partout, `packages: write` sur les jobs qui publient ;
  refus d'un déploiement `prod` si l'image `sha-<12>` n'existe pas (pas de reconstruction de l'api en prod) ; jamais
  de `pull_request_target`.
- [ ] **Étape 3** : `make workflow-lint` et `make deploiement-test` verts ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 6 : documentation

**Fichiers :**
- Créer : `docs/v1/infra/deploiement.md`.

**Interfaces :**
- Consomme : tâches 1 à 5 ; contrats 8.3.
- Produit : document en français, accents, sections : vue d'ensemble (schéma CI/poste), commande forcée et commandes
  acceptées, tableau CI/poste (§ 5.8), premier déploiement d'un environnement (secrets par la CI ou `make
  secrets-cluster`), déploiement courant, rollback (`--atomic`, redéploiement de la version précédente, `helm rollback`),
  règle des migrations N-1, preprod à la demande, secrets et variables requis par environnement (liste de
  `scripts/secrets/secrets.txt` renvoyée, pas recopiée), prérequis posés par le développeur à la mise en service
  (`DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS`, environnement GitHub `prod` avec approbation, jeton GHCR),
  dépannage, cibles `make` et tests.

- [ ] **Étape 1** : rédiger ; chaque commande citée existe (vérifier avec `make -n`) ; aucune valeur réelle de secret,
  d'hôte ou de clé dans le texte (`make secrets-scan` en tâche 7).
- [ ] **Étape 2** : cocher l'Avancement ; commit d'une ligne.

---

### Tâche 7 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make deploiement-test`, `make deploiement-lint` (shellcheck) et `make workflow-lint` verts.
- [ ] Réactiver le test de cohérence des clés (tâche 2, étape 4) si le lot `nettoyage` est fusionné ; sinon le signaler.
- [ ] `make lint` et `make typecheck` verts (inchangés : le lot ne touche aucune application) ; `make secrets-test` vert
  (aucune régression sur les outils de secrets).
- [ ] `make secrets-scan` : zéro détection.
- [ ] `make -n images-publier VERSION=0.0.0-rc.1 ENV=preprod`, `make -n charts-publier VERSION=0.0.0-rc.1`,
  `make -n deploiement ENV=preprod VERSION=0.0.0-rc.1` : les cibles existent et s'expandent sans erreur.
- [ ] Couverture : tous les chemins du script (chaque refus, chaque branche) ont un test bats ; la couverture de ligne
  de code applicatif est sans objet. `make coverage-diff BASE=feature/k3s-ansible` : sans objet (aucun fichier
  d'application modifié), à noter dans le rapport.
- [ ] `make check-generated` et `make migrations-check` : sans objet pour ce lot (aucune migration ni génération) ;
  e2e : sans objet (aucun test e2e pour l'instant).
- [ ] Périmètre : `make devteam-perimetre LOT=deploiement PLAN=docs/v1/plans/k3s-ansible/7-deploiement.md BASE=origin/feature/k3s-ansible` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler.
