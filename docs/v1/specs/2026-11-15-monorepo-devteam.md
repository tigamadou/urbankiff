# Urbankiff : mise en conformité avec le contrat devteam — préalable structurel (monorepo)

> Rédigée par `/devteam:conformite` le 2026-11-15 ; validée par le développeur le 2026-11-15. Elle s'exécute de
> façon **séquentielle** (le contrat n'étant pas rempli, une mission parallèle est impossible), par exemple avec
> `superpowers:subagent-driven-development`, à partir du plan joint
> (`docs/v1/plans/2026-11-15-monorepo-devteam.md`).

## 1. Diagnostic de départ

| Point | État | Constat |
| --- | --- | --- |
| structure | **bloquant** | dépôts git imbriqués : `apps/api`, `apps/minio`, `apps/mobile`, `apps/nextjs`, `apps/panel` ; `apps` ignoré par le `.gitignore` racine |
| 1 docker | absent | pas de `make help` ; commandes hôte dans le Makefile (`code`, `scp`/`ssh`, `cd apps/nextjs && docker compose`) |
| 2 agent_env | absent | pas de cibles `agent-*` ; ports et noms de conteneurs figés dans `docker-compose.yml` |
| 3 isolation | absent | pas de garde-fou ; Postgres, Redis, RustFS, Mailhog partagés |
| 4 cibles | absent | aucune des neuf cibles |
| 5 branches | absent | fichier projet absent (`development` existe) |
| 6 ci | absent | seulement des workflows de déploiement, par dépôt |
| 7 budget | absent | pas de document de profils |
| 8 generes_migrations | absent | migrations Django (api), générés non recensés |
| 9 taches_planifiees | partiel | `docker info` OK, `create_scheduled_task` présent ; section absente |

Le bloc 0 étant bloquant, cette spec ne porte **que** sur la structure. Les points 1 à 9 seront traités par un
nouveau passage de `/devteam:conformite` sur le monorepo.

## 2. Ce qui reste à construire, et pourquoi

### Structure : passage en monorepo

**Décision du développeur (2026-11-15)** : monorepo dans `tigamadou/urbankiff`.

**Périmètre** (réponses du questionnaire) :

| Dépôt source | Destination | Commits (`development`) | Décision |
| --- | --- | --- | --- |
| `tigamadou/urbankiff-api` | `apps/api` | 370 | importé avec historique |
| `tigamadou/urbankiff-nextjs` | `apps/nextjs` | 112 | importé avec historique |
| `tigamadou/urbankiff-panel` | `apps/panel` | 308 | importé avec historique |
| `tigamadou/urbankiff-minio` | `apps/minio` | 17 | importé avec historique |
| `tigamadou/urbankiff-mobile` | — | 8 | **exclu** : reste un dépôt séparé, hors missions ; `apps/mobile/` ignoré |
| `apps/backup_service` (non versionné) | `apps/backup_service` | — | **versionné** (sans ses `.env*`) |

Les chemins `apps/<app>` restent identiques : `docker-compose.yml` et les variables `*_FOLDER` de `.env` ne changent
pas.

**Méthode d'import (D1)** : pour chaque dépôt, clone frais de `development`, réécriture avec
`git filter-repo --to-subdirectory-filter apps/<app> --tag-rename '':'<app>/'`, puis
`git merge --allow-unrelated-histories` dans la branche de travail. Pourquoi plutôt que `git subtree add` : chaque
commit importé porte les vrais chemins `apps/<app>/…`, donc `git log -- apps/api/…` et `git blame` fonctionnent sans
`--follow`. `git filter-repo` n'est pas un outil de l'hôte : il tourne dans un conteneur via une cible `make`
temporaire (`make/monorepo.mk`). Le travail se fait dans un worktree `../urbankiff-wt-monorepo` (où `apps/` est vide),
jamais par-dessus les dossiers `apps/*` actuels, qui sont des dépôts vivants.

**Branches ouvertes (D2)** : seule `development` de chaque dépôt est importée. Avant la bascule, chaque branche
locale non poussée est poussée (`nextjs` : `feat/celtis_add`, `feat/docker-edited*` ; `panel` :
`fix/new_user_invitation`, `feat/file_library_post`, `feat/panel_files`, `feat/workflow_layout`), puis le
développeur décide pour chacune : fusionnée dans `development` du dépôt source **avant** l'import, ou abandonnée
(elle reste lisible dans le dépôt archivé). Aucune branche n'est fusionnée ni supprimée sans son accord. Les
`main`/`staging` des dépôts sources ne sont pas importées.

**Secrets versionnés (D3, décidé le 2026-11-15)** : `apps/api/env.prod`, `env.preprod`, `apps/minio/.env.prod`,
`.env.preprod`, `apps/panel/.env.prod`, `.env.preprod` contiennent des secrets (`SECRET_KEY`, `SMTP_PASSWORD`,
`TWILIO_AUTH_TOKEN`, `MINIO_ROOT_PASSWORD`, clés MinIO) et les workflows de déploiement les copient en `.env`.
Décision : l'import les **conserve tels quels** (même exposition qu'aujourd'hui : dépôts privés, même propriétaire).
Le passage des secrets en GitHub Secrets, avec rotation, est un chantier distinct, hors de cette spec. Option écartée :
les purger de l'historique à l'import (`--invert-paths`), ce qui aurait cassé les déploiements tant que les workflows
ne lisent pas de secrets GitHub.

**`.gitignore` racine** : la ligne `apps` est remplacée par `apps/mobile/`, et on ajoute les fichiers d'environnement
locaux non versionnés aujourd'hui (`apps/*/.env`, `apps/backup_service/.env*`), plus le dossier de travail
`.monorepo-work/`. Les `.gitignore` des applications continuent de s'appliquer à leur sous-dossier.

**CI et déploiement à unifier** : les workflows `deploy-to-preprod.yml`, `deploy-to-prod.yml` d'api, nextjs, panel et
minio, ainsi que le `eslint.yml` de nextjs, passent dans `.github/workflows/` à la racine, renommés
`<app>-<nom>.yml`, avec `defaults.run.working-directory: apps/<app>` et :

- déclenchement sur `release` (api, nextjs, panel) : garde
  `if: startsWith(github.event.release.tag_name, '<app>/')`, les releases étant désormais communes au dépôt ;
  convention de tag `<app>/vX.Y.Z` (les tags importés sont déjà préfixés par D1) ;
- déclenchement sur `push` (minio) et `eslint.yml` : filtre `paths: ['apps/<app>/**']` ;
- étapes qui zippent ou copient le projet : chemins ajustés au sous-dossier.

Les secrets GitHub Actions des quatre dépôts (`SSH_PRIVATE_KEY`, `SSH_HOST`, `PREPROD_DB_*`…) doivent être recréés
dans `tigamadou/urbankiff` : c'est une **action du développeur** (configuration hors du code), listée dans le plan.
La CI à check unique (`ci-ok`) relève du point 6 et vient au passage suivant de `/devteam:conformite`.

**Makefile racine** : `clean-all` (`rm -rf apps`) effacerait désormais du code versionné : supprimée. `pull-all`
(dossiers `ubnews*` qui n'existent plus) et `open_all` (chemin `apps/frontend` absent) sont obsolètes : supprimées.
Le reste est inchangé à cette étape.

**Bascule** :

1. PR `chore/monorepo` → `development`, fusionnée par le développeur.
2. Sur chaque poste : sauvegarde des `.env` locaux non versionnés des `apps/*`, puis nouveau clone (ou déplacement
   des anciens `apps/<app>` hors du dépôt), puis restauration des `.env`.
3. Les quatre dépôts sources passent en lecture seule (archivés sur GitHub), avec une ligne de README qui pointe vers
   le monorepo. Action du développeur, après un premier déploiement preprod réussi depuis le monorepo.

**Risques** :

- Déploiement cassé après la bascule (chemins, secrets manquants). Parade : premier déploiement en preprod via une
  pré-release `api/v…` avant toute release de prod ; dépôts sources non archivés tant que ce n'est pas fait.
- Commits faits dans un dépôt source entre l'import et la bascule. Parade : gel annoncé des dépôts sources pendant
  la bascule, et vérification que leur `development` n'a pas bougé (comparaison de SHA notée dans le plan).
- Taille du dépôt : `yarn-error.log` (183 Ko, nextjs) et les lockfiles sont importés tels quels, pas de nettoyage à
  cette étape.
- Hors structure, mais à retenir pour le point 6 : la protection de branche est refusée sur ce dépôt privé
  (GitHub Free, HTTP 403). Le check requis `ci-ok` ne pourra pas être imposé par GitHub sans passer à GitHub Pro/Team
  ou rendre le dépôt public.

## 3. Hors périmètre

- Les points 1 à 9 du contrat (cibles `make`, CI `ci-ok`, environnement d'agent, isolation, budget) : passage suivant
  de `/devteam:conformite`.
- Le dépôt `urbankiff-mobile`.
- Le code applicatif, la configuration Caddy et Compose, la production (aucun déploiement de prod n'est lancé par la
  mission), le passage des secrets en GitHub Secrets et leur rotation.

## 4. Critère de fin

- `bash <plugin>/outils/diagnostic.sh <projet>` renvoie `structure ok` (les points 1 à 9 restent ouverts, traités au
  passage suivant).
- `git log --oneline -- apps/<app> | wc -l` ≥ le nombre de commits de `development` du dépôt source, pour chaque
  application importée.
- `docker compose config` réussit et `make start` lance la stack comme avant la bascule.
- Un déploiement preprod d'au moins une application réussit depuis le monorepo (constaté par le développeur).
