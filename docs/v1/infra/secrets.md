# Inventaire des secrets et variables

Source : spec `docs/v1/specs/2026-11-16-publication-depot-public.md`. Ce document ne contient **jamais de valeur**,
seulement des noms. Les valeurs vivent dans GitHub (Settings → Environments → `prod` / `preprod`) et sont posées par
`make secrets-definir ENV=<prod|preprod> REPO=tigamadou/urbankiff` (script `scripts/secrets/definir-secrets.sh`).
La procédure de révocation des anciennes valeurs est dans `docs/v1/infra/rotation-secrets.md`.

Règles :

- Le nom GitHub est le nom de la variable lue par le code ; il est défini **par environnement** (`prod`, `preprod`),
  avec une valeur différente dans chacun.
- Les secrets et variables de déploiement (`DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS`) sont posés à la
  main par le développeur à la mise en service (section dédiée plus bas), hors du script ; les anciens sont seulement
  révoqués.
- Aucune valeur de développement local (voir la fin de ce document) n'est réutilisée en prod ou en preprod.

## Secrets (environnements `prod` et `preprod`)

| Nom | Usage | Emplacement avant la publication | Révocation de l'ancienne valeur | Nouvelle valeur |
| --- | --- | --- | --- | --- |
| `SECRET_KEY` | clé Django (sessions, jetons) | `apps/api/env.prod`, `env.preprod` (versionnés) | sans effet dès qu'elle n'est plus déployée (prod arrêtée) | aléatoire, 64 caractères, script |
| `POSTGRES_PASSWORD` | mot de passe de l'utilisateur applicatif de la base | secrets `DB_PASSWORD`, `PREPROD_DB_PASSWORD` de l'ancien dépôt | `ALTER ROLE` sur la base de B (runbook, mesures conservatoires) | généré par CloudNativePG (Secret `urbankiff-pg-app`), absent de `secrets.txt` |
| `REDIS_PASSWORD` | mot de passe Redis (Redis n'en avait pas) | — | Redis actuel arrêté (mesures conservatoires) | aléatoire, 40 caractères, script |
| `MINIO_ROOT_USER` | administrateur du stockage S3 | `apps/api/env.*`, `apps/minio/.env.*` (versionnés) | port public de MinIO fermé ; instance de A retirée à sa reconstruction, après export des objets | saisie masquée (script), connu du développeur : login de la console du stockage |
| `MINIO_ROOT_PASSWORD` | mot de passe administrateur du stockage S3 | idem | idem | saisie masquée (script), connu du développeur : mot de passe de la console du stockage |
| `PGADMIN_EMAIL` | login de pgAdmin (outil web d'administration de la base) | — | — | saisie masquée (script) |
| `PGADMIN_MOT_DE_PASSE` | mot de passe de pgAdmin | — | — | saisie masquée (script) |
| `SMTP_USERNAME` | identifiant du fournisseur SMTP | `apps/api/env.*` (versionnés) | console du fournisseur SMTP : révoquer le jeton actuel | saisie masquée (script) |
| `SMTP_PASSWORD` | jeton du fournisseur SMTP | idem | idem | saisie masquée (script) |
| `TWILIO_ACCOUNT_SID` | compte Twilio (SMS) | `apps/api/env.*` (versionnés) | — (identifiant de compte, inchangé) | saisie masquée (script) |
| `TWILIO_AUTH_TOKEN` | jeton d'authentification Twilio | idem | console Twilio : régénérer le jeton | saisie masquée (script) |
| `SOCIAL_AUTH_GOOGLE_OAUTH2_KEY` | identifiant client OAuth Google (connexion) | non versionné | — | saisie masquée (script) |
| `SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET` | secret client OAuth Google | non versionné | console Google Cloud : réinitialiser le secret client | saisie masquée (script) |
| `WASABI_ACCESS_KEY_ID` | identifiant d'accès Wasabi (sauvegardes CloudNativePG, copie des fichiers) | — | — | saisie masquée (script) |
| `WASABI_SECRET_ACCESS_KEY` | clé secrète Wasabi (mêmes usages) | — | — | saisie masquée (script) |
| `DJANGO_SUPERUSER_PASSWORD` | mot de passe de l'administrateur créé par `prodseed` (sans lui, aucun administrateur n'est créé) | codé en dur (`password`) dans `prodseed.py` | sur une base migrée où l'administrateur existe déjà : changer son mot de passe avant la remise en service (mission k3s) | aléatoire, 40 caractères, script |

## Variables non secrètes (environnements `prod` et `preprod`)

Posées par le même script depuis `scripts/secrets/variables-<env>.txt`.

| Nom | Usage |
| --- | --- |
| `DJANGO_ENV` | mode de l'api |
| `ALLOWED_HOSTS` | hôtes acceptés par Django ; obligatoire et sans `*` quand `DJANGO_ENV` vaut `staging` ou `production` (l'api refuse de démarrer sinon). Inclut `urbankiff-api` : le rendu serveur de Next appelle l'api par le Service interne (`BACKEND_URL=http://urbankiff-api:8000`), sinon `DisallowedHost` et pages vides |
| `WEB_URL` | URL publique du front |
| `API_URL` | URL publique de l'api |
| `SMTP_SERVER` | serveur SMTP |
| `SMTP_PORT` | port SMTP |
| `MINIO_DEFAULT_BUCKETS` | bucket des fichiers |
| `FILES_CDN_ENDPOINT` | URL de service des fichiers |
| `NEXT_PUBLIC_BACKEND_URL` | URL de l'api vue du navigateur (nextjs) |
| `BACKEND_URL` | URL de l'api vue du serveur Next |
| `NEXT_PUBLIC_BACKEND_URL_FRONT` | URL du front (nextjs) |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | identifiant OAuth Google public (nextjs) |
| `REACT_APP_BACKEND_URL` | URL de l'api (panel) |
| `REACT_APP_IMAGEKIT_ENDPOINT` | URL de service des images (panel) |
| `WASABI_REGION` | région du bucket Wasabi de l'environnement |
| `WASABI_BUCKET` | bucket Wasabi de l'environnement (un par environnement) |

Générées ou construites par le chart (hors `secrets.txt` et fichiers de variables) :

| Nom | Origine |
| --- | --- |
| `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD`, `POSTGRES_HOST` | générés par CloudNativePG (Secret `urbankiff-pg-app`) |
| `REDIS_ENDPOINT` | construit par le chart à partir de `REDIS_PASSWORD` |
| `MINIO_ENDPOINT` | construit par le chart (service interne RustFS) |

Non reprises :

| Nom | Raison |
| --- | --- |
| `REACT_APP_MINIO_ENDPOINT`, `REACT_APP_MINIO_BUCKETNAME`, `NEXT_PUBLIC_BASENAME`, `REACT_APP_BASENAME` | non lues par le code ou vides dans les anciens fichiers : valeur par défaut du code |
| `MINIO_CONTAINER_NAME`, `MINIO_VOLUME_NAME` | propres à l'ancien Compose de prod, remplacé par k3s |

## Secrets et variables de déploiement

Posés à la main par le développeur dans chaque environnement GitHub à la mise en service, **hors script** : absents de
`secrets.txt` et des fichiers de variables.

| Nom | Type | Usage |
| --- | --- | --- |
| `DEPLOY_SSH_KEY` | secret | clé privée SSH du compte `deploy` utilisée par la CI (clé de déploiement du poste du développeur incluse) |
| `DEPLOY_HOST` | variable | nom d'hôte ou adresse du serveur du déploiement |
| `DEPLOY_KNOWN_HOSTS` | variable | empreinte du serveur (`known_hosts`) pour la connexion SSH de la CI |

La preprod utilise le même compte Twilio que la prod : `TWILIO_ACCOUNT_SID` et `TWILIO_AUTH_TOKEN` de `preprod` reçoivent
les valeurs de la prod (saisie masquée) ; la preprod envoie de vrais SMS.

`MINIO_ROOT_USER` et `MINIO_ROOT_PASSWORD` sont des secrets saisis (masqués) et connus du développeur, qui s'en sert pour
la console du stockage. Changer la valeur d'un environnement déjà en service demande de redémarrer RustFS.
`PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` donnent l'accès à pgAdmin.

## Anciens secrets et configurations retirés

| Nom | Ancien usage | Traitement |
| --- | --- | --- |
| `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER` | déploiements par `scp`/`ssh` (anciens workflows) | clés publiques retirées de `authorized_keys` sur A et B ; la mission k3s crée sa propre clé |
| `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `PREPROD_DB_*` | base de l'ancien déploiement | remplacés par `POSTGRES_*` ; mot de passe changé sur B |
| Configuration Firebase du panel | Firestore (menus), Firebase Auth (vérification d'email, réinitialisation) | sortie du code (`apps/panel/src/firebase/base.js` lit `REACT_APP_FIREBASE_*`, non définies) ; projet Firebase supprimé |
| `FCM_API_KEY` | clé serveur Firebase Cloud Messaging, en clair dans `apps/api/project/settings.py` (`FCM_API_KEY` et `GCM_API_KEY`) | sortie du code (lue dans `FCM_API_KEY`, non définie : l'API historique FCM est arrêtée par Google) ; révoquée par la suppression du projet Firebase, **avant** la publication ; règle gitleaks dédiée |
| SID et jeton Twilio dans les gabarits | recopiés dans `apps/api/env.template`, `apps/api/.env.temp` et `apps/nextjs/env.example` (`NEXT_PUBLIC_TWILIO_*`) | valeurs vidées ; les `.env` locaux copiés de ces gabarits contiennent encore l'ancien jeton : il est révoqué chez Twilio |
| `BUCKETEER_AWS_ACCESS_KEY_ID`, `BUCKETEER_AWS_SECRET_ACCESS_KEY`, `BUCKETEER_AWS_REGION`, `BUCKETEER_BUCKET_NAME` | ancien stockage S3 Heroku | obsolète (compte fermé) ; code retiré par le lot nettoyage |
| `REACT_APP_MINIO_ACCESS_KEY_ID`, `REACT_APP_MINIO_SECRET_KEY` | définis pour le panel | non définis ; code retiré par le lot nettoyage |

## Valeurs de développement local (versionnées, sans usage hors du poste)

`.env.template`, `apps/api/.env.temp`, `apps/api/env.template`, `apps/panel/.env.development`,
`apps/nextjs/env.example`, `configs/pgadmin/pgpass`, identifiants du `README.md` : valeurs du Compose local
uniquement ; les règles de `.gitleaks.toml` ne les détectent pas, aucune exception n'est déclarée. Aucune ne doit être
reprise en prod ou en preprod.
