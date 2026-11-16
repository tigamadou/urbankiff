# Urbankiff en monorepo (préalable devteam) — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, vérifications d'abord. Les étapes utilisent la syntaxe à
> cases `- [ ]`.

**Objectif** : réunir api, nextjs, panel, minio (avec historique) et backup_service dans `tigamadou/urbankiff` pour
lever le bloquant `structure` du contrat devteam.

**Architecture** : import par `git filter-repo --to-subdirectory-filter` (conteneurisé) puis fusion
`--allow-unrelated-histories`, dans un worktree dédié ; chemins `apps/<app>` inchangés.

**Stack** : git, Docker, GitHub Actions, Make.

**Spec** : `docs/v1/specs/2026-11-15-monorepo-devteam.md` (elle fait autorité). Plan séquentiel hors mission devteam
(le contrat n'est pas encore rempli).

## Exécution

- **Mission** : sans objet (mise en conformité) · **Issue** : aucune
- **Branche** : `chore/monorepo` · **Base** : `development` · **Profil** : sans objet
- **Dépendances** : aucune.
- Le travail se fait dans le worktree `../urbankiff-wt-monorepo` (créé par la tâche 2), jamais dans le checkout
  principal, dont les `apps/*` sont des dépôts vivants.
- Aucun commit sans demande explicite du développeur ; jamais de commit sur `development`, jamais de `--force`, jamais
  de `--no-verify`, aucune mention d'IA dans les messages.
- Les actions marquées **(développeur)** ne sont pas faites par l'agent : il s'arrête et les demande.

## Avancement

Statut : 🟡 en cours (tâches 1 à 8 ✅ le 2026-11-15) · Prochaine tâche : 9 (développeur)

- [x] **Tâche 1** Gel et inventaire des dépôts sources
- [x] **Tâche 2** Branche, worktree et outil d'import conteneurisé
- [x] **Tâche 3** `.gitignore` racine
- [x] **Tâche 4** Import des quatre dépôts avec historique
- [x] **Tâche 5** Versionnement de `apps/backup_service`
- [x] **Tâche 6** Workflows de déploiement à la racine
- [x] **Tâche 7** Makefile racine et documentation
- [x] **Tâche 8** Vérification
- [ ] **Tâche 9** Bascule (développeur)

> Reprise : 2026-11-15, tâches 1 à 8 faites dans ../urbankiff-wt-monorepo. Seuls les 4 merges d'import sont commités, le reste est non commité. Restent : commit du reste, secrets Actions (SSH_HOST, SSH_PRIVATE_KEY, SSH_USER, DB_*, PREPROD_DB_*), branche staging pour la preprod minio, puis tâche 9.

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après vérification verte**.

## Fichiers du lot (exclusifs)

- `.gitignore`
- `Makefile`
- `make/monorepo.mk` [nouveau]
- `apps/api/**` [nouveau, importé]
- `apps/nextjs/**` [nouveau, importé]
- `apps/panel/**` [nouveau, importé]
- `apps/minio/**` [nouveau, importé]
- `apps/backup_service/**` [nouveau]
- `.github/workflows/**` [nouveau]
- `README.md`
- `docs/v1/plans/2026-11-15-monorepo-devteam.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docker-compose.yml`, `configs/**`, `caddyprod/**`, `deploys/**`, `.env`, `.env.template`, le code applicatif importé
(aucune modification de contenu de `apps/<app>` hors déplacement de `.github/`).

Besoin d'y toucher → **s'arrêter et le signaler**.

## Contraintes globales

Pas de code applicatif modifié ; commandes outillées via `make` et conteneurs (seuls `docker`, `make`, `git`, `gh`
sur l'hôte) ; aucun secret ajouté ; secrets déjà versionnés conservés tels quels (spec, D3).

## Points de revue

1. Nombre de commits par `apps/<app>` conforme au dépôt source, tags préfixés `<app>/`.
2. Aucun `.env` local (non versionné aujourd'hui) n'entre dans le dépôt.
3. Chaque workflow ne se déclenche que pour son application.

---

### Tâche 1 : gel et inventaire des dépôts sources

- [ ] Pour api, nextjs, panel, minio : `git -C apps/<app> fetch --all`, lister les branches locales non poussées et
  les branches distantes ; noter dans « Reprise » le SHA de `origin/development`.
- [ ] **(développeur)** Pour chaque branche ouverte (`nextjs` : `feat/celtis_add`, `feat/docker-edited*` ; `panel` :
  `fix/new_user_invitation`, `feat/file_library_post`, `feat/panel_files`, `feat/workflow_layout`) : pousser,
  fusionner dans `development` du dépôt source, ou abandonner.
- [ ] **(développeur)** Annoncer le gel des dépôts sources jusqu'à la tâche 9.

### Tâche 2 : branche, worktree et outil d'import conteneurisé

**Fichiers :** Créer `make/monorepo.mk` ; Modifier `Makefile` (inclusion).

- [ ] `git worktree add -b chore/monorepo ../urbankiff-wt-monorepo development`.
- [ ] `make/monorepo.mk` : cible `monorepo-import APP=<app> REPO=<url>` qui, dans un conteneur (image Python
  épinglée, `pip install git-filter-repo` à version fixée, `.monorepo-work/` monté, clé SSH en lecture seule ou
  clone HTTPS via `gh auth token`), clone `development`, applique
  `--to-subdirectory-filter apps/$(APP) --tag-rename '':'$(APP)/'` ; puis, sur l'hôte, `git fetch` du clone réécrit
  et `git merge --allow-unrelated-histories --no-edit`.
- [ ] Vérification : `make -n monorepo-import APP=x REPO=y` affiche les commandes attendues.

### Tâche 3 : `.gitignore` racine

- [ ] Remplacer `apps` par `apps/mobile/` ; ajouter `apps/*/.env`, `apps/backup_service/.env*`, `.monorepo-work/`.
- [ ] Vérification : `git check-ignore -v apps/mobile/x apps/api/.env apps/backup_service/.env.prod` les ignore tous ;
  `git check-ignore apps/api/env.prod` ne l'ignore pas (versionné, D3).

### Tâche 4 : import des quatre dépôts avec historique

Pour chaque `<app>` dans api, nextjs, panel, minio :

- [ ] Vérifier que `origin/development` du dépôt source a encore le SHA noté en tâche 1.
- [ ] `make monorepo-import APP=<app> REPO=git@github.com:tigamadou/urbankiff-<app>.git`.
- [ ] Vérification : `git log --oneline -- apps/<app> | wc -l` ≥ le nombre de commits du dépôt source ;
  `git tag -l '<app>/*'` liste les tags du dépôt source ; `git ls-files apps/<app> | head` montre des chemins
  `apps/<app>/…`.

### Tâche 5 : versionnement de `apps/backup_service`

- [ ] **(développeur)** Fournir le contenu de `apps/backup_service` (copie du dossier actuel du checkout principal,
  hors `.env*`).
- [ ] Ajouter `Dockerfile`, `README.md`, `backup.sh`, `docker-compose.yml`, `docker-compose-prod.yml`,
  `entrypoint.sh`.
- [ ] Vérification : `git ls-files apps/backup_service` ne contient aucun `.env*`.

### Tâche 6 : workflows de déploiement à la racine

- [ ] `git mv apps/<app>/.github/workflows/<nom>.yml .github/workflows/<app>-<nom>.yml` pour api, nextjs, panel,
  minio (et `nextjs-eslint.yml`).
- [ ] Ajouter `defaults.run.working-directory: apps/<app>` ; garde
  `if: startsWith(github.event.release.tag_name, '<app>/')` sur les déclenchements `release` ; `paths:
  ['apps/<app>/**']` sur les déclenchements `push`/`pull_request` ; ajuster les étapes `zip`/`scp` qui ciblent la
  racine du dépôt.
- [ ] Vérification : lint des workflows dans un conteneur (`rhysd/actionlint`, version épinglée) via une cible de
  `make/monorepo.mk` ; aucun dossier `apps/*/.github/` restant.
- [ ] **(développeur)** Recréer dans `tigamadou/urbankiff` les secrets Actions utilisés par ces workflows (liste
  produite par `grep -ho 'secrets\.[A-Z_]*' .github/workflows/*.yml | sort -u`).

### Tâche 7 : Makefile racine et documentation

- [ ] Supprimer les cibles `clean-all`, `pull-all`, `open_all`.
- [ ] `README.md` : structure monorepo (applications, mobile à part), convention de tag `<app>/vX.Y.Z`, procédure de
  bascule d'un poste (spec, Bascule, étape 2).

### Tâche 8 : vérification

- [ ] `bash <plugin>/outils/diagnostic.sh ../urbankiff-wt-monorepo` : ligne `structure ok`.
- [ ] `docker compose config` réussit dans le worktree (avec une copie du `.env` racine).
- [ ] Points de revue 1 à 3 vérifiés ; rapport final : `Statut: DONE|PARTIAL|BLOCKED`, commandes et résultats.

### Tâche 9 : bascule (développeur)

- [ ] PR `chore/monorepo` → `development`, revue et fusion.
- [ ] Sur chaque poste : sauvegarder les `.env` des `apps/*`, recloner, restaurer, `make start`.
- [ ] Pré-release `api/v…` → déploiement preprod constaté.
- [ ] Archiver les dépôts sources (README pointant vers le monorepo) ; supprimer le worktree.
- [ ] Relancer `/devteam:conformite` pour les points 1 à 9.
