# Urbankiff : preprod iso à la prod, restauration rejouable, outils web de la base et du stockage

> Spec rédigée le 2026-11-17, validée par le développeur le 2026-11-17. Mission devteam (`/devteam:demarrer`), slug
> proposé `outils-donnees`. Préalable fait : mission `k3s-ansible` (`docs/v1/specs/2026-11-16-k3s-ansible.md`), preprod
> en service sur k3s depuis le 2026-11-17 (`v0.1.0-rc.4`). Cette spec **remplace** les décisions suivantes de la spec
> k3s-ansible : « preprod sans SMS » (§ 6), « preprod sur base vide avec données de démonstration » (§ 6) et la
> restauration par Job ponctuel piloté par `restauration.active` (§ 5.10).

## 1. Intention

La preprod existe pour **tester avant de déployer en prod**. Tout ce qui y diffère de la prod est un angle mort. Le
cas qui a révélé le problème : la mise en service de la prod (restauration de la sauvegarde du 2026-11-16, procédure
`docs/v1/infra/premier-deploiement-prod.md`) ne peut aujourd'hui être jouée **que** sur la prod, une seule fois, sans
répétition possible.

Deux besoins, liés :

1. **Preprod iso à la prod** : mêmes processus, même code actif, mêmes outils. Seules diffèrent les valeurs propres à
   l'environnement (hôtes, identifiants, bucket) et le dimensionnement mémoire.
2. **Interagir avec les données d'un environnement** :
   - **charger un dump** dans la base et des fichiers dans le stockage, par un processus rejouable, identique en preprod
     et en prod, lançable par la CI **ou** depuis le poste du développeur ;
   - **consulter et manipuler** la base et le stockage S3 (RustFS) **depuis un navigateur, de n'importe où**, en HTTPS
     et derrière une authentification.

Ce que le développeur veut pouvoir faire, par exemple : déposer une sauvegarde **de la preprod** dans le bucket de
la preprod, la restaurer en preprod, vérifier dans le navigateur (front, panel, pgAdmin, console du stockage),
recommencer autant de fois que nécessaire ; puis, le jour venu, jouer **exactement le même geste** sur la prod avec la
sauvegarde de la prod. C'est le **processus** qui est répété en preprod, pas les données.

**Chaque environnement a ses propres données et sa propre restauration** (décision du développeur). Une seule
exception, lancée à la main quand le développeur en a besoin : la **copie anonymisée** de la prod vers la preprod
(§ 5.6), qui rend les données de la preprod iso à celles de la prod sans jamais y faire entrer de données personnelles
réelles.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs**

1. **Restauration rejouable** : une action `restaurer <prefixe>` du point d'entrée du serveur (`urbankiff-deploy`), qui
   recharge la base et les fichiers d'un environnement depuis un préfixe du bucket Wasabi de cet environnement, sur une
   base **non vide**, autant de fois que voulu.
2. **Deux déclencheurs, un seul code** : un workflow GitHub manuel (`workflow_dispatch`) et une cible `make` du poste,
   qui appellent tous deux la même action par SSH (compte `deploy`, commande forcée).
3. **Dépôt de la sauvegarde** dans Wasabi par une cible `make` du poste (aujourd'hui « par l'outil choisi par le
   développeur »).
4. **Outils web** par environnement, sur des sous-domaines en HTTPS (port 443) :
   - **pgAdmin 4** pour la base ;
   - **console de RustFS** pour le stockage.
   Chacun protégé par son propre login. **Pas d'authentification Traefik devant les outils pour l'instant**
   (décision du développeur, 2026-11-17) : elle pourra être ajoutée plus tard sans changer le reste.
5. **Iso preprod / prod** : `sms.actif` et tous les interrupteurs fonctionnels ont la même valeur dans les deux
   environnements ; les outils web et la restauration existent dans les deux ; la procédure de premier déploiement de
   la prod devient « jouer la restauration », déjà répétée en preprod.
6. **Copie prod → preprod anonymisée**, déclenchée à la main (workflow GitHub manuel ou cible `make` du poste),
   jamais planifiée : la base et les fichiers de la preprod deviennent ceux de la prod, données personnelles
   remplacées par des valeurs factices (§ 5.6).
7. Un **contrôle automatique** d'iso : un test échoue si une valeur fonctionnelle (hors liste d'écarts autorisés,
   § 5.1) diffère entre `values-preprod.yaml` et `values-prod.yaml`, pour les deux charts.

**Non-objectifs**

- Aligner la mémoire des pods et le quota : **restent tels quels** (décision du développeur, A partagé par les deux
  environnements).
- Le déclenchement par version (pré-release → preprod, release → prod) et l'arrêt/démarrage à la demande de la
  preprod (`preprod-arret`, `preprod-demarrage`) : écarts voulus, conservés.
- Copier des données de la prod vers la preprod **sans anonymisation**, ou de façon planifiée : exclu.
- Produire le dump d'un environnement en marche : hors chantier ; la source est un dump déposé dans Wasabi.
  Pour la preprod, un dump s'obtient par la sauvegarde de pgAdmin (format custom, téléchargée dans le navigateur) ou
  par le dump fabriqué des tests (`infra/restauration/tests/fabriquer-dump.sh`).
- Les données de démonstration et le seeder local (`make seed`, `apps/api/seed/fake_data.py`) : inchangés.
- Le chantier Firebase et connexion Google, l'admin Django sans fichiers statiques (A14 de k3s-ansible).

**Anti-objectifs** (ce qui ferait échouer le chantier même si « ça marche »)

- Un outil web joignable sans authentification, en HTTP clair, ou par un port autre que 443.
- Une restauration en prod lançable sans l'approbation de l'environnement GitHub `prod` côté CI.
- Un secret écrit dans le dépôt, passé en argument de commande, journalisé, ou lisible dans les journaux d'un Job.
- Deux chemins de restauration (l'ancien `restauration.active` laissé à côté du nouveau).
- Un écart preprod / prod ajouté sans être déclaré dans la liste des écarts autorisés.
- Une donnée personnelle réelle (email, téléphone, nom, mot de passe, jeton) présente en preprod ou dans le bucket
  Wasabi de la preprod : la preprod envoie de vrais emails et de vrais SMS (même compte Twilio), elle est publique,
  et pgAdmin y est ouvert sur Internet.
- Une colonne personnelle ajoutée plus tard qui passe en clair dans la copie parce que personne ne l'a classée.
- Des données restaurées qui pointent encore vers d'anciens hôtes (URL des fichiers).

## 3. Contraintes

- **Serveur A** : 5,8 Go, sans swap, porte prod et preprod. Le quota de la preprod (3 Gio de limites, 1 536 Mi de
  requêtes) ne change pas : les nouveaux composants doivent y tenir, vérifié par `infra/helm/tests-transverses/controle.rb`.
  Aujourd'hui : 1 728 Mi en régime établi, 256 Mi d'auxiliaire Barman, 384 Mi de surplus de mise à jour, 256 Mi de
  plus gros Job, soit 2 624 Mi sur 3 072 : **environ 450 Mi de marge**.
- **Ports exposés** : 22, 80, 443 seulement (contrôlé par `make ports-scan`). Les outils passent par Traefik sur 443.
- **Compte `deploy`** : commande forcée, environnement fixé par `authorized_keys`, Role limité à son namespace
  (`infra/ansible/roles/deploiement/defaults/main.yml`). Toute ressource nouvelle (par exemple `Middleware` de Traefik)
  demande une règle de Role ajoutée par Ansible.
- **Secrets** : dans les environnements GitHub `prod` et `preprod`, posés par `make secrets-definir`, transmis au
  serveur par l'entrée standard de SSH (`urbankiff-deploy`), jamais en argument.
- **Contrat devteam** : sur l'hôte, seulement `docker`, `make`, `git`, `gh`. Tout le reste en conteneur.
- **DNS** : les enregistrements des nouveaux sous-domaines sont créés par le développeur.
- Toute action sur le serveur réel, le DNS, Wasabi ou les réglages GitHub est faite ou autorisée par le développeur.

## 4. Approches

**Mise en service et chargement de données**

| Approche | Résumé | Retenue |
| --- | --- | --- |
| A. Les outils web sont le processus | Restaurer le dump depuis pgAdmin, déposer les fichiers par la console S3, puis une commande de réécriture des URL. | Non : manuel, non testé, dépend de la taille des envois par le navigateur ; le geste de la prod n'est pas répété à l'identique. |
| **B. Job rejouable piloté par `urbankiff-deploy`, outils web pour contrôler** | `restaurer <prefixe>` arrête l'application, restaure (`pg_restore --clean`), copie les fichiers, migre, réécrit les URL, vide le cache, redémarre. CI et poste appellent la même action. | **Oui** (choix du développeur) : même geste en preprod et en prod, tracé, testé. |
| C. Fixture `loaddata` | Données en JSON versionné. | Non : ne transporte pas les fichiers, inadapté à un dump de prod. |

**Accès aux outils web**

| Approche | Retenue |
| --- | --- |
| **Sous-domaines sur 443, Traefik, cert-manager** | **Oui** (choix du développeur) : aucun port de plus, certificats comme le reste. |
| Ports non standard | Non : un point d'entrée Traefik et une règle ufw par port, bloqués par certains réseaux, aucune protection en plus (un scan complet prend quelques minutes). |
| Tunnel SSH seulement | Non : le développeur veut un accès depuis n'importe où. |

## 5. Conception

### 5.1 Iso preprod / prod

- `sms.actif: true` dans les deux environnements, avec **le même compte Twilio** que la prod (décision du
  développeur) : `TWILIO_ACCOUNT_SID` et `TWILIO_AUTH_TOKEN` de la preprod prennent les valeurs de la prod. Le code
  utilise Twilio Verify, que les identifiants de test de Twilio ne prennent pas en charge.
- Valeurs fonctionnelles identiques dans `values-preprod.yaml` et `values-prod.yaml` des deux charts. **Écarts
  autorisés**, et seulement eux : `environnement`, `hosts.*` (y compris les hôtes des outils), `*.ressources.*`. Toute
  autre clé différente fait échouer le contrôle d'iso (objectif 6), ajouté à `controle.rb` ou à côté.
- Les variables GitHub (`scripts/secrets/variables-<env>.txt`) : mêmes clés dans les deux fichiers ; le contrôle
  vérifie aussi l'égalité des **ensembles de clés** (déjà vrai aujourd'hui).

### 5.2 Restauration rejouable

**Format du dépôt dans Wasabi** (inchangé, A10 de k3s-ansible) :

```
restauration/<AAAA-MM-JJ>/base.dump     # pg_dump au format custom
restauration/<AAAA-MM-JJ>/fichiers/     # contenu du bucket
```

**Action du serveur** : `SSH_ORIGINAL_COMMAND = restaurer restauration/<AAAA-MM-JJ>/` (expression régulière stricte,
même verrou que `deploy`). Déroulé, chaque étape vérifiée avant la suivante, arrêt au premier échec avec un message
clair :

1. contrôle que le préfixe existe dans le bucket Wasabi de l'environnement et contient `base.dump` ;
2. arrêt de l'application : `api`, `workers`, `nextjs`, `panel` et les outils web à 0 réplique (les données restent
   en marche) ;
3. Job `urbankiff-restauration` (chart `urbankiff-donnees`) : récupération depuis Wasabi,
   remise à zéro du schéma `public` (suppression puis recréation, pour qu'aucune table plus récente que le dump ne
   subsiste et que `migrate` reparte de l'état du dump), puis
   `pg_restore --no-owner --no-privileges --schema=public`, copie de `fichiers/` dans le bucket
   RustFS (`rclone copy` : ajoute et remplace, ne supprime pas ce qui n'est pas dans la sauvegarde) ;
4. Job `urbankiff-apres-restauration` (chart `urbankiff`, image de l'api de la version déployée) :
   `migrate`, réécriture des URL (§ 5.3), `clearcache` ;
5. redémarrage de l'application aux répliques d'avant l'arrêt, attente de la disponibilité ;
6. contrôle de santé (`/api/health/`) et journal de fin `restauration terminée`.

En cas d'échec à l'étape 3 ou 4, l'application **reste arrêtée** et le script le dit : la base peut être à moitié
restaurée, on corrige et on relance.

**Fin du chemin `restauration.active`** : le Job n'est plus rendu par `helm upgrade` selon une valeur ; il est rendu à
la demande par l'action `restaurer` (par exemple `helm template --show-only` avec les valeurs de la release en place),
créé, suivi, puis supprimé. Les valeurs `restauration.active`, `restauration.purger` et la purge du préfixe
disparaissent : **la sauvegarde reste dans Wasabi** pour pouvoir rejouer en preprod puis en prod.

**Déclencheurs** :

- **CI** : workflow `.github/workflows/restauration.yml`, `workflow_dispatch` avec deux entrées : `environnement`
  (choix `preprod` ou `prod`) et `prefixe`. Le job porte `environment: <environnement>` : pour la prod, l'approbation
  de l'environnement GitHub `prod` s'applique. Il ne transmet **aucun secret** sur l'entrée standard (l'action lit les
  Secrets déjà présents dans le namespace) et liste explicitement ce qu'il lit (pas de `toJSON(secrets)`).
- **Poste** : `make restauration-lancer ENV=<preprod|prod> PREFIXE=restauration/<date>/`, SSH avec la clé de
  déploiement de l'environnement (`~/.ssh/urbankiff-deploy-<env>`), hôte et empreinte lus comme pour
  `make deploiement`. Pour `ENV=prod`, confirmation interactive (saisie du mot `prod`).

**Dépôt** : `make restauration-deposer ENV=<env> DUMP=<fichier> [FICHIERS=<dossier>] DATE=<AAAA-MM-JJ>` copie vers
`restauration/<date>/` du bucket Wasabi de l'environnement, rclone en conteneur, identifiants Wasabi saisis de façon
masquée ou lus dans l'environnement du shell, jamais en argument ; contrôle de taille de `base.dump` après copie.

### 5.3 Réécriture des URL

Les données de la prod contiennent des URL absolues vers les fichiers (au moins `Post.image`, `File.url`, `Media.file`
de `banner`, `Scrapper.image`, avatars ; liste exacte à établir par le constructeur à partir des modèles). Elles ne
pointent pas toutes vers `https://api.urbankiff.com/file/...` : le plan `k3s-ansible/8-restauration.md` signale aussi
des URL d'anciens points d'accès MinIO (`s3*`, `s30*`, chemin `/<bucket>/...`).

Une commande Django (`apps/api`) applique une **liste de règles** « préfixe source → préfixe cible », où la cible est
construite à partir de `FILES_CDN_ENDPOINT` de l'environnement. Les règles vivent dans un fichier versionné, lu par la
commande ; leur contenu exact (quels préfixes `s3*` réécrire, et vers quel chemin) est fixé **après** l'inspection de
la sauvegarde (`make sauvegarde-inspecter`), par le développeur. La commande est idempotente, journalise le nombre de
lignes changées par colonne, et est testée (tests Django sur une base de test, sans mock de l'ORM). En prod, elle ne
change rien si les URL sont déjà bonnes.

### 5.4 Outils web

**Hôtes** (valeurs `hosts.*`, écarts autorisés) :

| Outil | preprod | prod |
| --- | --- | --- |
| pgAdmin | `preprod.db.urbankiff.com` | `db.urbankiff.com` |
| Console RustFS | `preprod.stockage.urbankiff.com` | `stockage.urbankiff.com` |

**Exposition** : Ingress Traefik + certificat cert-manager (ClusterIssuer existant), comme le front. Middlewares
Traefik devant les deux : limitation de débit contre le forçage des logins (le login de l'outil est la seule barrière)
et en-têtes de sécurité (HSTS). Pas d'authentification Traefik pour l'instant.

**pgAdmin 4** (même outil que le Compose local) :

- Deployment dans le namespace de l'environnement, image épinglée, non root, système de fichiers en lecture seule
  sauf les dossiers de travail ; mémoire limitée pour tenir dans la marge du quota (§ 3).
- Login pgAdmin : adresse et mot de passe de secrets GitHub dédiés.
- Serveur `urbankiff-pg` préconfiguré, connexion avec l'utilisateur applicatif (`urbankiff-pg-app`) par fichier de
  mots de passe monté depuis le Secret : le développeur n'a pas à connaître le mot de passe de la base.
- État de pgAdmin (préférences, historique) : volume persistant petit ou `emptyDir`, au choix du constructeur ;
  rien d'indispensable n'y est stocké.

**Console RustFS** : activée sur le StatefulSet existant (`RUSTFS_CONSOLE_ENABLE`, port de console), sans nouveau
pod. Le port S3 (9000) reste interne.

**Réseau** : NetworkPolicies à ajouter : Traefik → pgAdmin, Traefik → console RustFS, pgAdmin → PostgreSQL (5432).
Rien d'autre.

**Iso** : outils présents et configurés à l'identique dans les deux environnements. `preprod-arret` les arrête aussi.

### 5.5 Secrets et variables

Nouveaux secrets GitHub, par environnement, ajoutés à `docs/v1/infra/secrets.md`, à `scripts/secrets/` et à la liste
`SECRET_KEYS` de `urbankiff-deploy` :

| Nom | Usage | Valeur |
| --- | --- | --- |
| `PGADMIN_EMAIL` | login pgAdmin | saisie masquée |
| `PGADMIN_MOT_DE_PASSE` | mot de passe pgAdmin | saisie masquée |

Login de la console RustFS : les identifiants administrateur `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`, aujourd'hui
générés au hasard par le script et illisibles dans GitHub : ils passent en **saisie masquée** pour que le développeur
les connaisse (voir § 6, choix à contrôler).

Les identifiants Twilio de la preprod cessent d'être factices : ce sont ceux de la prod (§ 5.1).

### 5.6 Copie prod → preprod anonymisée

**Principe** : les données réelles ne quittent jamais le namespace `prod`. L'anonymisation se fait côté prod ; la
preprod ne reçoit qu'une sauvegarde déjà anonymisée, chargée par la **restauration habituelle** (§ 5.2) : pas de
deuxième chemin de chargement.

**Étape 1, export côté prod** : action `exporter-anonyme` de `urbankiff-deploy`, acceptée **seulement** pour la clé de
la prod. Elle crée un Job dans `prod` qui :

1. fait un `pg_dump` (format custom) de la base de prod ;
2. le restaure dans un PostgreSQL temporaire **à l'intérieur du pod du Job** (conteneur annexe, stockage `emptyDir`,
   détruit avec le pod) ;
3. applique l'anonymisation (règles ci-dessous) ;
4. refait un `pg_dump` de la base anonymisée et le dépose dans le **bucket Wasabi de la preprod**, sous
   `restauration/<AAAA-MM-JJ>-prod-anonyme/base.dump` ;
5. copie sous `restauration/<AAAA-MM-JJ>-prod-anonyme/fichiers/` **seulement les fichiers cités par le contenu
   public** de la base anonymisée (images d'articles, bannières, pages, scrapper), listés par une commande Django ;
   les avatars sont remis à la valeur par défaut et les pièces d'identité (`user.id_img`) ne sont ni copiées ni
   référencées (décision du développeur, 2026-11-17).

Les identifiants Wasabi sont **les mêmes** pour les deux environnements, seul le bucket change : le Job de prod
utilise ses identifiants et reçoit le nom du bucket de la preprod (valeur de configuration, pas un secret). La base
réelle n'est jamais écrite hors du pod du Job.

**Étape 2, chargement côté preprod** : `restaurer restauration/<AAAA-MM-JJ>-prod-anonyme/` (§ 5.2) : base, fichiers,
réécriture des URL de la prod vers la preprod (§ 5.3), cache vidé. L'expression régulière du préfixe accepte ce
suffixe.

**Déclencheurs** :

- **CI** : workflow manuel `.github/workflows/copie-prod-preprod.yml` (`workflow_dispatch`), deux jobs enchaînés :
  export (`environment: prod`, donc approbation de la prod) puis restauration (`environment: preprod`).
- **Poste** : `make copie-prod-preprod`, qui enchaîne les deux actions en SSH avec les deux clés de déploiement, avec
  confirmation interactive.

**Anonymisation** :

- règles dans un fichier versionné, **colonne par colonne**, pour chaque table qui porte des données de personnes
  (utilisateurs, profils, tokens, sessions, journaux d'accès, vues avec IP, etc. ; inventaire à établir par le
  constructeur à partir des modèles de `apps/api`) ;
- traitements : emails → `user-<id>@exemple.invalid` ; téléphones → numéro factice non attribuable ; noms et prénoms →
  valeurs factices stables par identifiant ; mots de passe → inutilisables ; jetons, sessions, codes OTP, adresses IP
  et agents utilisateurs → vidés ou remplacés ;
- les administrateurs aussi sont anonymisés ; l'administrateur de la preprod est recréé par `prodseed` avec le
  `DJANGO_SUPERUSER_PASSWORD` de la preprod après la restauration (le constructeur vérifie l'ordre des étapes) ;
- **garde-fou** : un test Django échoue si une colonne d'une table classée « personnes » n'est ni « anonymiser » ni
  « garder » dans le fichier de règles, ou si une table nouvelle contient une colonne dont le nom évoque une donnée
  personnelle (email, phone, contact, name, ip, token, password…) sans être classée ;
- un test vérifie sur une base de test qu'après anonymisation aucune valeur d'origine des colonnes classées ne
  subsiste.

**Point d'attention (hors chantier)** : avec les mêmes identifiants Wasabi, le namespace `preprod` détient des clés
capables de lire le bucket de la prod (sauvegardes CloudNativePG brutes). La séparation des clés par bucket est
recommandée plus tard.

### 5.7 Droits du compte `deploy`

Ajouts au Role (Ansible) : `traefik.io` `middlewares` en écriture ; `pods/exec` **non** (la restauration passe par des
Jobs). Le contrôle `tests/controles.sh` d'Ansible vérifie les nouvelles règles.

### 5.8 Documentation

- `docs/v1/infra/premier-deploiement-prod.md` réécrit : processus répété en preprod avec une sauvegarde de la
  preprod (`make restauration-deposer ENV=preprod`, `make restauration-lancer ENV=preprod`), contrôles dans le
  navigateur, puis même geste sur la prod avec la sauvegarde de la prod.
- `docs/v1/infra/deploiement.md` : action `restaurer`, workflow manuel, cibles `make`.
- `docs/v1/infra/kubernetes.md` : outils web, middlewares, NetworkPolicies, quota recalculé.
- `docs/v1/infra/secrets.md` : nouveaux secrets ; Twilio preprod = compte de la prod.
- Nouveau `docs/v1/infra/outils-donnees.md` : usage de pgAdmin et de la console, enregistrements DNS à créer.

## 6. Ce qui est décidé, ce qui reste au constructeur

**Décidé par le développeur** : preprod iso à la prod sauf mémoire et quota ; restauration par Job rejouable
(approche B) ; déclenchement par workflow GitHub manuel **et** depuis le poste sans la CI ; outils web accessibles de
partout, HTTPS et authentification, sous-domaines sur 443 ; seeder inchangé.

**Choix faits pendant la conception** (à contrôler) :

- pgAdmin 4 pour la base (même outil qu'en local), console intégrée de RustFS pour le stockage ;
- login de l'outil seul, limitation de débit Traefik devant ; noms d'hôtes `db` et `stockage` ;
- sauvegarde conservée dans Wasabi après restauration (plus de purge) ;
- `rclone copy` et non `sync` pour les fichiers ;
- `MINIO_ROOT_*` en saisie masquée ;
- confirmation interactive de `make restauration-lancer ENV=prod`.

**Décidé après la relecture** : même compte Twilio en preprod et en prod ; chaque environnement restaure ses propres
sauvegardes depuis son propre bucket Wasabi ; seule exception, la copie prod → preprod **anonymisée pendant la copie**,
lancée à la main (§ 5.6) ; identifiants Wasabi communs, un bucket par environnement.

**Réponses aux questions de la relecture** :

- la prod n'a encore **aucune donnée** sur k3s (rien n'est déployé dans `prod`) : passer `MINIO_ROOT_*` en saisie
  masquée revient à poser des valeurs neuves, sans bascule ;
- le chantier Firebase et connexion Google reste un **préalable au premier déploiement de la prod**, pas à la
  répétition du processus en preprod, qui peut se faire avant ;
- remise à zéro du schéma `public` avant `pg_restore` plutôt que `--clean` (choix de conception : `--clean` laisse les
  tables plus récentes que le dump et casse `migrate`) ; le constructeur vérifie que l'utilisateur applicatif est
  propriétaire du schéma, sinon il le signale ;
- console sur `stockage.` et non `s3.` : d'anciennes URL de données utilisent des hôtes `s3*`.

**Laissé au constructeur** : versions épinglées (pgAdmin, rclone) ; découpage des templates ; forme du rendu à la
demande du Job ; forme des tests (helm-unittest, bats, tests Django) ; liste exacte des colonnes d'URL ; noms des
cibles `make` intermédiaires.

## 7. Critère de fin

- Tests verts : helm-unittest des deux charts, `make helm-controle` (rendu, kubeconform, contrôles transverses dont
  quota et iso), bats de `urbankiff-deploy` (action `restaurer` : commande acceptée, préfixes refusés, verrou, arrêt
  et redémarrage, échec qui laisse l'application arrêtée), tests Django de la réécriture des URL, tests du rôle
  Ansible.
- Le contrôle d'iso échoue sur un écart non autorisé introduit volontairement dans un test.
- Tests de l'anonymisation verts : aucune valeur d'origine des colonnes classées ne subsiste ; une colonne personnelle
  non classée fait échouer le garde-fou ; `exporter-anonyme` refusé avec la clé de la preprod (bats).
- Aucun secret dans le dépôt (`make secrets-scan`).

Vérifié **après la fusion de la PR finale**, avec le développeur, sur la preprod réelle :

- `make restauration-deposer` puis `make restauration-lancer ENV=preprod` avec un dump de test, puis le même préfixe
  par le workflow GitHub manuel : deux restaurations successives réussies, décomptes de tables égaux à ceux du dump ;
- front, panel et api répondent après restauration, images servies depuis l'hôte de la preprod ;
- `https://preprod.db.urbankiff.com` et `https://preprod.stockage.urbankiff.com` : login de l'outil exigé, accès après connexion ;
  pgAdmin montre les tables, la console liste le bucket ;
- `make copie-prod-preprod` (une fois la prod en service) : la preprod affiche les contenus de la prod, aucun email
  ni téléphone réel dans la base de la preprod (contrôle par requête dans pgAdmin) ;
- `make ports-scan HOTE=<A>` : toujours 22, 80, 443 seulement.

## 8. Organisation du travail

Mission `outils-donnees` (titre : « Preprod iso, restauration rejouable, outils web des données »), branche
`feature/outils-donnees` partie de `development`. Plans : `docs/v1/plans/outils-donnees/<n>-<lot>.md`, tableau de
bord `docs/v1/plans/outils-donnees/README.md`.

### 8.1 Graphe

```
reecriture-urls   (indépendant)
anonymisation     (indépendant)
outils-web        (indépendant)
jobs-donnees      (indépendant)
deploiement       (indépendant)
iso-secrets       (indépendant)
ansible           (indépendant)
```

Aucun socle : les interfaces entre lots sont fixées par les contrats du § 8.3, et chaque lot teste son côté avec
des faux (bats, helm-unittest, tests Django). Tous les lots utilisent le profil `api` (le moins coûteux) : aucun ne
lance le front ni le panel.

### 8.2 Lots

| n | Lot | Profil | Dépend de | Fichiers exclusifs |
| --- | --- | --- | --- | --- |
| 1 | `reecriture-urls` | `api` | — | `apps/api/apps/file/management/commands/reecrire_urls.py` [nouveau], `apps/api/apps/file/regles_urls.json` [nouveau], `apps/api/apps/file/test_reecrire_urls.py` [nouveau] (et `apps/api/apps/file/management/__init__.py`, `…/commands/__init__.py` si absents) |
| 2 | `anonymisation` | `api` | — | `apps/api/apps/user/management/commands/anonymiser.py` [nouveau], `apps/api/apps/user/regles_anonymisation.json` [nouveau], `apps/api/apps/user/test_anonymiser.py` [nouveau], `apps/api/apps/user/management/commands/lister_fichiers_publics.py` [nouveau], `apps/api/apps/user/test_lister_fichiers_publics.py` [nouveau] (B1) |
| 3 | `outils-web` | `api` | — | `infra/helm/urbankiff-donnees/templates/pgadmin.yaml` [nouveau], `…/templates/outils-ingress.yaml` [nouveau], `…/templates/outils-middlewares.yaml` [nouveau], `…/templates/reseau-outils.yaml` [nouveau], `…/templates/rustfs.yaml`, `…/templates/_helpers.tpl`, `…/values-preprod.yaml`, `…/values-prod.yaml`, `…/values.yaml` (sections `hosts`, `ingress`, `pgadmin`, `rustfs.console` seulement), `…/tests/outils_test.yaml` [nouveau], `…/tests/rustfs_test.yaml`, `…/tests/valeurs-communes.yaml`, `docs/v1/infra/outils-donnees.md` [nouveau], `infra/helm/schemas/traefik.io/middleware_v1alpha1.json` [nouveau] (B6), `docs/v1/infra/kubernetes.md` (section « Outils web » seulement) |
| 4 | `jobs-donnees` | `api` | — | `infra/helm/urbankiff-donnees/templates/restauration-job.yaml`, `infra/helm/urbankiff-donnees/tests/restauration_test.yaml`, `infra/helm/urbankiff-donnees/values.yaml` (section `restauration` seulement), `infra/helm/urbankiff/templates/apres-restauration-job.yaml` [nouveau], `infra/helm/urbankiff/templates/export-anonyme-job.yaml` [nouveau], `infra/helm/urbankiff/values.yaml`, `infra/helm/urbankiff/tests/apres_restauration_test.yaml` [nouveau], `infra/helm/urbankiff/tests/export_anonyme_test.yaml` [nouveau], `docs/v1/infra/kubernetes.md` (section « Restauration et copie » seulement) |
| 5 | `deploiement` | `api` | — | `infra/deploiement/**`, `make/restauration.mk`, `make/deploiement.mk`, `.github/workflows/restauration.yml` [nouveau], `.github/workflows/copie-prod-preprod.yml` [nouveau], `docs/v1/infra/deploiement.md`, `docs/v1/infra/premier-deploiement-prod.md` |
| 6 | `iso-secrets` | `api` | — | `infra/helm/tests-transverses/**`, `infra/helm/urbankiff/values-preprod.yaml`, `infra/helm/urbankiff/values-prod.yaml`, `scripts/secrets/**`, `docs/v1/infra/secrets.md`, `docs/v1/infra/kubernetes.md` (section « Iso preprod / prod » seulement) |
| 7 | `ansible` | `api` | — | `infra/ansible/roles/deploiement/**`, `infra/ansible/group_vars/all.yml`, `infra/ansible/tests/**`, `infra/ansible/inventory.example.yml` (s'il existe), `docs/v1/infra/serveur.md` |

En lecture seule pour tous : cette spec, `CLAUDE.md`, `.claude/**`, `.github/workflows/devteam-ci.yml`,
`.github/workflows/deploiement.yml`, `make/devteam.mk`, `make/standard.mk`, `make/helm.mk`, `apps/api/project/**`, les
modèles de `apps/api/apps/**/models.py`, et les fichiers exclusifs des autres lots. `docs/v1/infra/kubernetes.md` est
découpé en sections : chaque lot crée ou modifie **sa** section seulement. `infra/helm/urbankiff-donnees/values.yaml`
est découpé de même (lot 3 : `hosts`, `ingress`, `pgadmin`, `rustfs.console` ; lot 4 : `restauration`).

### 8.3 Contrats entre lots

Fixés ici pour que les lots soient indépendants ; un lot qui a besoin d'en changer un s'arrête et le signale.

| Contrat | Valeur |
| --- | --- |
| Réécriture des URL (lot 1) | `python manage.py reecrire_urls` ; règles lues dans `apps/api/apps/file/regles_urls.json` (liste d'objets `{"source": "<préfixe>"}`, cible = `FILES_CDN_ENDPOINT` de l'environnement) ; idempotente ; journalise `reecrire_urls : <table>.<colonne> : <n> ligne(s)` ; code 0 si succès. Le fichier livré contient au moins `https://api.urbankiff.com/file` ; les règles `s3*` sont ajoutées après l'inspection. |
| Anonymisation (lot 2) | `python manage.py anonymiser` ; refuse de tourner (code 2, rien modifié) sauf si `ANONYMISATION_AUTORISEE=1` **et** `POSTGRES_HOST` vaut `127.0.0.1` ou `localhost` (garde-fou : jamais sur une vraie base) ; règles dans `apps/api/apps/user/regles_anonymisation.json` ; code 0 si succès. |
| Job de restauration (lot 4) | `infra/helm/urbankiff-donnees/templates/restauration-job.yaml`, Job `urbankiff-restauration`, rendu **seulement** si `restauration.prefixe` est non vide ; le script le rend par `helm template … --show-only templates/restauration-job.yaml --set restauration.prefixe=<préfixe>` avec les valeurs de la release en place ; remise à zéro du schéma `public` puis `pg_restore --no-owner --no-privileges --schema=public` ; `rclone copy` des fichiers ; aucune purge ; journal final `restauration terminée`. Les valeurs `restauration.active` et `restauration.purger` disparaissent. |
| Job après restauration (lot 4) | `infra/helm/urbankiff/templates/apres-restauration-job.yaml`, Job `urbankiff-apres-restauration`, rendu seulement si `apresRestauration.actif=true` ; image api ; `python manage.py migrate && python manage.py reecrire_urls && python manage.py prodseed && python manage.py clearcache`. |
| Job d'export anonymisé (lot 4) | `infra/helm/urbankiff/templates/export-anonyme-job.yaml`, Job `urbankiff-export-anonyme`, rendu seulement si `exportAnonyme.prefixe` et `exportAnonyme.bucketCible` sont non vides, **échec de rendu si `environnement` ≠ `prod`** ; PostgreSQL temporaire dans le pod (`127.0.0.1`), `python manage.py anonymiser` avec `ANONYMISATION_AUTORISEE=1`, dépôt sous `<bucketCible>/<prefixe>base.dump` et `fichiers/` ; journal final `export terminé`. |
| Script (lot 5) | `SSH_ORIGINAL_COMMAND` : `restaurer restauration/<AAAA-MM-JJ>[-prod-anonyme]/` (prod et preprod) ; `exporter-anonyme <AAAA-MM-JJ>` (**prod seulement**, refus code 2 sinon) ; bucket cible lu dans la clé `BUCKET_COPIE_PREPROD` de `/etc/urbankiff/deploy.prod.env`, préfixe `restauration/<date>-prod-anonyme/` ; arrêt de l'application par le label `app.kubernetes.io/part-of: urbankiff` (hors `urbankiff-pg`, Redis, RustFS), puis remise aux répliques d'avant. |
| Configuration du serveur (lot 7) | `deploy.prod.env` gagne `BUCKET_COPIE_PREPROD=<bucket Wasabi de la preprod>` (variable d'inventaire) ; `deploy.preprod.env` inchangé ; Role `deploy` gagne `traefik.io` `middlewares` en écriture. |
| Secrets (lots 5 et 6) | Nouveaux secrets `PGADMIN_EMAIL`, `PGADMIN_MOT_DE_PASSE` (dans `scripts/secrets/secrets.txt`, lot 6, et dans `SECRET_KEYS` du script, lot 5), consommés par le chart depuis `urbankiff-secrets` ; `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` en saisie masquée (lot 6). |
| Outils web (lot 3) | valeurs `hosts.db`, `hosts.stockage`, `ingress.classe`, `ingress.clusterIssuer` dans `urbankiff-donnees` ; Deployment `urbankiff-pgadmin` portant `app.kubernetes.io/part-of: urbankiff` ; console RustFS sur un port de console du StatefulSet existant ; Middlewares Traefik (`traefik.io/v1alpha1`) de limitation de débit et d'en-têtes. |
| Iso (lot 6) | écarts autorisés entre `values-preprod.yaml` et `values-prod.yaml` des deux charts : `environnement`, `hosts.*`, toute clé sous `*.ressources.*` ; `sms.actif: true` dans les deux. |

### 8.4 Table de contrôle

| Lots | Fichier ou interface partagé | Producteur → consommateur | Verdict |
| --- | --- | --- | --- |
| reecriture-urls / jobs-donnees | commande `reecrire_urls` | 1 → 4 | contrat 8.3 |
| anonymisation / jobs-donnees | commande `anonymiser`, garde-fou d'environnement | 2 → 4 | contrat 8.3 |
| jobs-donnees / deploiement | noms et conditions de rendu des trois Jobs, journaux de fin | 4 → 5 | contrat 8.3 |
| ansible / deploiement | clé `BUCKET_COPIE_PREPROD` de `deploy.prod.env` | 7 → 5 | contrat 8.3 (le script refuse les clés inconnues : les deux arrivent ensemble par la PR finale) |
| ansible / outils-web | droit `middlewares` du Role | 7 → 3 | contrat 8.3 |
| iso-secrets / deploiement | liste des secrets (`secrets.txt` ↔ `SECRET_KEYS`, contrôlée par `inventaire-cles.bats`) | 6 ↔ 5 | contrat 8.3 ; les deux listes sont modifiées à l'identique |
| iso-secrets / outils-web | valeurs `hosts.*` du chart `urbankiff-donnees` (écart autorisé) | 3 → 6 | contrat 8.3 |
| iso-secrets / outils-web | quota de la preprod (le pod pgAdmin entre dans le calcul de `controle.rb`) | 3 → 6 | le lot 3 vérifie avec `make helm-controle` ; un dépassement est signalé, pas contourné |
| outils-web / jobs-donnees | `infra/helm/urbankiff-donnees/values.yaml` | — | sections disjointes (8.2) |
| outils-web / jobs-donnees / iso-secrets | `docs/v1/infra/kubernetes.md` | — | sections disjointes (8.2) |

### 8.5 Arbitrages de la relecture croisée (2026-11-17)

Ils complètent et, en cas d'écart, remplacent les contrats de 8.3. Un plan qui contredit un arbitrage suit
l'arbitrage.

| # | Sujet | Décision | Lots |
| --- | --- | --- | --- |
| B1 | Fichiers copiés par l'export | Seulement les fichiers cités par le contenu public de la base anonymisée (décision du développeur). Le lot 2 ajoute la commande `python manage.py lister_fichiers_publics` (fichier exclusif du lot 2 : `apps/api/apps/user/management/commands/lister_fichiers_publics.py` [nouveau] et son test), qui écrit sur la sortie standard une clé d'objet du bucket par ligne, relative à la racine du bucket, dédoublonnée, à partir des colonnes publiques (`post_post.image/audio/video`, URL de fichiers dans `post_post.content/intro`, `page_page.content`, `banner_media.file`, `scrapper_scrapper.image/content`, `file_file.url` des fichiers cités) ; même garde-fou d'environnement que `anonymiser`. `anonymiser` remet `user_user.avatar` à la valeur par défaut de `prodseed` et vide `user_user.id_img`. Le lot 4 copie avec `rclone copy --files-from <liste>`. | 2, 4 |
| B2 | Préfixe `-prod-anonyme` en prod | `restaurer` **refuse** en prod un préfixe qui finit par `-prod-anonyme/` (code 2) : on ne charge jamais de données anonymisées dans la prod. | 5 |
| B3 | Région Wasabi de l'export | Le chart `urbankiff` gagne `wasabi.region` et `wasabi.endpoint` (lot 4), obligatoires quand l'export est rendu ; le script (lot 5) les passe en `--set` au rendu de l'export, comme pour `urbankiff-donnees`. | 4, 5 |
| B4 | `restauration.copierFichiers` | Supprimée avec `active` et `purger` ; le Job copie `fichiers/` s'il existe, sans échouer s'il est absent. Le script ne passe que `restauration.prefixe`. | 4, 5 |
| B5 | Politiques réseau | Les Jobs réutilisent les composants existants : après-restauration porte `migrations`, export porte `restauration` ; `reseau-donnees.yaml` et `reseau.yaml` restent intouchés. L'entrée pgAdmin → PostgreSQL est une politique additive du lot 3 (`reseau-outils.yaml`). | 3, 4 |
| B6 | Schéma Traefik | Le lot 3 ajoute `infra/helm/schemas/traefik.io/middleware_v1alpha1.json` [nouveau] à ses fichiers exclusifs (obtenu par `make helm-schemas`). | 3 |
| B7 | Lignes périmées de `kubernetes.md` | Le lot 4 remplace la puce « Job de restauration » de la section « PostgreSQL, version et restauration » par un renvoi à sa section ; le lot 6 corrige les lignes `sms.actif` du tableau « Variables et Secrets consommés ». Ce sont les seules lignes hors de leur section qu'ils modifient. | 4, 6 |
| B8 | Inventaire des secrets pendant la mission | `inventaire-cles.bats` (lot 5) tolère les clés du contrat (`PGADMIN_*`) absentes de `secrets.txt` tant que le lot 6 n'est pas fusionné ; l'égalité stricte est rétablie par une issue `role:dev` sur la branche de la mission après la fusion des lots 5 et 6. | 5, 6 |
| B9 | Quota de requêtes | Le lot 6 ajoute à `controle.rb` le contrôle du quota de **requêtes** de la preprod (1 536 Mi), en plus des limites ; le lot 3 dimensionne pgAdmin pour tenir dans les deux. | 3, 6 |
| B10 | Journal de fin du Job après restauration | Le script se fie à `status.succeeded` ; seuls `restauration terminée` et `export terminé` sont des journaux exigés. | 4, 5 |
| B11 | Échec de rendu de l'export hors prod | Seulement quand `exportAnonyme.prefixe` et `exportAnonyme.bucketCible` sont non vides (le rendu par défaut de la preprod reste valide). | 4 |

