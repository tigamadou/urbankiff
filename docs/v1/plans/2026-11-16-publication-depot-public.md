# Publication du dépôt en public et rotation des secrets — Plan d'implémentation

> **Pour les agents d'exécution** : skill requis `superpowers:subagent-driven-development` (recommandé) ou
> `superpowers:executing-plans`, tâche par tâche. Les étapes utilisent la syntaxe à cases `- [ ]`.

**Objectif** : publier `tigamadou/urbankiff` à partir d'un instantané sans secret, l'ancien dépôt restant privé en
archive, avec tous les secrets inventoriés, révoqués et redéfinis dans les environnements GitHub.

**Architecture** : préparation sur une branche de l'ancien dépôt (outillage, inventaire, nettoyage, scan), puis
instantané en un commit poussé dans un nouveau dépôt public, configuré ensuite par `gh` ; les opérations sur GitHub
et sur les serveurs sont faites ou autorisées par le développeur.

**Stack** : bash, bats, Docker, gitleaks, `gh`, Make.

**Spec** : `docs/v1/specs/2026-11-16-publication-depot-public.md` (elle fait autorité).

## Exécution

- **Mission** : sans objet (plan séquentiel hors mission devteam) · **Issue** : aucune
- **Branche** : `chore/publication`, dans un worktree `../urbankiff-wt-publication` · **Base** : `development`
- Toutes les commandes passent par `make` ou un conteneur ; sur l'hôte : `docker`, `make`, `git`, `gh` seulement.
- Aucun commit sans demande explicite du développeur, sauf le commit initial de l'instantané (tâche 6), qui est
  l'objet même de la tâche. Jamais de `--force`, jamais de `--no-verify`, aucune mention d'IA.
- Les étapes marquées **(développeur)** ne sont pas exécutées par l'agent : il s'arrête, donne la commande ou la
  procédure, et attend la confirmation. Cela couvre toute connexion SSH aux serveurs, toute console de fournisseur,
  le renommage et le changement de visibilité des dépôts, et toute création ou suppression hors du dossier du projet.
- **Aucune valeur de secret** ne doit apparaître dans un terminal, un log, un argument de commande, un fichier commité
  ou un message.

## Contraintes globales

- Noms GitHub des secrets = noms des variables lues par le code, définis par environnement `prod` et `preprod`.
- Dépôt d'archive : `tigamadou/urbankiff-archive`, privé. Dépôt public : `tigamadou/urbankiff`, branche par défaut
  `development`, branches `development` et `main` sur le même commit initial « chore: initial public snapshot ».
- Images épinglées : `alpine:3.20` (génération), gitleaks à version fixe (choisie à la tâche 4), `instrumentisto/nmap`
  à version fixe (tâche 5).
- Les données de prod (base PostgreSQL de B, volumes MinIO de A) ne sont jamais supprimées.
- Aucun runner auto-hébergé sur le dépôt public.

## Points de revue

1. Un secret dont la saisie est vide ou interrompue (Ctrl-C) ne laisse ni valeur partielle dans GitHub ni trace sur
   disque : test `saisie interrompue → rien n'est posé` (tâche 1).
2. Une valeur générée contenant des caractères spéciaux est posée intacte : test `valeur avec = et espace posée
   intacte` (tâche 1).
3. Le script lancé avec un `ENV` inconnu ou un `REPO` vide échoue avant tout appel à `gh` : test dédié (tâche 1).
4. Un nom présent dans `secrets.txt` mais absent de l'inventaire Markdown fait échouer les tests : test de cohérence
   (tâche 2).
5. Le panel démarre sans aucune variable Firebase définie : test `base.js sans configuration` (tâche 3).

## Avancement

Statut : 🟡 en cours (tâches 1 à 7 ✅ le 2026-11-16) · Prochaine tâche : 8 (révocations, après la saisie des vraies valeurs)

- [x] **Tâche 1** Script de définition des secrets
- [x] **Tâche 2** Inventaire et runbook
- [x] **Tâche 3** Nettoyage de l'arbre
- [x] **Tâche 4** Scan gitleaks
- [x] **Tâche 5** Mesures conservatoires sur A et B (développeur)
- [x] **Tâche 6** Instantané et nouveau dépôt public
- [x] **Tâche 7** Configuration GitHub et rotation (2026-11-16)
- [ ] **Tâche 8** Révocations chez les fournisseurs (développeur)
- [ ] **Tâche 9** Clones locaux et vérification finale

> Reprise : 2026-11-16, branche chore/publication du checkout principal, rien de commité. Tâches 1 à 4 faites, revue finale corrigée (FCM, prodseed, idempotence, journal Docker, inventaire, Caddy). Tâche 5 : A et B terminés le 2026-11-16 (services arrêtés, pare-feu 22 seul, connexion SSH par mot de passe désactivée, clé de déploiement retirée), projet Firebase supprimé : tâche 5 terminée. Tâche 6 : instantané publié le 2026-11-16 (tigamadou/urbankiff public, archive privée). Tâche 7 : environnements prod et preprod créés, 14 secrets et 18 variables chacun, development et main protégées (ci-ok, enforce_admins). GitHub Actions bloqué un temps : ci-ok retiré puis rétabli le 2026-11-16 une fois Actions revenu ; la PR d essai est remplacée par les PR de la mission k3s-ansible (#19 à #35), toutes avec ci-ok vert sur un runner GitHub : tâche 7 terminée. Les valeurs des fournisseurs (SMTP, Twilio, Google) restent provisoires : elles sont saisies avant la tâche 8.

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après vérification verte**.

## Fichiers du lot (exclusifs)

- `scripts/secrets/**` [nouveau]
- `make/secrets.mk` [nouveau]
- `Makefile` (inclusion de `make/secrets.mk`, retrait de `uploadDeploys`)
- `.gitleaks.toml` [nouveau]
- `docs/v1/infra/**` [nouveau]
- `apps/panel/src/firebase/base.js`
- `apps/panel/src/firebase/base.test.js` [nouveau]
- `apps/api/env.prod`, `apps/api/env.preprod`, `apps/minio/.env.prod`, `apps/minio/.env.preprod`,
  `apps/panel/.env.prod`, `apps/panel/.env.preprod`, `apps/nextjs/env.prod`, `apps/nextjs/env.preprod` (supprimés)
- `.github/workflows/*-deploy-to-*.yml` (supprimés)
- `.claude/INCIDENT-2026-05-31-nextjs-compromise.md` (supprimé)
- `docs/v1/plans/2026-11-16-publication-depot-public.md` (ce plan : Avancement)

## Fichiers en lecture seule

`apps/**` hors des fichiers listés ci-dessus, `docker-compose.yml`, `compose.agent.yml`, `devteam.agent.conf`,
`.github/workflows/devteam-ci.yml`, `deploys/**`, `caddyprod/**`, `.claude/devteam.projet.md`.

---

### Tâche 1 : script de définition des secrets

**Fichiers :**
- Créer : `scripts/secrets/definir-secrets.sh`, `scripts/secrets/secrets.txt`,
  `scripts/secrets/variables-prod.txt`, `scripts/secrets/variables-preprod.txt`, `make/secrets.mk`
- Test : `scripts/secrets/tests/definir-secrets.bats`, `scripts/secrets/tests/fakes/gh`
- Modifier : `Makefile` (ajout de `-include make/secrets.mk`)

**Interfaces :**
- Produit :
  - `scripts/secrets/secrets.txt` : une ligne par secret, `NOM TYPE`, TYPE ∈ `aleatoire:<longueur>`,
    `aleatoire-hex:<longueur>`, `saisie`. Contenu (spec § 5.1) : `SECRET_KEY aleatoire:64`,
    `POSTGRES_PASSWORD aleatoire:40`, `REDIS_PASSWORD aleatoire:40`, `MINIO_ROOT_USER aleatoire:20`,
    `MINIO_ROOT_PASSWORD aleatoire:40`, `IMGPROXY_KEY aleatoire-hex:64`, `IMGPROXY_SALT aleatoire-hex:64`,
    `SMTP_USERNAME saisie`, `SMTP_PASSWORD saisie`, `TWILIO_ACCOUNT_SID saisie`, `TWILIO_AUTH_TOKEN saisie`,
    `SOCIAL_AUTH_GOOGLE_OAUTH2_KEY saisie`, `SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET saisie`.
  - `scripts/secrets/variables-<env>.txt` : `NOM=valeur` non secrètes, reprises des anciens `env.<env>` (hors
    secrets) : `POSTGRES_USER`, `POSTGRES_DB`, `ALLOWED_HOSTS`, `WEB_URL`, `API_URL`, `MINIO_ENDPOINT`,
    `MINIO_DEFAULT_BUCKETS`, `FILES_CDN_ENDPOINT`, `SMTP_SERVER`, `SMTP_PORT`, `DJANGO_ENV`,
    `NEXT_PUBLIC_BACKEND_URL`, `BACKEND_URL`, `NEXT_PUBLIC_BACKEND_URL_FRONT`, `NEXT_PUBLIC_GOOGLE_CLIENT_ID`,
    `REACT_APP_BACKEND_URL`, `REACT_APP_BASENAME`.
  - `definir-secrets.sh <env> <repo>` (variable `SEULEMENT="N1 N2"` facultative ; `GENERATEUR` facultative, commande
    qui reçoit `<type> <longueur>` et écrit la valeur sur sa sortie, par défaut un `docker run --rm alpine:3.20` avec
    `openssl rand`) ; code 0 si tous les noms attendus sont présents dans `gh secret list` et `gh variable list` de
    l'environnement, 1 sinon, 2 pour un usage invalide.
  - `make secrets-definir ENV=<prod|preprod> REPO=<owner/nom>`, `make secrets-test`.

- [ ] **Étape 1** : écrire `definir-secrets.bats` avec un faux `gh` (`tests/fakes/gh`) qui journalise ses arguments
  et la **longueur** de son entrée standard dans un fichier du dossier temporaire du test, et répond à `secret list` /
  `variable list` avec les noms posés. Tests :
  - `usage invalide → code 2 sans appel à gh` (ENV `staging`, REPO vide) ;
  - `chaque secret aleatoire est pose avec --env et --repo` ;
  - `aucune valeur n'apparait en argument ni en sortie` (GENERATEUR de test renvoyant une valeur repère ; la valeur
    repère n'est ni dans le journal des arguments ni dans la sortie du script) ;
  - `valeur avec = et espace posee intacte` (longueur reçue par le faux `gh` = longueur de la valeur) ;
  - `saisie vide → secret laisse tel quel` ;
  - `saisie interrompue → rien n'est pose` (EOF sur l'entrée standard pendant une saisie) ;
  - `SEULEMENT limite les secrets definis` ;
  - `variables posees avec gh variable set` ;
  - `nom attendu absent de gh secret list → code 1`.
- [ ] **Étape 2** : `make secrets-test` (bats dans un conteneur, comme `devteam-test`) ; attendu : les tests
  échouent (script absent).
- [ ] **Étape 3** : écrire `definir-secrets.sh` : valeurs transmises à `gh secret set <NOM> --env <env> --repo <repo>`
  par tube, jamais en argument ni exportées ; saisie par `read -rs` depuis `/dev/tty` (surchargeable pour les tests) ;
  `set -euo pipefail`.
- [ ] **Étape 4** : `make secrets-test` vert ; `make -n secrets-definir ENV=prod REPO=x/y` affiche la commande.
- [ ] **Étape 5** : cocher l'Avancement.

### Tâche 2 : inventaire et runbook

**Fichiers :**
- Créer : `docs/v1/infra/secrets.md`, `docs/v1/infra/rotation-secrets.md`
- Test : ajout au fichier `scripts/secrets/tests/definir-secrets.bats`

**Interfaces :**
- Consomme : `scripts/secrets/secrets.txt`, `scripts/secrets/variables-*.txt` (tâche 1).

- [ ] **Étape 1** : test `chaque nom de secrets.txt et des fichiers de variables figure dans docs/v1/infra/secrets.md`
  et `aucune valeur ne figure dans les docs` (aucune ligne `NOM=` suivie d'une valeur dans `docs/v1/infra/`) ; le voir
  échouer.
- [ ] **Étape 2** : écrire `secrets.md` : le tableau de la spec § 5.1 (noms, environnements, usage, emplacement
  actuel, révocation, génération), plus les variables, la ligne Firebase, la ligne `BUCKETEER_AWS_*` obsolète, les
  valeurs de développement local et la règle « aucune réutilisation en prod ».
- [ ] **Étape 3** : écrire `rotation-secrets.md` : ordre des opérations (tâches 5 à 9 de ce plan), une case datée par
  révocation, procédure de chaque console (Twilio : régénérer le jeton d'authentification ; fournisseur SMTP : révoquer
  et recréer le jeton ; Google Cloud : réinitialiser le secret client OAuth ; Firebase : supprimer le projet), commandes
  serveur des mesures conservatoires (tâche 5).
- [ ] **Étape 4** : `make secrets-test` vert ; cocher l'Avancement.

### Tâche 3 : nettoyage de l'arbre

**Fichiers :**
- Supprimer : les 8 fichiers `env.prod`/`env.preprod` et `.env.prod`/`.env.preprod` listés dans « Fichiers du lot »,
  les 8 workflows `.github/workflows/*-deploy-to-*.yml`, `.claude/INCIDENT-2026-05-31-nextjs-compromise.md`
- Modifier : `apps/panel/src/firebase/base.js`, `Makefile` (cible `uploadDeploys` retirée)
- Test : `apps/panel/src/firebase/base.test.js`

**Interfaces :**
- Produit : `apps/panel/src/firebase/base.js` exporte `firebaseActif: boolean` (vrai seulement si
  `REACT_APP_FIREBASE_PROJECT_ID` est défini), et `db`, `auth`, `postsRef`, `categoriesRef`, `usersRef`, `menusRef`
  valant `null` quand `firebaseActif` est faux.

- [ ] **Étape 1** : test Jest `base.js sans configuration` : sans aucune variable `REACT_APP_FIREBASE_*`, l'import ne
  lève pas d'erreur, `firebaseActif === false` et `menusRef === null`.
- [ ] **Étape 2** : `make test-cible T=apps/panel/src/firebase` rouge.
- [ ] **Étape 3** : modifier `base.js` : configuration lue dans `process.env.REACT_APP_FIREBASE_*`, initialisation
  seulement si `firebaseActif`. Les écrans qui l'utilisent ne sont pas modifiés (portage : chantier séparé, spec § 9).
- [ ] **Étape 4** : supprimer les fichiers et la cible listés.
- [ ] **Étape 5** : `make test-cible T=apps/panel/src` vert ; `make lint-panel` vert ; `git grep -nE
  'env\.prod|env\.preprod|uploadDeploys'` ne trouve plus que la spec, ce plan et les docs d'infra ; cocher
  l'Avancement.

### Tâche 4 : scan gitleaks

**Fichiers :**
- Créer : `.gitleaks.toml`
- Modifier : `make/secrets.mk` (cible `secrets-scan`)

**Interfaces :**
- Produit : `make secrets-scan` (scan de l'arbre de travail, conteneur gitleaks épinglé, sortie sans les valeurs
  trouvées : option de masquage) ; `make secrets-scan-historique DOSSIER=<dépôt>` (scan de l'historique git d'un dépôt).

- [ ] **Étape 1** : `make secrets-scan` sur l'état courant ; relever les constats (noms de fichiers et règles,
  valeurs masquées).
- [ ] **Étape 2** : pour chaque constat : soit le fichier relève du nettoyage (retour à la tâche 3, puis noter dans
  « Reprise »), soit c'est une valeur de développement local (`.env.template`, `apps/api/.env.temp`,
  `apps/panel/.env.development`, `apps/nextjs/env.example`, `configs/pgadmin/pgpass`, README) : exception dans
  `.gitleaks.toml` par chemin, avec un commentaire de justification.
- [ ] **Étape 3** : `make secrets-scan` : zéro constat ; cocher l'Avancement.

### Tâche 5 : mesures conservatoires sur A et B (développeur)

**Fichiers :** `docs/v1/infra/rotation-secrets.md` (cases cochées) ; `make/secrets.mk` (cible `ports-scan`).

**Interfaces :**
- Produit : `make ports-scan HOTE=<ip ou nom>` (nmap en conteneur, ports TCP 1 à 65535, liste des ports ouverts).

- [ ] **Étape 1** : ajouter `ports-scan` ; `make ports-scan HOTE=<A>` et `HOTE=<B>` : relever l'état de départ.
- [ ] **Étape 2 (développeur)** : sur A, arrêter les conteneurs applicatifs de prod et de preprod et Redis, sans
  supprimer les volumes MinIO ; pare-feu limité à 22, 80 et 443.
- [ ] **Étape 3 (développeur)** : sur B : sauvegarde complète `pg_dump` copiée hors des serveurs ; port PostgreSQL
  ouvert à l'IP de A seulement ; mot de passe de l'utilisateur applicatif changé (`ALTER ROLE`) pour une valeur
  aléatoire conservée par le développeur dans son gestionnaire de mots de passe : elle servira à l'export de la
  mission k3s et n'est **pas** le `POSTGRES_PASSWORD` de GitHub.
- [ ] **Étape 4 (développeur)** : sur A et B, retirer les anciennes clés de déploiement de `authorized_keys` et
  vérifier qu'aucune clé inconnue n'y figure.
- [ ] **Étape 5** : `make ports-scan` sur A et B : A n'expose que 22, 80, 443 ; B n'expose que 22 (PostgreSQL filtré
  depuis l'extérieur) ; cocher le runbook et l'Avancement.

### Tâche 6 : instantané et nouveau dépôt public

**Interfaces :**
- Consomme : branche `chore/publication` à jour des tâches 1 à 5, `make secrets-scan` à zéro.
- Produit : dépôt local `../urbankiff-public` (création autorisée par le développeur), un commit
  « chore: initial public snapshot » sur `development` et `main`.

- [ ] **Étape 1** : `make secrets-scan` à zéro sur `chore/publication`.
- [ ] **Étape 2 (autorisation du développeur pour écrire hors du projet)** : `git archive chore/publication` extrait
  dans `../urbankiff-public`, `git init -b development`, un commit avec l'identité git du développeur, branche `main`
  sur le même commit.
- [ ] **Étape 3** : `make secrets-scan-historique DOSSIER=../urbankiff-public` : zéro constat ;
  `git -C ../urbankiff-public rev-list --count --all` = 1.
- [ ] **Étape 4 (développeur)** : renommer `tigamadou/urbankiff` en `tigamadou/urbankiff-archive` (privé).
- [ ] **Étape 5 (développeur)** : créer `tigamadou/urbankiff`, y pousser `development` et `main`, branche par défaut
  `development`, puis le passer en public.
- [ ] **Étape 6** : cocher l'Avancement.

### Tâche 7 : configuration GitHub et rotation

- [ ] **Étape 1** : activer l'analyse de secrets et la protection au push (`gh api -X PATCH repos/tigamadou/urbankiff`
  avec `security_and_analysis`) ; vérifier par `gh api repos/tigamadou/urbankiff -q .security_and_analysis`.
- [ ] **Étape 2** : créer les environnements `preprod` et `prod` (`gh api -X PUT
  repos/tigamadou/urbankiff/environments/<env>`) ; `prod` : relecteur obligatoire = le développeur, déploiements
  limités aux tags `v*`.
- [ ] **Étape 3 (développeur, au terminal)** : `make secrets-definir ENV=preprod REPO=tigamadou/urbankiff`, puis
  `ENV=prod` ; attendu : code 0.
- [ ] **Étape 4** : protection de `development` et `main` : check requis `ci-ok`, pas de force push, pas de
  suppression (`gh api -X PUT …/branches/<branche>/protection`) ; commande montrée au développeur et lancée avec son
  accord.
- [ ] **Étape 5** : PR d'essai (modification de `README.md`) : `devteam-ci.yml` tourne sur un runner GitHub et `ci-ok`
  est requis et vert ; PR fermée sans fusion ; cocher l'Avancement.

### Tâche 8 : révocations chez les fournisseurs (développeur)

- [ ] **Étape 1 (développeur)** : Twilio, fournisseur SMTP, Google OAuth : révoquer les anciennes valeurs, en suivant
  le runbook (les nouvelles ont été saisies à la tâche 7).
- [ ] **Étape 2 (développeur)** : supprimer le projet Firebase.
- [ ] **Étape 3** : runbook entièrement coché et daté ; cocher l'Avancement.

### Tâche 9 : clones locaux et vérification finale

- [ ] **Étape 1 (développeur)** : sauvegarder les `.env` locaux non versionnés du checkout actuel ; renommer le
  checkout actuel en dossier d'archive ; cloner `tigamadou/urbankiff` dans `/Users/amadou/Devs/projects/urbankiff` ;
  restaurer les `.env`.
- [ ] **Étape 2** : dans le nouveau clone : `make stack-check` après `make start`, `bash
  <plugin>/outils/diagnostic.sh <racine>` sort en 0.
- [ ] **Étape 3** : critères de fin de la spec (§ 7) vérifiés un par un, avec la commande et son résultat.
- [ ] **Étape 4** : rapport final `Statut: DONE|PARTIAL|BLOCKED`, tâches, commandes et résultats, choix signalés ;
  cocher l'Avancement.
