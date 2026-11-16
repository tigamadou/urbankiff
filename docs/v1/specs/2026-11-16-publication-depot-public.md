# Urbankiff : publication du dépôt en public et rotation des secrets

> Spec rédigée le 2026-11-16, validée par le développeur le 2026-11-16. Préalable à la mission k3s (« un cluster k3s, Ansible,
> secrets dans GitHub »), qui partira du dépôt public produit ici. Exécution **séquentielle**, par un plan dédié
> (`docs/v1/plans/2026-11-16-publication-depot-public.md`), pas par une mission devteam : la publication est une
> opération ponctuelle et coordonnée qui ne se découpe pas en lots parallèles.

## 1. Intention

Urbankiff passe son dépôt en **public** pour deux raisons :

- la mission k3s range **tous** les secrets dans GitHub (secrets et variables) : plus rien de sensible ne doit vivre
  dans le dépôt ;
- un dépôt public débloque ce que la formule GitHub Free refuse aux dépôts privés : minutes GitHub Actions gratuites
  sur les runners standards (la CI est bloquée par la facturation depuis le 2026-11-15), protection de branche (check
  `ci-ok` imposé), environnements GitHub avec approbation, analyse de secrets et protection au push.

Contexte de sécurité : le serveur applicatif A a été compromis (mai 2026) et le Redis de prod, publié sur le port
6380 de l'hôte sans mot de passe, a été infecté par un ver. **Tous les secrets actuels sont considérés comme volés**,
publication ou pas.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs**

1. Un dépôt public `tigamadou/urbankiff` dont **aucun commit** ne contient de secret, garanti par construction et
   vérifié par un scanner.
2. L'ancien dépôt conservé **privé**, intact (historique, issues, 51 PR), comme archive.
3. Un **inventaire complet des secrets** : usage, emplacement actuel, révocation de l'ancienne valeur, génération de la
   nouvelle, destination GitHub.
4. Un **script** qui génère les valeurs aléatoires et les pose dans GitHub sans jamais les afficher, et demande les
   valeurs des fournisseurs externes en saisie masquée.
5. Toutes les anciennes valeurs **révoquées** ; toutes les nouvelles valeurs **dans GitHub**, rangées par
   environnement (`prod`, `preprod`).
6. Le dépôt public configuré : branche par défaut `development`, protection de `development` et `main` (check
   `ci-ok`), environnements `prod` (approbation du développeur) et `preprod`, analyse de secrets et protection au push
   activées.
7. Des **mesures conservatoires** sur les serveurs actuels tant que la mission k3s n'a pas reconstruit A : plus aucun
   service publié hors 22, 80 et 443.

**Non-objectifs**

- Reconstruire les serveurs, installer k3s, migrer les données : mission k3s.
- Corriger le code qui envoie des clés au navigateur (voir § 8) : mission k3s.
- Remettre en service la prod ou la preprod actuelles (la prod est arrêtée : `urbankiff.com` et `api.urbankiff.com`
  répondent 502 le 2026-11-16).

**Anti-objectifs** (échec même si « ça marche »)

- Un secret réel, même ancien, lisible dans le dépôt public, dans un commit, une PR ou une issue.
- Une valeur de secret affichée dans un terminal, un log CI, une commande, un fichier commité ou une conversation.
- Une donnée de prod perdue : la base sur B et les fichiers MinIO sur A doivent rester intacts pour la migration de la
  mission k3s.

## 3. Contraintes

- Le développeur est seul sur le dépôt ; aucun fork (`forks_count=0`). Les clones locaux sont les siens et ceux des
  sessions Claude (worktrees).
- La prod est arrêtée : la rotation ne coupe aucun service en fonctionnement.
- Les données de prod (base PostgreSQL sur B, objets MinIO sur A) ne sont pas touchées, seulement mises à l'abri.
- Toute action sur GitHub qui change la visibilité, renomme un dépôt, ou toute connexion SSH aux serveurs est
  **lancée ou autorisée explicitement par le développeur** au moment de l'exécuter.
- Outillage : seulement `docker`, `make`, `git` et `gh` sur l'hôte (contrat devteam, point 1) ; les générateurs
  (`openssl`, `ssh-keygen`) et le scanner tournent en conteneur.
- Sur un dépôt public, **aucun runner auto-hébergé** (une PR externe exécuterait du code sur la machine).

## 4. Approches

| Approche | Résumé | Retenue |
| --- | --- | --- |
| **A. Nouveau dépôt public sans historique** | Instantané propre du code en un commit initial dans un nouveau dépôt public ; l'ancien est renommé et reste privé. | **Oui** (décision du développeur, 2026-11-16) |
| B. Même dépôt, historique purgé | `git filter-repo` sur les 967 commits, réécriture forcée de toutes les branches, puis demande au support GitHub de purger les références des PR et les vues en cache. | Non : GitHub conserve les commits des 51 PR (`refs/pull/*`) tant que le support ne les a pas effacés ; le résultat dépend d'un tiers et impose une réécriture forcée. |
| C. Publier sans toucher à l'historique, en comptant sur la rotation | | Non : expose les anciennes valeurs, les noms d'hôtes et la structure des secrets ; contraire à l'anti-objectif 1. |

Coût accepté de A : l'historique, les issues et les PR ne sont visibles que dans l'archive privée ; les réglages
GitHub (secrets, protections, environnements) sont recréés sur le nouveau dépôt, ce que la rotation impose de toute
façon.

## 5. Conception

### 5.1 Inventaire des secrets

Document `docs/v1/infra/secrets.md`, dans l'instantané publié : **noms uniquement, jamais de valeur**. Une ligne par
secret avec : nom GitHub, environnement(s), usage, emplacement actuel, révocation, génération.

Convention de nommage : les secrets applicatifs gardent le **nom de la variable lue par le code** et sont définis
**par environnement GitHub** (`prod`, `preprod`) ; le même nom porte une valeur différente dans chaque environnement.
Les secrets de déploiement (clé SSH de CI, jeton de registre) sont définis par la mission k3s, qui crée le nouveau
serveur ; ici on ne fait que révoquer les anciens.

| Nom GitHub | Env. | Usage | Emplacement actuel | Révocation de l'ancienne valeur | Nouvelle valeur |
| --- | --- | --- | --- | --- | --- |
| `SECRET_KEY` | prod, preprod | clé Django (sessions, jetons) | `apps/api/env.prod`, `env.preprod` | perd toute valeur dès qu'elle n'est plus déployée (prod arrêtée) | aléatoire, 64 caractères, générée par le script |
| `POSTGRES_PASSWORD` | prod, preprod | mot de passe de l'utilisateur applicatif de la base | secrets GitHub `DB_PASSWORD`, `PREPROD_DB_PASSWORD` de l'ancien dépôt | `ALTER ROLE … PASSWORD` sur la base de B (développeur, en SSH) | aléatoire, générée par le script ; la mission k3s l'utilise pour la nouvelle base |
| `POSTGRES_USER`, `POSTGRES_DB` | prod, preprod | identifiants non secrets de la base | idem (`DB_USER`, `DB_NAME`…) | — | **variables** GitHub, valeurs actuelles reprises |
| `REDIS_PASSWORD` | prod, preprod | mot de passe Redis (nouveau : Redis n'en avait pas) | — | Redis actuel arrêté (mesures conservatoires) | aléatoire, généré par le script |
| `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | prod, preprod | administrateur du stockage S3 | `apps/api/env.*`, `apps/minio/.env.*` | port public de MinIO fermé (mesures conservatoires) ; instance de A retirée à sa reconstruction, après export des objets | aléatoire, généré par le script |
| `IMGPROXY_KEY`, `IMGPROXY_SALT` | prod, preprod | signature des URL d'images | `.env` racine, `REACT_APP_IMGPROXY_*` du panel (présent dans le JavaScript servi : voir § 8) | imgproxy actuel arrêté avec la stack | aléatoire hexadécimal, 64 caractères, généré par le script |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | prod, preprod | envoi d'emails | `apps/api/env.*` | console du fournisseur SMTP : révoquer le jeton actuel, en créer un nouveau | saisie masquée par le script |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | prod, preprod | SMS | `apps/api/env.*` | console Twilio : régénérer le jeton d'authentification (le SID reste le même) | saisie masquée par le script |
| `SOCIAL_AUTH_GOOGLE_OAUTH2_KEY`, `SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET` | prod, preprod | connexion Google | non versionné (manquant en local) | console Google Cloud : réinitialiser le secret client | saisie masquée par le script |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | prod, preprod | identifiant OAuth public du front | `apps/nextjs/env.*` | — (public par nature) | **variable** GitHub |
| Clés SSH de déploiement (`SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`) | — | anciens déploiements par `scp`/`ssh` | secrets de l'ancien dépôt | clé publique correspondante retirée de `authorized_keys` sur A et B (développeur) | aucune ici : la mission k3s crée sa propre clé de déploiement |
| Configuration Firebase du panel (clé d'API Google, projectId…) | — | Firestore (menus) et Firebase Auth (vérification d'email, réinitialisation du mot de passe) du panel | `apps/panel/src/firebase/base.js`, en clair | projet Firebase **supprimé** dans la console (décision du développeur : Firebase n'est plus utilisé) | aucune : `base.js` ne contient plus de valeur ; les écrans concernés cessent de fonctionner jusqu'à leur portage vers l'api (§ 8) |
| `BUCKETEER_AWS_*` | — | ancien stockage S3 Heroku, lu par `settings.py` | non défini nulle part | — (compte obsolète, confirmé par le développeur) | aucune ; ligne « obsolète », code retiré par la mission k3s |
| Identifiants pgAdmin de dev (`configs/pgadmin/pgpass`) | — | développement local | dépôt | — (valeur de développement local) | inchangé ; vérifié comme différent de toute valeur de prod |

Les valeurs de **développement local** versionnées (`.env.template`, `apps/api/.env.temp`, `apps/panel/.env.development`,
`apps/nextjs/env.example`, identifiants du README) restent dans le dépôt : elles ne servent qu'au Compose local. Le
script et le runbook vérifient qu'aucune n'est réutilisée comme valeur de prod ou de preprod.

Les autres variables non secrètes des anciens `env.prod` (`ALLOWED_HOSTS`, `WEB_URL`, `API_URL`, `MINIO_ENDPOINT`,
`FILES_CDN_ENDPOINT`, `MINIO_DEFAULT_BUCKETS`, `NEXT_PUBLIC_BACKEND_URL`…) deviennent des **variables** GitHub par
environnement. L'inventaire les liste aussi.

### 5.2 Script de rotation

`scripts/secrets/definir-secrets.sh`, lancé par `make secrets-definir ENV=prod|preprod REPO=tigamadou/urbankiff` :

- Valeurs aléatoires générées dans un conteneur (image épinglée), transmises par tube à `gh secret set <NOM> --env
  <ENV> --repo <REPO>` (valeur lue sur l'entrée standard, jamais en argument ni dans une variable exportée, jamais
  écrite sur disque).
- Valeurs de fournisseurs demandées une par une en saisie masquée (`read -s`), passées de la même façon.
- Variables non secrètes posées avec `gh variable set`, à partir d'un fichier de valeurs **non secrètes** versionné
  (`scripts/secrets/variables-<env>.txt`).
- Idempotent et sélectif : `SEULEMENT="NOM1 NOM2"` pour ne (re)définir que certains secrets ; sans valeur saisie, un
  secret de fournisseur est laissé tel quel.
- À la fin : `gh secret list --env <ENV>` et `gh variable list --env <ENV>` (noms et dates seulement), comparés à
  l'inventaire ; le script échoue si un nom attendu manque.
- Testé : tests `bats` avec un faux `gh` qui vérifie qu'aucune valeur n'apparaît en argument ni en sortie.

### 5.3 Runbook de révocation

`docs/v1/infra/rotation-secrets.md` : ordre des opérations, et pour chaque secret externe la procédure de
révocation (console, page, action), avec une case à cocher et la date. Le runbook couvre aussi les **mesures
conservatoires** sur A et B (§ 5.5). Toute commande à lancer sur un serveur est donnée au développeur, jamais exécutée
par un agent.

### 5.4 Instantané propre et nouveau dépôt

1. **Préparation dans l'ancien dépôt** (branche de travail) :
   - suppression de `apps/api/env.prod`, `apps/api/env.preprod`, `apps/minio/.env.prod`, `apps/minio/.env.preprod`,
     `apps/panel/.env.prod`, `apps/panel/.env.preprod`, `apps/nextjs/env.prod`, `apps/nextjs/env.preprod` ;
   - suppression des 8 workflows `*-deploy-to-*.yml` (ils copient ces fichiers ; la mission k3s écrit les nouveaux) ;
     `deploys/` et `caddyprod/` restent comme référence pour la mission k3s ;
   - `apps/panel/src/firebase/base.js` ne contient plus aucune valeur de configuration (lecture de variables
     `REACT_APP_FIREBASE_*` non définies, sans planter au chargement de l'application) ;
   - suppression de `.claude/INCIDENT-2026-05-31-nextjs-compromise.md` (décision du développeur : on n'en tient plus
     compte) et de la cible `uploadDeploys` du `Makefile` (IP du serveur et accès `root`) ;
   - ajout de l'inventaire, du script, du runbook, de `.gitleaks.toml` (règles par défaut plus liste d'exceptions
     justifiées pour les valeurs de développement local) et des cibles `make secrets-definir` et `make secrets-scan` ;
   - `make secrets-scan` : gitleaks (conteneur, version épinglée) sur l'arbre de travail ; **zéro constat** hors
     exceptions listées.
2. **Instantané** : `git archive` de cette branche → nouveau dépôt local avec **un seul commit initial**
   (« chore: initial public snapshot »), sans aucun objet de l'ancien historique. Nouveau scan gitleaks, cette fois sur
   l'historique du nouveau dépôt (un commit) : zéro constat.
3. **Bascule GitHub** (actions lancées ou autorisées par le développeur, dans cet ordre) :
   1. renommer `tigamadou/urbankiff` en `tigamadou/urbankiff-archive` (reste privé ; GitHub redirige l'ancien nom
      tant qu'aucun dépôt ne le reprend) ;
   2. créer `tigamadou/urbankiff` et y pousser `development` et `main` (même commit), branche par défaut
      `development`, puis le **passer en public** aussitôt. Les étapes suivantes l'exigent : en GitHub Free, un dépôt
      privé n'a ni environnements, ni analyse de secrets, ni protection au push. Rien n'est exposé entre-temps, le
      dépôt ne contenant aucun secret (scan gitleaks à zéro, étape 2) ;
   3. activer l'analyse de secrets et la protection au push ; créer les environnements `prod` (approbation obligatoire
      du développeur, déploiement limité aux tags `v*`) et `preprod` ;
   4. lancer le script de rotation pour `preprod` puis `prod` ;
   5. protéger `development` et `main` : check requis `ci-ok`, pas de force push, pas de suppression ; vérifier qu'une
      PR d'essai déclenche `devteam-ci.yml` sur un runner GitHub et que `ci-ok` est imposé.

   **Préalable à l'étape 3.2** : les mesures conservatoires (§ 5.5) sont appliquées et vérifiées. Les documents
   publiés (specs, plans, `.claude/CLAUDE.md`) décrivent l'état de sécurité des serveurs actuels : ils ne sont rendus
   publics qu'une fois ces faiblesses fermées.

   Les branches non fusionnées et la PR #43 (backups) restent dans l'archive ; tout travail repris plus tard dans le
   dépôt public passe d'abord par `make secrets-scan`.
4. **Clones locaux** : nouveau clone de `tigamadou/urbankiff` dans le dossier du projet (après sauvegarde des `.env`
   locaux non versionnés) ; l'ancien checkout est renommé en dossier d'archive, puis supprimé par le développeur quand
   il le décide. Les worktrees de sessions Claude de l'ancien clone sont abandonnés.

### 5.5 Mesures conservatoires sur les serveurs (développeur)

Tant que la mission k3s n'a pas reconstruit A :

- A : arrêter les conteneurs de la preprod et de la prod applicatives (déjà en panne pour la prod) ; **ne pas** supprimer
  les volumes MinIO ; pare-feu : seuls 22, 80 et 443 ouverts (fermeture de 6380, 8000, 8001, 3000, 3050, 3051, 3500,
  9000 à 9003) ; Redis arrêté.
- B : le port PostgreSQL n'accepte plus que l'IP de A (et plus aucune autre) ; mot de passe de l'utilisateur
  applicatif changé (`ALTER ROLE`) ; sauvegarde complète de la base (`pg_dump`) copiée hors des serveurs.
- A et B : retrait des anciennes clés de déploiement de `authorized_keys` ; vérification qu'aucune clé inconnue n'y
  figure.
- A : Caddy ne sert plus ni l'application ni les consoles MinIO (`s3*`, `s30*`) : le port 443 restant ouvert, la
  fermeture des ports ne suffit pas. Vérification par `make hotes-scan` sur chaque nom d'hôte du Caddyfile.
- Projet Firebase supprimé avant la publication : il révoque la clé serveur FCM trouvée dans `settings.py`.

## 6. Ce qui est décidé, ce qui reste au constructeur

**Décidé** : approche A ; noms GitHub = noms des variables du code, définis par environnement `prod`/`preprod` ; dépôt
d'archive `urbankiff-archive` privé ; suppression des workflows de déploiement actuels et de la note d'incident ;
gitleaks comme scanner ; aucune valeur affichée ni commitée ; actions GitHub et serveur par le développeur.

**Laissé au constructeur** : version épinglée de gitleaks et de l'image de génération ; forme exacte des tests `bats`
du script ; mise en page de l'inventaire et du runbook ; contenu exact des fichiers de variables non secrètes (repris
des anciens `env.prod`/`env.preprod`, hors secrets).

## 7. Critère de fin

- `tigamadou/urbankiff` est public, son historique compte un seul commit propre, et gitleaks ne trouve rien hors des
  exceptions listées.
- `tigamadou/urbankiff-archive` est privé et contient l'historique complet.
- Tous les secrets de l'inventaire sont définis dans les environnements GitHub (`gh secret list --env …` conforme) et
  toutes les révocations du runbook sont cochées et datées.
- La protection de `development` impose `ci-ok`, et une PR d'essai a `ci-ok` vert sur un runner GitHub.
- Les mesures conservatoires sont appliquées (scan de ports externe sur A et B : seuls 22, 80, 443, plus PostgreSQL
  depuis A uniquement).

## 8. Constats transmis à la mission k3s

- Le panel envoie `REACT_APP_IMGPROXY_KEY` et `REACT_APP_IMGPROXY_SALT` dans son JavaScript (`apps/panel/src/utility/
  hooks/useSignedUrl.js`) : la signature des URL imgproxy doit passer côté serveur, sinon la clé reste publique quelle
  que soit sa rotation.
- `REACT_APP_MINIO_ACCESS_KEY_ID` et `REACT_APP_MINIO_SECRET_KEY` sont définis pour le panel : vérifier qu'aucun code
  ne les lit (une variable `REACT_APP_*` lue est inscrite dans le JavaScript servi) et les supprimer.
- Redis doit avoir un mot de passe (`REDIS_PASSWORD`) et n'être joignable que depuis le namespace qui l'utilise.
- `settings.py` garde une branche de stockage `BUCKETEER_AWS_*` (Heroku, obsolète) : à retirer.
- Serveur B (ancienne base de prod) : décision du développeur du 2026-11-16, **futur deuxième nœud** du cluster,
  réinstallé à neuf et joint par Ansible quand le trafic le demandera. PostgreSQL et Caddy y sont arrêtés, pare-feu
  limité à SSH.
- La base de prod était ouverte à Internet (port 5432) avec un mot de passe considéré comme volé : la sauvegarde
  faite le 2026-11-16 a pu capturer une base modifiée. Avant toute restauration, l'inspecter (rôles, fonctions,
  extensions, déclencheurs inattendus, `COPY … FROM PROGRAM`) et ne restaurer que le schéma et les données de
  l'application, sans les rôles. Même vigilance pour le bucket MinIO (fichiers ajoutés, exécutables).

## 9. Chantier séparé, avant la remise en prod

Portage vers l'api des écrans du panel qui utilisaient Firebase : liste, formulaire et suppression des menus
(Firestore, alors que l'api a une app `menu`), vérification d'email et réinitialisation du mot de passe (Firebase
Auth). Ils sont inactifs entre la publication et ce portage.

Également avant la remise en prod, une fois le code public : la connexion Google de l'api (`SocialLoginView`,
`apps/api/apps/user/views.py`) utilise l'identifiant Google (`sub`) comme mot de passe et ne vérifie pas l'audience
(`aud`) du jeton ; à corriger.
