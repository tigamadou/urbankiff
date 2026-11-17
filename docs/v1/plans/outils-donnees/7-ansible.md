# Ansible (configuration du serveur) — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [x]`.

**Objectif** : le serveur A reçoit, par rejeu du playbook, ce dont les lots 3 et 5 ont besoin : `deploy.prod.env` porte
la clé `BUCKET_COPIE_PREPROD` (bucket Wasabi de la preprod, lu par l'action `exporter-anonyme` de `urbankiff-deploy`),
`deploy.preprod.env` reste inchangé, et le Role `deploy` de chaque namespace gagne `traefik.io` `middlewares` en
écriture (le chart `urbankiff-donnees` rend des `Middleware` Traefik). Aucune exécution sur le serveur réel dans ce
lot.

**Architecture** : une variable non secrète `bucket_copie_preprod` dans `infra/ansible/group_vars/all.yml` (valeur par
défaut `urbankiff-preprod`, surchargeable dans `inventory.yml`), rendue seulement dans `deploy.prod.env` par
`roles/deploiement/templates/deploy.env.j2` (condition sur `item.key == 'prod'`) ; une règle ajoutée à
`deploiement_role_regles` (`roles/deploiement/defaults/main.yml`), rendue dans le Role par `rbac.yaml.j2` (inchangé).
Une assertion du rôle refuse un nom de bucket vide ou invalide. Contrôles statiques dans `tests/controles.sh` (dont la
cohérence avec `WASABI_BUCKET` de `scripts/secrets/variables-preprod.txt`), vérifications sur conteneur dans
`tests/verifier.yml`, test d'échec dans `tests/lancer.sh`. Le volet Kubernetes du rôle n'étant pas testable en
conteneur, le Role est contrôlé en statique et la preuve réelle est la vérification `kubectl auth can-i` documentée,
jouée par le développeur après la PR finale.

**Stack** : Ansible (image épinglée `infra/ansible/Dockerfile`), ansible-lint, shell POSIX, GNU Make
(`make infra-lint`, `make infra-test`, `make infra-test-assert`).

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité ; voir aussi § 5.6 et § 5.7). Plan de la mission `outils-donnees`, lot 7 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/outils-donnees-ansible` · **Base** : `feature/outils-donnees` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 4

- [x] **Tâche 1** Tests d'abord : contrôles statiques, vérifications sur conteneur, test d'échec (rouges) · `feature/outils-donnees-ansible`
  - [x] `tests/controles.sh` : règle `middlewares`, absence de `pods/exec`, variable de bucket, cohérence avec la preprod
  - [x] `tests/verifier.yml` : `BUCKET_COPIE_PREPROD` dans `deploy.prod.env` seulement
  - [x] `tests/lancer.sh` : échec franc sur un bucket vide ou invalide
  - [x] `make infra-lint` et `make infra-test` rouges pour la bonne raison
- [x] **Tâche 2** Variable, gabarit, assertion et règle du Role · `feature/outils-donnees-ansible`
  - [x] `group_vars/all.yml`, `roles/deploiement/templates/deploy.env.j2`, tâche d'assertion
  - [x] `roles/deploiement/defaults/main.yml` : règle `traefik.io` `middlewares`
  - [x] `make infra-lint`, `make infra-test`, `make infra-test-assert` verts (deux passages, zéro changement au second)
- [x] **Tâche 3** Inventaire d'exemple et documentation du serveur · `feature/outils-donnees-ansible`
  - [x] `inventory.example.yml` : variable commentée
  - [x] `docs/v1/infra/serveur.md` : nouveaux éléments et rejeu par le développeur après la PR finale
- [ ] **Tâche 4** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/ansible/roles/deploiement/**` (`defaults/main.yml`, `templates/deploy.env.j2`, `tasks/utilisateur.yml`)
- `infra/ansible/group_vars/all.yml`
- `infra/ansible/tests/**` (`controles.sh`, `verifier.yml`, `lancer.sh`)
- `infra/ansible/inventory.example.yml`
- `docs/v1/infra/serveur.md`
- `docs/v1/plans/outils-donnees/7-ansible.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md`, `CLAUDE.md`, `.claude/**`, `make/infra.mk` (cibles
`infra-lint`, `infra-test`, `infra-test-assert`, `infra-ansible`), `make/devteam.mk`, `make/standard.mk`,
`infra/ansible/site.yml` (aucune assertion ajoutée : celle du bucket vit dans le rôle), `infra/ansible/inventory.yml`
(inventaire réel, ignoré par git : ne pas le lire ni le modifier), le reste de `infra/ansible/**`,
`infra/deploiement/**` (lot 5 : le script lit `BUCKET_COPIE_PREPROD`, il refuse les clés inconnues),
`infra/helm/**` (lots 3, 4, 6), `scripts/secrets/**` (lot 6 : `variables-preprod.txt` porte `WASABI_BUCKET`, lu par
`controles.sh`), `.github/workflows/**`, et tous les fichiers exclusifs des autres lots.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test du projet (`.claude/devteam.projet.md`, `CLAUDE.md`) : tout passe par `make` (sur l'hôte, seulement
`docker`, `make`, `git`, `gh`) ; tests d'abord, vus rouges avant l'implémentation ; jamais de modification du code de
production pour faire passer un test ; pas de `retry` ni de contournement. Propres à ce lot :

- **Aucune exécution sur le serveur réel** : ni `make infra-ansible`, ni SSH, ni lecture de `inventory.yml`. Seuls
  `make infra-lint`, `make infra-test` et `make infra-test-assert` (conteneurs jetables) sont lancés.
- Aucun secret dans le dépôt : le nom du bucket n'en est pas un ; aucun identifiant Wasabi n'est ajouté au serveur
  (les identifiants vivent dans les Secrets du namespace, posés par le script).
- `deploy.preprod.env` ne change pas d'un octet ; `deploy.prod.env` ne gagne que la ligne `BUCKET_COPIE_PREPROD`.
- Le Role n'ajoute que `traefik.io` `middlewares` : pas de `pods/exec`, pas de ressource supplémentaire (spec § 5.7).
- Le second passage de `lancer.sh` doit rester à `changed=0`.
- Couverture : sans objet pour du code Ansible ; la preuve est la paire test rouge puis vert de chaque comportement.

## Points de revue

1. `BUCKET_COPIE_PREPROD` n'apparaît que dans `deploy.prod.env`, jamais dans `deploy.preprod.env`, et sa valeur par
   défaut égale `WASABI_BUCKET` de `scripts/secrets/variables-preprod.txt` (`urbankiff-preprod`), contrôlé par
   `tests/controles.sh`.
2. Le Role gagne uniquement `traefik.io` / `middlewares` avec les verbes d'écriture ; aucune règle `pods/exec`.
3. L'assertion refuse un bucket vide ou qui ne respecte pas les règles de nommage S3 (3 à 63 caractères, minuscules,
   chiffres, tirets et points).
4. Documentation : le rejeu du playbook par le développeur après la PR finale (et avant la première utilisation de
   `exporter-anonyme`) est écrit, avec les vérifications `kubectl auth can-i`.

---

### Tâche 1 : tests d'abord (rouges)

**Fichiers :**
- Créer : aucun.
- Modifier : `infra/ansible/tests/controles.sh`, `infra/ansible/tests/verifier.yml`, `infra/ansible/tests/lancer.sh`
- Test : ces trois fichiers sont les tests.

**Interfaces :**
- Consomme : contrat « Configuration du serveur (lot 7) » du § 8.3 ; `scripts/secrets/variables-preprod.txt`
  (`WASABI_BUCKET=urbankiff-preprod`, lot 6, lecture seule, atteint depuis `/repo/infra/ansible` par
  `../../scripts/secrets/variables-preprod.txt`).
- Produit : les attentes que la tâche 2 doit satisfaire : variable `bucket_copie_preprod`, clé
  `BUCKET_COPIE_PREPROD=<valeur>` dans `/etc/urbankiff/deploy.prod.env` seulement, règle de Role, message d'échec
  « bucket_copie_preprod » sur valeur invalide.

- [ ] **Étape 1** : `tests/controles.sh`, à la suite du contrôle des `replicasets`, ajouter (même style `verifier` /
  `echec=1`) :
  - la règle du Role : `roles/deploiement/defaults/main.yml` contient `apiGroups: [traefik.io]` et
    `resources: [middlewares]` (contrôle sur deux lignes consécutives : `grep -A1 'apiGroups: \[traefik.io\]'`
    puis `resources: \[middlewares\]`), avec `verbs: "{{ deploiement_verbes_ecriture }}"` à la ligne suivante ;
  - l'absence de `pods/exec` dans `roles/deploiement/defaults/main.yml` (`grep -q 'pods/exec'` doit échouer) ;
  - la présence de `^bucket_copie_preprod: ` dans `group_vars/all.yml` ;
  - le gabarit : `roles/deploiement/templates/deploy.env.j2` contient `BUCKET_COPIE_PREPROD={{ bucket_copie_preprod }}`
    sous une condition `item.key == 'prod'` ;
  - la cohérence : la valeur de `bucket_copie_preprod` de `group_vars/all.yml` est égale à la valeur de
    `WASABI_BUCKET` de `../../scripts/secrets/variables-preprod.txt` (message d'échec explicite si les deux
    divergent ; si le fichier est absent, `ECHEC … absent`).
- [ ] **Étape 2** : `tests/verifier.yml`, après la vérification des clés `URBANKIFF_ENV`, `GHCR_OWNER`… : une tâche
  d'assertion sur `deploy_envs.results` (en bouclant sur chaque environnement) : le contenu de `deploy.prod.env`
  contient la ligne exacte `BUCKET_COPIE_PREPROD=` suivie de `bucket_copie_preprod` (`is search('(?m)^BUCKET_COPIE_PREPROD=' ~ bucket_copie_preprod ~ '$')`) ;
  le contenu de `deploy.preprod.env` ne contient **pas** `BUCKET_COPIE_PREPROD`. Rappel : `group_vars/all.yml` est déjà
  chargé par `vars_files` de `verifier.yml`.
- [ ] **Étape 3** : `tests/lancer.sh`, après le bloc « Script de déploiement requis mais absent », un bloc
  « Bucket de la copie invalide : échec attendu » calqué sur lui : `ansible -e ansible_user=testadmin
  -e bucket_copie_preprod=""` avec `--tags bucket_copie` sur `tests/site-test.yml` doit échouer **et** la sortie doit
  contenir `bucket_copie_preprod` ; un second cas avec `-e bucket_copie_preprod=Mauvais_Nom` (majuscule et
  soulignement) échoue de même ; message `ok   échec franc quand le bucket de la copie est invalide`.
- [ ] **Étape 4** : lancer `make infra-lint`, `make infra-test-assert` puis `make infra-test` ; constater que
  `infra-lint` échoue (lignes `ECHEC …` de l'étape 1) et que `infra-test` échoue (étapes 2 et 3), pour la bonne raison
  (comportement absent, pas une faute de syntaxe du test). Cocher l'Avancement ; commit d'une ligne
  (`test: controles ansible du bucket de copie et du droit middlewares`).

---

### Tâche 2 : variable, gabarit, assertion et règle du Role

**Fichiers :**
- Créer : aucun.
- Modifier : `infra/ansible/group_vars/all.yml`, `infra/ansible/roles/deploiement/defaults/main.yml`,
  `infra/ansible/roles/deploiement/templates/deploy.env.j2`, `infra/ansible/roles/deploiement/tasks/utilisateur.yml`
- Test : ceux de la tâche 1.

**Interfaces :**
- Consomme : les attentes de la tâche 1.
- Produit : `/etc/urbankiff/deploy.prod.env` avec la ligne `BUCKET_COPIE_PREPROD=urbankiff-preprod` (consommée par
  `infra/deploiement/urbankiff-deploy.sh`, lot 5) ; `/etc/urbankiff/deploy.preprod.env` inchangé ; Role `deploy` de
  `prod` et de `preprod` avec `traefik.io` `middlewares` (consommé par le chart `urbankiff-donnees`, lot 3).

- [ ] **Étape 1** : `group_vars/all.yml` : sous `deploiement_envs`, ajouter la variable avec son commentaire de
  pourquoi : `bucket_copie_preprod: urbankiff-preprod` (bucket Wasabi de la preprod, nom non secret, reçu par le Job
  d'export anonymisé de la prod ; doit égaler `WASABI_BUCKET` de `scripts/secrets/variables-preprod.txt`, vérifié par
  `tests/controles.sh` ; surchargeable dans `inventory.yml`).
- [ ] **Étape 2** : `roles/deploiement/templates/deploy.env.j2` : ajouter en fin de fichier, **seulement pour la
  prod** (`{% if item.key == 'prod' %}` … `{% endif %}`), le commentaire « Bucket Wasabi de la preprod : cible de
  l'export anonymisé (action exporter-anonyme, prod seulement). Aucun secret. » et la ligne
  `BUCKET_COPIE_PREPROD={{ bucket_copie_preprod }}`. Vérifier que le rendu de `preprod` est identique octet pour octet
  à l'actuel (aucune ligne vide ajoutée par les balises de bloc).
- [ ] **Étape 3** : `roles/deploiement/tasks/utilisateur.yml` : avant la tâche « Configuration de urbankiff-deploy par
  environnement », ajouter une tâche `ansible.builtin.assert` étiquetée `[bucket_copie]` : `bucket_copie_preprod is
  defined`, `is match('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')` ; `fail_msg` :
  `"bucket_copie_preprod : nom de bucket S3 valide requis (3 à 63 caractères, minuscules, chiffres, tirets, points)"`,
  `quiet: true`. Les tâches du rôle n'étant pas toutes étiquetées, vérifier que `--tags bucket_copie` ne joue bien que
  cette assertion (sinon, étiqueter en conséquence sans toucher au comportement des autres tâches).
- [ ] **Étape 4** : `roles/deploiement/defaults/main.yml` : ajouter à `deploiement_role_regles`, avant la règle
  `cert-manager.io`, la règle `apiGroups: [traefik.io]`, `resources: [middlewares]`,
  `verbs: "{{ deploiement_verbes_ecriture }}"`, avec un commentaire : « Middlewares Traefik du chart urbankiff-donnees
  (limitation de débit, en-têtes de sécurité des outils web). Pas de pods/exec : la restauration passe par des
  Jobs. »
- [ ] **Étape 5** : `make infra-lint` (ansible-lint, syntax-check, contrôles) vert ; `make infra-test-assert` vert ;
  `make infra-test` vert (deux passages, `changed=0` au second, nouveaux contrôles verts, échecs francs attendus
  obtenus). Cocher l'Avancement ; commit d'une ligne (`feat: bucket de copie preprod dans deploy.prod.env et droit
  middlewares du Role deploy`).

---

### Tâche 3 : inventaire d'exemple et documentation du serveur

**Fichiers :**
- Créer : aucun.
- Modifier : `infra/ansible/inventory.example.yml`, `docs/v1/infra/serveur.md`
- Test : `make infra-lint` (syntax-check avec l'inventaire d'exemple).

**Interfaces :**
- Consomme : variable `bucket_copie_preprod`, règle du Role (tâche 2).
- Produit : documentation lue par le développeur pour rejouer le playbook.

- [ ] **Étape 1** : `inventory.example.yml` : dans `vars` du groupe `noeuds`, ajouter en commentaire (jamais de
  valeur différente imposée) :
  `# bucket_copie_preprod: urbankiff-preprod   # facultatif : défaut de group_vars/all.yml, doit égaler WASABI_BUCKET de la preprod`.
- [ ] **Étape 2** : `docs/v1/infra/serveur.md` :
  - ligne `deploiement` du tableau « Vue d'ensemble » : mentionner `BUCKET_COPIE_PREPROD` dans `deploy.prod.env` et le
    droit `traefik.io` `middlewares` du Role ;
  - section « Inventaire » : variable facultative `bucket_copie_preprod` (non secrète, défaut `urbankiff-preprod`,
    égale à `WASABI_BUCKET` de `scripts/secrets/variables-preprod.txt`) ;
  - section « Vérifications » : `sudo -u deploy kubectl auth can-i create middlewares.traefik.io --kubeconfig
    /home/deploy/.kube/preprod` répond `yes` (idem `prod`), et `kubectl auth can-i create pods/exec …` répond `no` ;
    `cat /etc/urbankiff/deploy.prod.env` montre `BUCKET_COPIE_PREPROD`, `deploy.preprod.env` non ;
  - nouvelle section « Rejouer le playbook après la mission `outils-donnees` » : **fait par le développeur après la
    fusion de la PR finale, jamais par un agent** ; commande `make infra-ansible LIMITE=serveur ARGS="--check --diff"`
    puis `make infra-ansible LIMITE=serveur` (changements attendus : `deploy.prod.env`, Role `deploy` des deux
    namespaces ; rien d'autre) ; à faire **avant** le premier `exporter-anonyme` et avant le déploiement qui apporte le
    chart des outils web (sans le droit `middlewares`, `helm upgrade` échoue) ; le script `urbankiff-deploy` refuse les
    clés inconnues de `deploy.<env>.env`, donc le rejeu et la mise à jour du script (même PR, lot 5) arrivent ensemble ;
  - « Limites connues » : le Role n'a pas `pods/exec` (voulu) ; le volet Kubernetes reste validé à la mise en service.
- [ ] **Étape 3** : `make infra-lint` vert. Cocher l'Avancement ; commit d'une ligne
  (`docs: bucket de copie, droit middlewares et rejeu du playbook dans serveur.md`).

---

### Tâche 4 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint` et `make typecheck` verts (sans objet pour Ansible, mais lancés pour le contrôle du dépôt) ;
  `make infra-lint` vert.
- [ ] Tests du lot : `make infra-test-assert` et `make infra-test` verts (deux passages, `changed=0` au second ;
  `make test-cible` n'est pas utilisé : il n'aiguille que `apps/api` et `apps/panel`).
- [ ] `make coverage-diff` : sans objet (aucun code Python modifié).
- [ ] `make check-generated` et `make migrations-check` : sans objet.
- [ ] e2e du lot : sans objet.
- [ ] `make secrets-scan` vert (aucun secret ajouté).
- [ ] Périmètre : `make devteam-perimetre LOT=ansible PLAN=docs/v1/plans/outils-donnees/7-ansible.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler ;
  rappeler que le playbook n'a **pas** été rejoué sur le serveur réel et que le développeur le rejoue après la PR
  finale (section de `serveur.md`).
