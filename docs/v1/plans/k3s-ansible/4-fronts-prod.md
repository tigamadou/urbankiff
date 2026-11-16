# Images de production des fronts (Next et panel) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : aucun arbitrage ne modifie ce lot ; REACT_APP_FIREBASE_*, REACT_APP_IMGPROXY_* et REACT_APP_BASENAME restent absents du bundle (Firebase inactif par décision, imgproxy supprimé, BASENAME vide par défaut) : ce n est pas un défaut.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : produire les Dockerfile de production de Next (standalone) et du panel (construit dans le Dockerfile,
servi statiquement en SPA), construits par environnement via des arguments de construction, non root (UID 10001),
compatibles `readOnlyRootFilesystem`.

**Architecture** : Next : Dockerfile multi-étapes (dépendances, build, exécution) ; la dernière étape est l'image de
prod ; le Compose local utilise `Dockerfile.dev` (non touché). Panel : Dockerfile multi-étapes (build `craco build`,
puis `serve` épinglé avec `serve.json` pour la SPA). Les `NEXT_PUBLIC_*` et `REACT_APP_*` sont des `ARG` convertis en
`ENV` dans l'étape de build uniquement (valeurs inscrites dans le JavaScript, jamais dans l'étape finale). Un
`.dockerignore` par application exclut `.env*`, `node_modules`, `.next`, `build`, `.git`.

**Stack** : Docker (`docker buildx`, `linux/amd64`), Node 22 (Next, `.nvmrc`) et Node 20 (panel), yarn, Next.js
standalone, craco / react-scripts, `serve`.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité ; voir
aussi 5.5 et le contrat 8.3). Plan de la mission `k3s-ansible`, lot 4 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/k3s-ansible-fronts-prod` · **Base** : `feature/k3s-ansible` · **Profil** : `api`
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 1

- [ ] **Tâche 1** Image de production de Next · `feature/k3s-ansible-fronts-prod`
  - [ ] `.dockerignore` et tests (construction, lecture seule, 200, grep des valeurs) en échec
  - [ ] Dockerfile multi-étapes, tests verts
- [ ] **Tâche 2** Image de production du panel · `feature/k3s-ansible-fronts-prod`
  - [ ] `.dockerignore`, `serve.json` et tests en échec
  - [ ] Dockerfile multi-étapes, tests verts
- [ ] **Tâche 3** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `apps/nextjs/Dockerfile`
- `apps/nextjs/.dockerignore` [nouveau]
- `apps/panel/Dockerfile`
- `apps/panel/.dockerignore` [nouveau]
- `apps/panel/serve.json` [nouveau]
- `docs/v1/plans/k3s-ansible/4-fronts-prod.md` (ce plan : Avancement)

## Fichiers en lecture seule

Tout le reste, en particulier : `apps/nextjs/Dockerfile.dev`, `apps/nextjs/next.config.ts`, le code source des deux
fronts (`apps/nextjs/src/**`, `apps/panel/src/**`), `apps/panel/craco.config.js`, `apps/*/package.json`, `yarn.lock`,
les `.env*`, `docker-compose.yml`, `Makefile` et `make/*.mk`, la spec, et les fichiers exclusifs des autres lots
(`apps/*/docker-compose-prod.yml` appartiennent à `nettoyage`).

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : sur l'hôte seuls `docker`, `make`, `git`, `gh` ;
`make lint` / `make typecheck` portent sur le code des applications ; nextjs n'a pas de tests, e2e sans objet.
Ce lot ne contient pas de code applicatif : « test » = commande `docker` qui échoue avant l'implémentation et réussit
après. Au minimum : aucun mock ; ne jamais modifier le code de production (sources des fronts, `next.config.ts`) pour
faire passer un test (s'arrêter et le signaler) ; pas de `retry` ni de contournement pour masquer une instabilité ;
aucune valeur secrète dans une image ni dans le plan (les valeurs de test sont fictives, par exemple
`https://api.test.invalid`) ; images de test étiquetées `urbankiff-test-*:lot4` et supprimées en fin de lot
(`docker rmi`, `docker rm -f`).

Contrats à respecter (8.3) :
- Next : port 3000, UID 10001, écritures dans `/tmp` et `/app/.next/cache` ; arguments `NEXT_PUBLIC_BACKEND_URL`,
  `NEXT_PUBLIC_BACKEND_URL_FRONT`, `NEXT_PUBLIC_GOOGLE_CLIENT_ID`, `BACKEND_URL`.
- panel : construit dans le Dockerfile, statique sur 8080, UID 10001, écritures dans `/tmp` ; arguments
  `REACT_APP_BACKEND_URL`, `REACT_APP_IMAGEKIT_ENDPOINT`.

## Points de revue

1. Aucun `.env*` ni secret ne peut entrer dans l'image (`.dockerignore`, pas de `COPY . .` sans filtre) ; les valeurs
   d'`ARG` ne se retrouvent que dans l'étape de build, pas dans les `ENV` de l'image finale.
2. `HOSTNAME` : Kubernetes écrase la variable `HOSTNAME` du pod, ce qui ferait écouter Next sur le nom du pod ;
   la commande de démarrage force `HOSTNAME=0.0.0.0`.
3. Compatibilité `readOnlyRootFilesystem` : tous les chemins écrits (`/tmp`, `/app/.next/cache`, `HOME`) sont
   déclarés ; le test tourne avec `--read-only` et seulement ces montages `tmpfs`.
4. Le Compose local est inchangé (`git diff` du lot ne touche ni `Dockerfile.dev` ni `docker-compose.yml`).
5. Versions de `serve` et des images de base épinglées (pas de `latest`) ; `serve` installé à la construction, pas au
   démarrage.

Pas d'UI modifiée : pas de contrôle visuel ni d'e2e.

---

### Tâche 1 : image de production de Next

**Fichiers :**
- Créer : `apps/nextjs/.dockerignore`
- Modifier : `apps/nextjs/Dockerfile`
- Test : commandes `docker` ci-dessous (aucun fichier de test versionné)

**Interfaces :**
- Consomme : `apps/nextjs/package.json`, `yarn.lock`, `next.config.ts` (`output: 'standalone'`), `public/`.
- Produit : image `linux/amd64`, port 3000, UID 10001, arguments `NEXT_PUBLIC_BACKEND_URL`,
  `NEXT_PUBLIC_BACKEND_URL_FRONT`, `NEXT_PUBLIC_GOOGLE_CLIENT_ID`, `BACKEND_URL` ; consommé par les lots `charts` et
  `deploiement`.

- [ ] **Étape 1 : tests d'abord.** Depuis `apps/nextjs` (contexte de construction), lancer et constater l'échec avec le
  Dockerfile actuel (il exige un `.next/` pré-construit, absent) :
  - construction : `docker buildx build --platform linux/amd64 --load -t urbankiff-test-nextjs:lot4 --build-arg NEXT_PUBLIC_BACKEND_URL=https://api.test.invalid --build-arg NEXT_PUBLIC_BACKEND_URL_FRONT=https://front-api.test.invalid --build-arg NEXT_PUBLIC_GOOGLE_CLIENT_ID=test-google-id.invalid --build-arg BACKEND_URL=https://internal-api.test.invalid apps/nextjs` ;
  - lancement : `docker run -d --name urbankiff-test-nextjs --platform linux/amd64 --read-only --tmpfs /tmp --tmpfs /app/.next/cache --user 10001:10001 -p 3000 urbankiff-test-nextjs:lot4` (le test réel pose `--tmpfs` avec les options `uid=10001` si l'écriture est refusée) ;
  - utilisateur : `docker exec urbankiff-test-nextjs id -u` affiche `10001` ;
  - HTTP : `docker exec urbankiff-test-nextjs wget -S -O /dev/null http://127.0.0.1:3000/` répond `200` (attendre
    le démarrage par une boucle bornée, sans `retry` masquant : échec franc au-delà de 30 s) ;
  - valeurs : `docker run --rm --entrypoint sh urbankiff-test-nextjs:lot4 -c 'grep -rl "api.test.invalid" /app/.next/static'`
    renvoie au moins un fichier pour `NEXT_PUBLIC_BACKEND_URL` et `NEXT_PUBLIC_BACKEND_URL_FRONT` ; pour
    `NEXT_PUBLIC_GOOGLE_CLIENT_ID`, grep de `test-google-id.invalid` dans `/app/.next` (si le code n'utilise pas cette
    variable aujourd'hui, le noter dans l'issue au lieu de forcer le test) ; `BACKEND_URL`
    (`internal-api.test.invalid`) se cherche dans `/app/.next/server` (inscrit à la construction) ;
  - aucun secret : `docker run --rm --entrypoint sh … -c 'find /app -name ".env*"'` ne renvoie rien.
- [ ] **Étape 2 : implémenter.**
  - `apps/nextjs/.dockerignore` : `.git`, `.next`, `node_modules`, `.env`, `.env.*` (sans exclure `env.example`
    inutilement : l'exclure aussi), `*.md`, `Dockerfile*`, `docker-compose*.yml`. Attention : `public/` et `src/` ne
    doivent **pas** être ignorés (ils le sont dans l'ancien flux CI, plus ici).
  - `apps/nextjs/Dockerfile`, étapes : `deps` (`node:22-alpine`, `libc6-compat`, `yarn install --frozen-lockfile`),
    `build` (copie des sources, `ARG` des quatre variables recopiés en `ENV`, `yarn build`), `runner` (dernière
    étape, nom `prod`) : `NODE_ENV=production`, `PORT=3000`, `NEXT_TELEMETRY_DISABLED=1`, groupe/utilisateur UID/GID
    10001, copie `public`, `.next/standalone`, `.next/static` avec `--chown=10001:10001`, `mkdir -p /app/.next/cache`
    puis `chown` à 10001, `USER 10001`, `EXPOSE 3000`, commande `["sh","-c","HOSTNAME=0.0.0.0 exec node server.js"]`.
    Les valeurs d'`ARG` ne sont pas recopiées dans l'étape finale. Remplacer le commentaire d'en-tête obsolète
    (« expects .next pre-built by CI »).
  - Si le build échoue pour des erreurs de lint ou de types que `next.config.ts` ignore seulement quand `CI=true`,
    poser `ENV CI=true` dans l'étape `build` (comportement de l'ancienne CI) ; ne pas modifier `next.config.ts`. Si
    le build exige l'API joignable pour pré-rendre des pages, **s'arrêter et le signaler** (voir Risques du rapport).
- [ ] **Étape 3 : relancer, tout vert** ; nettoyer (`docker rm -f`, `docker rmi`) ; cocher l'Avancement ; commit
  d'une ligne, par exemple `feat: build next production image in dockerfile`.

*(Les tâches d'un plan sont dépendantes par construction ; Next et panel sont techniquement indépendants, voir le
rapport.)*

---

### Tâche 2 : image de production du panel

**Fichiers :**
- Créer : `apps/panel/.dockerignore`, `apps/panel/serve.json`
- Modifier : `apps/panel/Dockerfile`
- Test : commandes `docker` ci-dessous

**Interfaces :**
- Consomme : `apps/panel/package.json` (script `build` : `craco build`), `yarn.lock`, `craco.config.js`, `public/`
  (dont `_redirects`, ignoré par `serve`).
- Produit : image `linux/amd64`, port 8080, UID 10001, arguments `REACT_APP_BACKEND_URL`,
  `REACT_APP_IMAGEKIT_ENDPOINT` ; consommé par `charts` et `deploiement`. La commande de la tâche 1 sert de modèle.

- [ ] **Étape 1 : tests d'abord** (échec attendu : l'ancien Dockerfile exige `build/`) :
  - construction : `docker buildx build --platform linux/amd64 --load -t urbankiff-test-panel:lot4 --build-arg REACT_APP_BACKEND_URL=https://api.test.invalid --build-arg REACT_APP_IMAGEKIT_ENDPOINT=https://ik.test.invalid/x/ apps/panel` ;
  - lancement : `docker run -d --name urbankiff-test-panel --platform linux/amd64 --read-only --tmpfs /tmp --user 10001:10001 -p 8080 urbankiff-test-panel:lot4` ;
  - HTTP : `wget -S -O /dev/null http://127.0.0.1:8080/` → `200` ; **SPA** : `wget` d'un chemin inexistant
    (`/tableau/inconnu`) → `200` avec le contenu de `index.html` ; un fichier réel `/static/js/*.js` est servi en
    JavaScript (pas `index.html`) ;
  - valeurs : `docker run --rm --entrypoint sh urbankiff-test-panel:lot4 -c 'grep -rl "api.test.invalid" /app/build/static/js'` et `ik.test.invalid` renvoient un fichier chacun ;
  - utilisateur `10001` ; aucun `.env*` dans l'image (`find / -name ".env*" -not -path "/proc/*"`).
- [ ] **Étape 2 : implémenter.**
  - `apps/panel/.dockerignore` : `.git`, `node_modules`, `build`, `.env`, `.env.*`, `*.md`, `Dockerfile*`,
    `docker-compose*.yml` (`.env.development` contient des clés locales : ne jamais l'embarquer).
  - `apps/panel/serve.json` : `public` vers `build`, `cleanUrls: false`, `rewrites: [{"source":"**","destination":"/index.html"}]`,
    en-têtes `Cache-Control: public, max-age=31536000, immutable` pour `/static/**` et `no-cache` pour `/index.html`.
  - `apps/panel/Dockerfile`, étapes : `build` (`node:20-alpine`, `yarn install --frozen-lockfile`, `ARG` des deux
    variables recopiés en `ENV`, `SKIP_PREFLIGHT_CHECK=true`, `GENERATE_SOURCEMAP=false`, `yarn build`) puis
    `prod` (`node:20-alpine`, `npm install -g serve@<version épinglée>`, UID/GID 10001, `HOME=/tmp`,
    `NO_UPDATE_NOTIFIER=1`, `COPY --from=build /app/build /app/build`, `COPY serve.json /app/serve.json`,
    `WORKDIR /app`, `USER 10001`, `EXPOSE 8080`, commande `["serve","-c","serve.json","-l","8080","--no-clipboard","build"]`
    — ajuster les drapeaux à la version épinglée, vérifiés par `docker run … serve --help`). Si le build échoue sous
    Node 20 avec une erreur OpenSSL, ajouter `NODE_OPTIONS=--openssl-legacy-provider` dans l'étape `build` seulement.
- [ ] **Étape 3 : relancer, tout vert** ; nettoyer ; cocher l'Avancement ; commit d'une ligne, par exemple
  `feat: build panel in dockerfile and serve spa with serve`.

---

### Tâche 3 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] Les deux suites de commandes `docker` des tâches 1 et 2 rejouées d'un bloc depuis un état propre (images
  supprimées, `--no-cache` pour le panel et Next) : toutes vertes.
- [ ] Compose local inchangé : `git diff --stat feature/k3s-ansible...HEAD` ne montre que les fichiers du lot ;
  `apps/nextjs/Dockerfile.dev` et `docker-compose.yml` absents du diff.
- [ ] `make lint` et `make typecheck` verts (sans objet pour le code, aucun source modifié ; à lancer par prudence).
- [ ] Tests ciblés, `make coverage-diff`, `make check-generated`, `make migrations-check`, e2e : sans objet (aucun code
  applicatif ; nextjs sans tests ; fichiers générés et e2e sans objet selon `.claude/devteam.projet.md`).
- [ ] Aucun conteneur ni image de test restant (`docker ps -a`, `docker images 'urbankiff-test-*'` vides).
- [ ] Périmètre : `make devteam-perimetre LOT=fronts-prod PLAN=docs/v1/plans/k3s-ansible/4-fronts-prod.md BASE=origin/feature/k3s-ansible` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler
  (notamment : variables `REACT_APP_FIREBASE_*`, `REACT_APP_IMGPROXY_*`, `REACT_APP_BASENAME` utilisées par le panel et
  hors contrat ; pré-rendu Next dépendant de l'API).
