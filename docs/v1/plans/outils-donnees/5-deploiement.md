> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d'écart) : B2, B3, B4, B8, B10.

# Déploiement : actions `restaurer` et `exporter-anonyme`, cibles du poste, workflows — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : ajouter au point d'entrée du serveur (`urbankiff-deploy`) l'action `restaurer <prefixe>` (prod et preprod,
rejouable, l'application reste arrêtée en cas d'échec) et l'action `exporter-anonyme <date>` (prod seulement), puis leurs
déclencheurs : cibles `make` du poste (`restauration-lancer`, `restauration-deposer`, `copie-prod-preprod`) et workflows
GitHub manuels `restauration.yml` et `copie-prod-preprod.yml`. Réécrire la documentation de déploiement et la procédure
de premier déploiement de la prod.

**Architecture** : le script reste le seul chemin. Pour `restaurer`, il lit les Secrets déjà présents dans le namespace
(aucune entrée standard), contrôle que `<prefixe>base.dump` existe dans Wasabi, met à zéro les Deployments portant
`app.kubernetes.io/part-of=urbankiff` (en notant les réplicas dans l'annotation `urbankiff.com/replicas-avant`, comme
`preprod-arret`), rend à la demande le Job `urbankiff-restauration` (chart `urbankiff-donnees`) puis
`urbankiff-apres-restauration` (chart `urbankiff`) par `helm template --show-only` avec les valeurs de la release en
place, les crée, les suit, les supprime en cas de succès, remet les réplicas et contrôle `/api/health/`. Pour
`exporter-anonyme`, il rend le Job `urbankiff-export-anonyme` de la même façon (sans arrêter l'application). Le poste et
la CI appellent les mêmes commandes par SSH (compte `deploy`, commande forcée).

**Stack** : bash, bats (faux `kubectl`, `helm`, `curl`, `docker`, `ssh`, `gh`, `flock`, `sleep` de
`infra/deploiement/tests/fakes/`), GNU Make, rclone en conteneur (poste), GitHub Actions, actionlint et shellcheck en
conteneur.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité). Plan de la mission `outils-donnees`, lot 5 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/outils-donnees-deploiement` · **Base** : `feature/outils-donnees` · **Profil** : `api`
- **Dépendances** : aucune (contrats du § 8.3 de la spec, testés avec des faux).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 2

- [x] **Tâche 1** Faux binaires étendus, clés `PGADMIN_*` dans `SECRET_KEYS`, tests d'inventaire tolérants · `feature/outils-donnees-deploiement`
  - [x] bats : aide commune, `inventaire-cles.bats` tolérant, tests existants adaptés
  - [x] implémentation : `SECRET_KEYS`, faux étendus
- [ ] **Tâche 2** Script : analyse des commandes `restaurer` et `exporter-anonyme`, clé `BUCKET_COPIE_PREPROD`
  - [ ] bats : motifs, refus, verrou, configuration
  - [ ] implémentation
- [ ] **Tâche 3** Script : aides communes (arrêt et remise des réplicas, version déployée, rendu et suivi d'un Job)
  - [ ] bats : non-régression de `preprod-arret` et `preprod-demarrage`, rendu, suivi
  - [ ] implémentation
- [ ] **Tâche 4** Script : action `restaurer` complète
  - [ ] bats : contrôle du préfixe Wasabi, déroulé, ordre, échecs qui laissent l'application arrêtée, relance
  - [ ] implémentation
- [ ] **Tâche 5** Script : action `exporter-anonyme`
  - [ ] bats : prod seulement, rendu, suivi, bucket cible
  - [ ] implémentation
- [ ] **Tâche 6** Poste : `make restauration-lancer` et `make restauration-deposer`
  - [ ] bats : usage, confirmation prod, commande exacte, dépôt sans secret en argument
  - [ ] implémentation
- [ ] **Tâche 7** Poste : `make copie-prod-preprod`
  - [ ] bats : confirmation, deux SSH dans l'ordre, arrêt au premier échec
  - [ ] implémentation
- [ ] **Tâche 8** Workflows `restauration.yml` et `copie-prod-preprod.yml`
  - [ ] bats : invariants de sécurité ; actionlint
  - [ ] implémentation
- [ ] **Tâche 9** Documentation `docs/v1/infra/deploiement.md`
- [ ] **Tâche 10** Réécriture de `docs/v1/infra/premier-deploiement-prod.md`
- [ ] **Tâche 11** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/deploiement/**` (script `urbankiff-deploy.sh`, `poste/`, `tests/` et `tests/fakes/`)
- `make/restauration.mk` (cibles du poste ajoutées ; `restauration-test`, `sauvegarde-inspecter` et `sauvegarde-repeter` inchangées)
- `make/deploiement.mk`
- `.github/workflows/restauration.yml` [nouveau]
- `.github/workflows/copie-prod-preprod.yml` [nouveau]
- `docs/v1/infra/deploiement.md`
- `docs/v1/infra/premier-deploiement-prod.md` (réécrit)
- `docs/v1/plans/outils-donnees/5-deploiement.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` ; `CLAUDE.md`, `.claude/**`.
- `.github/workflows/deploiement.yml` (modèle de la préparation SSH ; **ne pas** reprendre `toJSON(secrets)`),
  `.github/workflows/devteam-ci.yml`.
- `make/devteam.mk`, `make/standard.mk`, `make/helm.mk`, `make/secrets.mk`, `Makefile`.
- `scripts/secrets/**` (lot 6 : `secrets.txt` gagne `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE`), `docs/v1/infra/secrets.md`.
- `infra/helm/**` (lots 3, 4, 6 : noms et conditions de rendu des Jobs, contrat 8.3), `apps/api/**` (lots 1, 2).
- `infra/ansible/**` (lot 7 : clé `BUCKET_COPIE_PREPROD` de `deploy.prod.env`, Role `deploy`), `docs/v1/infra/serveur.md`.
- `infra/restauration/**` (scripts de la répétition locale, source du format du dépôt).
- `docs/v1/infra/kubernetes.md`, `docs/v1/infra/outils-donnees.md` (lots 3, 4, 6).

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par des cibles
`make` qui lancent des conteneurs (sur l'hôte : `docker`, `make`, `git`, `gh` seulement) ; commits en ASCII,
Conventional Commits ; pas de commentaires inutiles (le *pourquoi* seulement). Au minimum : aucun mock de la base ni de
l'ORM (sans objet : le lot n'a pas de code applicatif, ses tests sont des bats avec de faux binaires) ; ne jamais
modifier le code de production pour faire passer un test ; **tous les chemins du script couverts par un test bats** (le
« 100 % du code modifié » de `coverage-diff` est sans objet pour du bash) ; pas de `retry` ni de contournement pour
masquer une instabilité ; aucun `xtrace`, aucun `eval`.

Contraintes propres au lot :

- Aucune valeur secrète en argument, journalisée, écrite dans le dépôt ou lisible dans un journal de Job ; les
  identifiants Wasabi du poste passent par `docker run -e NOM` (valeur lue dans l'environnement du processus, jamais
  dans la ligne de commande) ; le contrôle Wasabi du serveur lit ses identifiants sur l'entrée standard de `curl -K -`.
- Les nouveaux workflows : permissions minimales (`permissions: {}` global, `contents: read` par job), aucune expression
  `${{ }}` dans un `run:`, un seul secret référencé (`secrets.DEPLOY_SSH_KEY`), **pas de `toJSON(secrets)`**.
- Prod : une restauration ou une copie n'est jamais lançable sans l'approbation de l'environnement GitHub `prod` (CI)
  ou la saisie du mot `prod` (poste).

## Points de revue

1. L'application reste **arrêtée** quand l'étape 3 ou 4 échoue, et le message le dit ; une relance reprend les réplicas
   d'avant (l'annotation n'est pas écrasée par zéro).
2. Aucun chemin de restauration par `helm upgrade` : le script ne passe jamais `restauration.active` ni
   `restauration.purger`, la sauvegarde n'est jamais supprimée de Wasabi.
3. `exporter-anonyme` est refusé (code 2) avec la clé de la preprod, avant tout appel à `kubectl` ou `helm`.
4. Aucun secret dans les arguments, les journaux, les workflows ; `toJSON(secrets)` absent des nouveaux workflows.
5. `inventaire-cles.bats` reste vert sur la branche du lot **et** après la fusion du lot 6 (voir tâche 1).
6. Les deux listes de secrets ajoutent exactement `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE`.

---

### Tâche 1 : faux binaires étendus, `SECRET_KEYS`, tests d'inventaire tolérants

Les clés `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` entrent dans `SECRET_KEYS` (lot 5) pendant que `secrets.txt` ne les
reçoit que par le lot 6 : sur la branche du lot, `secrets.txt` ne les contient pas. Les tests qui comparent ou
reconstruisent des entrées depuis `secrets.txt` doivent rester verts avant **et** après la fusion du lot 6.

**Fichiers :**
- Créer : `infra/deploiement/tests/aide.bash`
- Modifier : `infra/deploiement/urbankiff-deploy.sh` (`SECRET_KEYS` seulement), `infra/deploiement/tests/inventaire-cles.bats`, `infra/deploiement/tests/deploy-secrets.bats`, `infra/deploiement/tests/deploy-helm.bats`, `infra/deploiement/tests/make-deploiement.bats` (les endroits qui construisent une entrée complète depuis `secrets.txt`), `infra/deploiement/tests/fakes/{kubectl,helm,curl,docker}`
- Test : les fichiers ci-dessus

**Interfaces :**
- Consomme : `scripts/secrets/secrets.txt` (lecture seule, lot 6) ; contrat « Secrets (lots 5 et 6) ».
- Produit : `aide.bash` avec `CLES_CONTRAT="PGADMIN_EMAIL PGADMIN_MOT_DE_PASSE"` et `noms_secrets_complets` (noms de
  `secrets.txt` ∪ `CLES_CONTRAT`, sans doublon) ; faux étendus pour les tâches 3 à 5 :
  - `kubectl` : `get job <nom>` lit `$FAKE_STATE/job-<nom>.txt` (contenu `succeeded/failed`, `/` si absent) ;
    `logs` lit `$FAKE_STATE/logs-<nom>.txt` ; `wait` n'échoue que si `FAKE_WAIT_ECHEC` est défini **et** (si
    `FAKE_WAIT_ECHEC_SUR` est défini) si les arguments contiennent ce motif ; `delete` journalisé ;
  - `helm` : `get values <release> …` rend `$FAKE_STATE/values-<release>.yaml` (échec si absent) ; `template` journalise
    et rend `$FAKE_STATE/rendu-$(basename du --show-only).yaml` ou `kind: Job` par défaut ; `FAKE_TEMPLATE_ECHEC` le fait échouer ;
  - `curl` : échoue (code 22) si `FAKE_CURL_ECHEC_SUR` est défini et que les arguments contiennent ce motif ; journalise
    `STDIN curl <longueur>` quand l'argument `-K -` est présent, jamais le contenu ;
  - `docker` : `… size --json …` rend `{"count":1,"bytes":${FAKE_RCLONE_OCTETS:-0}}`.

- [ ] **Étape 1** : écrire les tests. `inventaire-cles.bats` : `SECRET_KEYS` contient tous les noms de `secrets.txt` ; tout nom de `SECRET_KEYS` absent de `secrets.txt` appartient à `CLES_CONTRAT` ; `SECRET_KEYS` contient les deux clés du contrat. Les tests qui bâtissent une entrée complète (`entree_complete`, `noms_secrets`, `noms_secrets_complets` dans `deploy-secrets.bats`, `deploy-helm.bats`) font `load aide` et utilisent `noms_secrets_complets`. Ajouter un test de non-régression : une entrée sans `PGADMIN_EMAIL` est refusée par `deploy` (« clé obligatoire absente ou vide : PGADMIN_EMAIL »). Les voir échouer (`make deploiement-test`).
- [ ] **Étape 2** : ajouter les deux clés à `SECRET_KEYS` (dans le bloc `cles:debut` / `cles:fin`), étendre les faux.
- [ ] **Étape 3** : `make deploiement-test` vert ; cocher l'Avancement ; commit d'une ligne (`feat: cles pgadmin dans urbankiff-deploy`).

Signaler dans l'issue et au lead de la PR finale : après la fusion du lot 6, `inventaire-cles.bats` peut revenir à
l'égalité stricte (la tolérance `CLES_CONTRAT` devient inutile) ; le lot ne le fait pas pour rester vert seul.

---

### Tâche 2 : script, analyse des commandes et configuration

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh` (`analyser_commande`, `lire_configuration`, `main`)
- Créer : `infra/deploiement/tests/restauration-commande.bats`
- Test : idem, plus `infra/deploiement/tests/deploy-commande.bats` (la liste des refus gagne les cas ci-dessous)

**Interfaces :**
- Consomme : contrat « Script (lot 5) » et « Configuration du serveur (lot 7) ».
- Produit : variables `PREFIXE` (ex. `restauration/2026-11-17/`), `DATE_EXPORT`, `BUCKET_COPIE_PREPROD` (vide si absent) ;
  `COMMANDE=restaurer|exporter-anonyme`.

B2 : en prod, `restaurer` d'un préfixe finissant par `-prod-anonyme/` est refusé (code 2, avant tout appel, test bats ; accepté en preprod). Motifs stricts, longueur ≤ 100 inchangée, aucun `eval` :
`^restaurer restauration/[0-9]{4}-[0-9]{2}-[0-9]{2}(-prod-anonyme)?/$` et `^exporter-anonyme [0-9]{4}-[0-9]{2}-[0-9]{2}$`.

- [ ] **Étape 1** : tests (faux `kubectl`/`helm` ; refus = code 2, `FAKE_LOG` vide). Cas : préfixe sans `/` final, avec
  `..`, avec chemin absolu, `restauration/2026-11-17/x/`, `restauration/2026-1-17/`, suffixe inconnu
  (`-prod-anonymes`), retour à la ligne, `restaurer` seul, `restaurer restauration/2026-11-17/ extra` ; `exporter-anonyme`
  avec date mal formée ; `exporter-anonyme 2026-11-17` en **preprod** : code 2 et `[ ! -s "$FAKE_LOG" ]`. Configuration :
  `BUCKET_COPIE_PREPROD=bucket-preprod` accepté dans `deploy.prod.env` ; valeur invalide (`a;b`, vide) refusée ; clé
  **inconnue** (donc refusée, code 1) dans `deploy.preprod.env` ; absente de `deploy.prod.env` : le script démarre pour
  `deploy` et `restaurer`, mais `exporter-anonyme` répond « configuration : BUCKET_COPIE_PREPROD absent » (code 1). Verrou
  pris : « un déploiement est déjà en cours » pour les deux nouvelles commandes.
- [ ] **Étape 2** : implémenter (branches de `analyser_commande`, clé acceptée seulement si `ENV=prod`, refus de
  `exporter-anonyme` hors prod placé avec les autres refus, avant `verrouiller`). Les actions elles-mêmes sont des
  fonctions vides qui `log` seulement (remplies aux tâches 4 et 5).
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 3 : script, aides communes

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh`
- Test : `infra/deploiement/tests/deploy-preprod.bats` (inchangé : doit rester vert), `infra/deploiement/tests/restauration-aides.bats` [nouveau]

**Interfaces :**
- Consomme : release Helm `urbankiff` du namespace (valeur `image.etiquette`), faux `helm get values`.
- Produit (fonctions du script) :
  - `mettre_a_zero <deployment|statefulset>` et `remettre_a_lechelle <genre>` : corps actuels de `cmd_preprod_arret` et
    `cmd_preprod_demarrage` extraits sans changement de comportement (les tests existants de `deploy-preprod.bats` en sont la garantie) ;
  - `version_deployee` : lit `etiquette:` sous `image:` dans `helm get values urbankiff -n "$NAMESPACE" -o yaml`, valide le motif
    semver, sinon `die "application non déployée : version introuvable"` ; positionne `VERSION` ;
  - `rendre_job <chart> <release> <gabarit> [--set k=v …]` : écrit `helm get values <release> -n NS -o yaml` dans
    `$TMP/valeurs-<release>.yaml`, puis `helm template <release> $TMP/charts/<chart> -n NS -f $TMP/charts/<chart>/values-$ENV.yaml -f $TMP/valeurs-<release>.yaml --show-only templates/<gabarit> [--set …]` ; sortie vide = `die` (le Job n'est pas rendu) ;
  - `lancer_job <nom> <manifeste>` : supprime d'abord un Job du même nom resté d'une tentative précédente
    (`kubectl delete job <nom> -n NS --ignore-not-found`), `kubectl apply -n NS -f -` ;
  - `suivre_job <nom> <journal-de-fin>` : boucle (`sleep 5`, `URBANKIFF_JOB_TENTATIVES` par défaut 360) sur
    `kubectl get job <nom> -n NS -o jsonpath='{.status.succeeded}/{.status.failed}'` ; échec ou délai : affiche les
    journaux (`kubectl logs job/<nom> -n NS --all-containers --tail=200`) et `die` ; succès : exige le journal de fin dans
    les journaux (sinon `die`), puis supprime le Job. **Le Job d'un échec est conservé** pour l'enquête.

`telecharger_charts` utilise `VERSION` : appeler `version_deployee` avant.

- [ ] **Étape 1** : tests. Non-régression : `make deploiement-test` après extraction (déjà vert = comportement conservé).
  Nouveaux : version lue (`image:\n  etiquette: 1.2.3`), version absente ou invalide → erreur ; rendu : les deux `-f` dans cet
  ordre et `--show-only` exacts, aucune valeur secrète dans les appels (`FAKE_LOG` sans valeur de Secret) ; rendu vide → erreur
  sans `apply` ; suivi : succès avec journal de fin, succès sans journal de fin (erreur), échec (`0/1`), délai
  (`URBANKIFF_JOB_TENTATIVES=3`, Job jamais terminé) ; Job supprimé après succès, conservé après échec ; Job homonyme
  supprimé avant création.
- [ ] **Étape 2** : implémenter l'extraction et les fonctions.
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 4 : script, action `restaurer`

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh`
- Test : `infra/deploiement/tests/restauration-restaurer.bats` [nouveau]

**Interfaces :**
- Consomme : contrats « Job de restauration » (`urbankiff-restauration`, rendu si `restauration.prefixe` non vide, journal
  `restauration terminée`) et « Job après restauration » (`urbankiff-apres-restauration`, rendu si `apresRestauration.actif=true`,
  image api, journal de fin : **le contrat du lot 4 ne fixe pas de journal de fin pour ce Job** : le script se fie à l'état
  du Job `succeeded`, voir « Problèmes de contrat » ci-dessous).
- Produit : `cmd_restaurer`, déroulé en six étapes, chaque étape vérifiée avant la suivante.

Déroulé de `cmd_restaurer` (secrets lus par `lire_cluster`, jamais d'entrée standard ; **message d'erreur dédié** si
`PGADMIN_*` manquent du Secret : « Secret incomplet : relancer `make secrets-cluster` »)  :

1. `controler_prefixe` : `curl -fsS --max-time 20 --head --aws-sigv4 "aws:amz:$WASABI_REGION:s3" -K - "https://s3.$WASABI_REGION.wasabisys.com/$WASABI_BUCKET/${PREFIXE}base.dump"`, avec
   `user = "<WASABI_ACCESS_KEY_ID>:<WASABI_SECRET_ACCESS_KEY>"` fourni par `-K -` sur l'entrée standard (décodé de
   `SECRET_B64`, jamais en argument). Échec : `die "préfixe introuvable dans le bucket $WASABI_BUCKET : ${PREFIXE}base.dump"` ; **rien n'est encore arrêté**. Attendre aussi que le cluster `urbankiff-pg` soit `Ready`
   (`kubectl wait`), sinon `die` sans rien arrêter.
2. `version_deployee`, `telecharger_charts`, arrêt : `mettre_a_zero deployment` (le label `part-of=urbankiff` exclut `urbankiff-pg`, Redis et
   RustFS ; le Deployment `urbankiff-pgadmin` du lot 3 porte ce label) ; `APP_ARRETEE=1`. Un Deployment déjà à zéro garde son annotation (relance après échec).
3. `rendre_job urbankiff-donnees urbankiff-donnees restauration-job.yaml --set restauration.prefixe=$PREFIXE`, `lancer_job urbankiff-restauration`, `suivre_job urbankiff-restauration "restauration terminée"`. Seul `restauration.prefixe` est passé (B4 : ni `active`, ni `purger`, ni `copierFichiers`).
4. `rendre_job urbankiff urbankiff apres-restauration-job.yaml --set apresRestauration.actif=true`, `lancer_job urbankiff-apres-restauration`, `suivre_job` (journal de fin non exigé pour ce Job).
5. `remettre_a_lechelle deployment`, `APP_ARRETEE=0`, `kubectl wait deployment -l app.kubernetes.io/part-of=urbankiff -n NS --for=condition=Available --timeout=600s`.
6. `verifier_sante`, puis `log "restauration terminée : $PREFIXE"`.

`nettoyer` (trap EXIT) : si le statut est non nul **et** `APP_ARRETEE=1`, journalise « l'application reste arrêtée : la base peut être à moitié restaurée, corriger puis relancer la même commande » (le message sort aussi quand la cause est un `die` quelconque).

- [ ] **Étape 1** : tests (préparer `$FAKE_STATE` : `values-urbankiff.yaml`, `values-urbankiff-donnees.yaml`, `deployment.txt` `urbankiff-api 2 \nurbankiff-workers 1 \nurbankiff-pgadmin 1 \n`, `job-urbankiff-restauration.txt` = `1/`, `logs-urbankiff-restauration.txt` contenant `restauration terminée`, `job-urbankiff-apres-restauration.txt` = `1/`, Secret fictif complet) :
  - succès preprod et prod : ordre exact des appels (curl, wait base, scale à 0 de chaque Deployment avec annotation, `helm pull` des deux charts à la version déployée, `helm template … restauration-job.yaml`, `apply`, suivi, `helm template … apres-restauration-job.yaml`, `apply`, suivi, scale aux valeurs d'avant, annotation retirée, wait Available, curl santé) ; sortie contient `restauration terminée` ;
  - le préfixe `-prod-anonyme/` est transmis tel quel à `--set restauration.prefixe=` ;
  - préfixe absent de Wasabi (`FAKE_CURL_ECHEC_SUR=wasabisys`) : code 1, **aucun** `scale`, `helm template` ni `apply` ; la requête ne contient pas les identifiants (`! grep -q 'valeur-WASABI' "$FAKE_LOG"`), `STDIN curl` journalisé ;
  - base non prête (`FAKE_WAIT_ECHEC=1 FAKE_WAIT_ECHEC_SUR=cluster.postgresql`) : aucun `scale` ;
  - échec du Job de restauration (`0/1`) : code 1, aucun `apres-restauration`, **aucun `scale --replicas=<n>` de remise**, message « l'application reste arrêtée » présent, Job conservé (pas de `delete job` en fin) ;
  - échec du Job après restauration : idem, le Job de restauration déjà supprimé ;
  - relance après échec : `deployment.txt` avec `urbankiff-api 0 2` → pas de nouvelle annotation (`! grep 'annotate .*=0'`), remise à 2 en fin ;
  - échec de l'attente de disponibilité (`FAKE_WAIT_ECHEC_SUR=deployment`) : code 1 ; santé en échec (`FAKE_CURL_ECHEC_SUR=api/health`) : code 1 après remise des réplicas ;
  - jamais `restauration.active`, `restauration.purger`, `--atomic`, `helm upgrade`, `delete pvc|secret` dans `FAKE_LOG` ;
  - Secret sans `PGADMIN_EMAIL` : message dédié, rien arrêté ;
  - aucun secret (valeurs de `secret.txt` décodées) dans `FAKE_LOG` ni dans la sortie.
- [ ] **Étape 2** : implémenter.
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 5 : script, action `exporter-anonyme`

**Fichiers :**
- Modifier : `infra/deploiement/urbankiff-deploy.sh`
- Test : `infra/deploiement/tests/restauration-export.bats` [nouveau]

**Interfaces :**
- Consomme : contrat « Job d'export anonymisé » (`urbankiff-export-anonyme`, rendu si `exportAnonyme.prefixe` et
  `exportAnonyme.bucketCible` non vides, échec de rendu si `environnement` ≠ `prod`, journal `export terminé`) ; clé
  `BUCKET_COPIE_PREPROD`.
- Produit : `cmd_exporter_anonyme` : `version_deployee`, `telecharger_charts`, `rendre_job urbankiff urbankiff export-anonyme-job.yaml --set exportAnonyme.prefixe=restauration/<date>-prod-anonyme/ --set exportAnonyme.bucketCible=$BUCKET_COPIE_PREPROD --set environnement=prod --set wasabi.region=$WASABI_REGION,wasabi.endpoint=s3.$WASABI_REGION.wasabisys.com` (B3 : lus comme pour `urbankiff-donnees`, testés en bats), `lancer_job urbankiff-export-anonyme`, `suivre_job urbankiff-export-anonyme "export terminé"` (même budget de tentatives que la restauration), journal `export terminé : restauration/<date>-prod-anonyme/ vers <bucket>`. L'application **n'est pas arrêtée**.

- [ ] **Étape 1** : tests : succès en prod (arguments `--set` exacts, aucun `scale`) ; refus code 2 en preprod avant tout appel ; `BUCKET_COPIE_PREPROD` absent : code 1 sans appel ; Job en échec : code 1, Job conservé, message ; journal de fin absent : erreur ; le nom du bucket cible n'apparaît que dans un `--set`, jamais dans un autre contexte ; aucun secret en argument ni journalisé.
- [ ] **Étape 2** : implémenter.
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 6 : poste, `make restauration-lancer` et `make restauration-deposer`

**Fichiers :**
- Créer : `infra/deploiement/poste/restauration-lancer.sh`, `infra/deploiement/poste/restauration-deposer.sh`
- Modifier : `make/restauration.mk` (cibles `restauration-lancer`, `restauration-deposer`, variable `RCLONE_IMAGE := rclone/rclone:<version épinglée>`, `RESTAURATION_POSTE_ENV`), `make/deploiement.mk` (rien si `deploiement-lint` couvre déjà `poste/*.sh` : vérifier)
- Test : `infra/deploiement/tests/make-restauration.bats` [nouveau], faux `docker` étendu (tâche 1)

**Interfaces :**
- Consomme : `lib.sh` (`ssh_deploy`, `variable_github`, `usage`, `die`) ; variables GitHub `WASABI_BUCKET`, `WASABI_REGION`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS` de l'environnement.
- Produit :
  - `make restauration-lancer ENV=<preprod|prod> PREFIXE=restauration/<date>[-prod-anonyme]/` : même motif que le serveur (refus code 2 avant tout appel) ; pour `ENV=prod`, saisie interactive du mot `prod` sur `CONFIRMATION_TTY` (défaut `/dev/tty`), autre saisie : code 1 sans `ssh` ; puis `ssh_deploy "$env" "restaurer $PREFIXE" < /dev/null` (clé `~/.ssh/urbankiff-deploy-<env>`) ;
  - `make restauration-deposer ENV=<env> DUMP=<fichier> [FICHIERS=<dossier>] DATE=<AAAA-MM-JJ>` : `DUMP` doit exister, `DATE` au bon motif, `FICHIERS` doit être un dossier s'il est donné ; identifiants lus dans `WASABI_ACCESS_KEY_ID` et `WASABI_SECRET_ACCESS_KEY` de l'environnement du shell, sinon saisie masquée sur `SECRETS_TTY` (défaut `/dev/tty`) puis `export` ; bucket et région lus dans les variables GitHub de l'environnement ; deux `docker run --rm` de `$RCLONE_IMAGE` avec `-e RCLONE_CONFIG_WASABI_TYPE=s3 -e RCLONE_CONFIG_WASABI_PROVIDER=Wasabi -e RCLONE_CONFIG_WASABI_ENDPOINT=s3.<région>.wasabisys.com -e RCLONE_CONFIG_WASABI_REGION=<région> -e RCLONE_CONFIG_WASABI_SERVER_SIDE_ENCRYPTION=AES256 -e RCLONE_CONFIG_WASABI_ACCESS_KEY_ID -e RCLONE_CONFIG_WASABI_SECRET_ACCESS_KEY` (**sans valeur** pour les deux dernières : le script les exporte sous ces noms), `copyto` du dump vers `wasabi:<bucket>/restauration/<date>/base.dump` (dossier du dump monté en lecture seule), `copy` de `FICHIERS` vers `…/fichiers/` si donné, puis contrôle de taille : `size --json wasabi:<bucket>/restauration/<date>/base.dump` comparé à `wc -c < DUMP` (écart : erreur, code 1).

- [ ] **Étape 1** : tests (faux `docker`, `gh`, `ssh`) :
  - `restauration-lancer` : usage invalide (env, préfixe mal formé, `..`, préfixe sans `/`) → code 2 sans appel aux faux ; preprod : commande exacte `restaurer restauration/2026-11-17/` vers `deploy@serveur.test.example`, entrée de `ssh` vide (`STDIN ssh 0`), `--env preprod` ; prod : sans confirmation → rien n'est lancé, « prod » saisi → lancé, autre mot → code 1 sans `ssh` ;
  - `restauration-deposer` : usage invalide (date, `DUMP` absent, `FICHIERS` non dossier) ; chemin heureux avec valeurs des identifiants par l'environnement : `FAKE_LOG` contient les noms `RCLONE_CONFIG_WASABI_ACCESS_KEY_ID` mais **jamais** les valeurs de repère (`Valeur-Repere-…`) ; saisie masquée sur `SECRETS_TTY` quand les variables sont absentes, saisie vide → erreur ; sans `FICHIERS` : un seul `docker run` de copie ; contrôle de taille égal → code 0, différent (`FAKE_RCLONE_OCTETS`) → code 1 avec message ; aucun fichier créé dans le dépôt ni dans `TMPDIR` ;
  - `make -n` : les deux cibles s'expandent ; `@test "aucun fichier des cibles du poste n'active xtrace"` existant reste vert.
- [ ] **Étape 2** : implémenter les deux scripts (`set -euo pipefail`, `. lib.sh`) et les cibles (`@$(POSTE_ENV) $(POSTE)/…`, `.PHONY`, aide `##`). `make/restauration.mk` ne définit pas `POSTE_ENV` : le Makefile racine inclut `deploiement.mk` avant ; sinon le recopier avec une valeur identique et l'indiquer en commentaire (le *pourquoi*). Les tests lancent `make -f make/restauration.mk -f make/deploiement.mk`.
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 7 : poste, `make copie-prod-preprod`

**Fichiers :**
- Créer : `infra/deploiement/poste/copie-prod-preprod.sh`
- Modifier : `make/restauration.mk`
- Test : `infra/deploiement/tests/make-restauration.bats`

**Interfaces :**
- Consomme : `ssh_deploy` avec les deux clés (`urbankiff-deploy-prod`, `urbankiff-deploy-preprod`).
- Produit : `make copie-prod-preprod` : confirmation interactive du mot `prod` (`CONFIRMATION_TTY`) ; date = `DATE` (défaut : jour UTC) ; `ssh_deploy prod "exporter-anonyme $DATE"`, **puis seulement si le code est 0** `ssh_deploy preprod "restaurer restauration/$DATE-prod-anonyme/"` ; le premier échec arrête la copie (code propagé) ; message final.

- [ ] **Étape 1** : tests : confirmation absente → ni `ssh` ni `gh` ; deux `ssh` dans l'ordre, commandes exactes, entrées vides ; échec du premier (`ssh` en échec via un faux dédié ou `FAKE_SSH_ECHEC` ajouté au faux `ssh` pour la n-ième invocation) : second jamais lancé et code non nul ; `DATE=2026-1-1` refusé (code 2).
- [ ] **Étape 2** : implémenter.
- [ ] **Étape 3** : `make deploiement-test` et `make deploiement-lint` verts ; cocher ; commit.

---

### Tâche 8 : workflows `restauration.yml` et `copie-prod-preprod.yml`

**Fichiers :**
- Créer : `.github/workflows/restauration.yml`, `.github/workflows/copie-prod-preprod.yml`, `infra/deploiement/tests/workflow-restauration.bats`
- Test : `infra/deploiement/tests/workflow-restauration.bats`, `make workflow-lint`

**Interfaces :**
- Consomme : modèle SSH de `deploiement.yml` (étapes « Préparer SSH » et « Nettoyage ») sans le `toJSON`.
- Produit :
  - `restauration.yml` : `on: workflow_dispatch` avec entrées `environnement` (`type: choice`, `preprod` ou `prod`) et `prefixe` (`type: string`, obligatoire) ; `permissions: {}` global, job `restaurer` avec `contents: read`, `environment: ${{ inputs.environnement }}` (approbation de `prod`), `concurrency: group: deploiement-${{ inputs.environnement }}`, `cancel-in-progress: false`, `timeout-minutes: 60`. Étapes : checkout (`persist-credentials: false`), « Préparer SSH » (`DEPLOY_SSH_KEY: ${{ secrets.DEPLOY_SSH_KEY }}`, `DEPLOY_KNOWN_HOSTS: ${{ vars.DEPLOY_KNOWN_HOSTS }}`, `umask 077`), « Restaurer » (valeurs en `env:` : `PREFIXE`, `ENVIRONNEMENT`, `DEPLOY_HOST: ${{ vars.DEPLOY_HOST }}` ; le script valide `ENVIRONNEMENT` (`prod|preprod`), `PREFIXE` (même motif que le serveur) et `DEPLOY_HOST` avant `ssh -i … "restaurer $PREFIXE" < /dev/null`), « Nettoyage » (`if: always()`). **Aucune** entrée standard de secrets.
  - `copie-prod-preprod.yml` : `on: workflow_dispatch` sans entrée ; job `exporter` (`environment: prod`, concurrence `deploiement-prod`) qui calcule la date (`date -u +%F`, écrite dans `GITHUB_OUTPUT`), lance `exporter-anonyme <date>` ; job `restaurer` (`needs: exporter`, `environment: preprod`, concurrence `deploiement-preprod`) qui lance `restaurer restauration/<date>-prod-anonyme/` ; `timeout-minutes` sur chaque job ; chaque job a sa propre clé SSH (le secret `DEPLOY_SSH_KEY` de son environnement) et son propre nettoyage.

- [ ] **Étape 1** : `workflow-restauration.bats` sur les deux fichiers (sur le modèle de `workflow.bats`) : `workflow_dispatch` seul, jamais `pull_request*` ni `schedule` ni `push` ; `permissions: {}` et `contents: read` par job, pas de `write` ; **`! grep -q 'toJSON' ` et `! grep -q 'secrets\.' sauf DEPLOY_SSH_KEY`** (une seule référence par job) ; aucune expression `${{ … }}` dans un bloc `run:` ; pas de `xtrace` ni d'écho de la clé ; nettoyage `if: always()` avec `rm -f "$RUNNER_TEMP/deploy_key" "$RUNNER_TEMP/known_hosts"` ; `environment: ${{ inputs.environnement }}` dans `restauration.yml`, `environment: prod` puis `environment: preprod` dans la copie, `needs: exporter` ; `cancel-in-progress: false` ; `timeout-minutes` partout ; actions épinglées en `@vN` ; `ssh … < /dev/null` ; commandes SSH exactes (`restaurer "$PREFIXE"`, `exporter-anonyme "$DATE"`) ; `DEPLOY_HOST` validé avant `ssh`. Les voir échouer.
- [ ] **Étape 2** : écrire les deux workflows.
- [ ] **Étape 3** : `make deploiement-test` et `make workflow-lint` verts ; cocher ; commit.

---

### Tâche 9 : documentation `docs/v1/infra/deploiement.md`

**Fichiers :**
- Modifier : `docs/v1/infra/deploiement.md`

**Interfaces :**
- Consomme : comportement des tâches 2 à 8.
- Produit : tableau « Commandes acceptées » complété (`restaurer restauration/<date>[-prod-anonyme]/`, `exporter-anonyme <date>`, prod seulement) ; configuration serveur (`BUCKET_COPIE_PREPROD` dans `deploy.prod.env`, ajoutée par le lot 7) ; section « Restauration » (déroulé en six étapes, application laissée arrêtée en cas d'échec et marche à suivre, relance, aucune purge de Wasabi, rejeu) ; section « Copie prod → preprod anonymisée » ; tableau CI / poste (workflows manuels, cibles `restauration-lancer`, `restauration-deposer`, `copie-prod-preprod`, confirmation du mot `prod`) ; secrets `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` dans la liste `SECRET_KEYS` (renvoi à `secrets.md`, lot 6) ; remarque : un Secret déployé avant ce lot doit être complété par `make secrets-cluster` avant la première restauration ; table des cibles `make` complétée ; dépannage (préfixe introuvable, Job en échec, application restée arrêtée).

- [ ] **Étape 1** : relire la doc contre le script (`grep` des motifs de commande, des journaux, des noms de Jobs) ; aucune valeur propre au projet inventée.
- [ ] **Étape 2** : rédiger ; accents et français ; pas de `restauration.active`.
- [ ] **Étape 3** : `grep -n 'restauration.active\|restauration.purger' docs/v1/infra/deploiement.md` ne trouve rien ; cocher ; commit (`docs: ...`).

---

### Tâche 10 : réécriture de `docs/v1/infra/premier-deploiement-prod.md`

**Fichiers :**
- Modifier : `docs/v1/infra/premier-deploiement-prod.md` (réécrit)

**Interfaces :**
- Consomme : cibles et actions des tâches 4 à 7 ; spec § 5.8.
- Produit : procédure « répétée en preprod puis jouée en prod » : préalables (inspection `make sauvegarde-inspecter`, `make sauvegarde-repeter`, décision sur les règles `s3*` du fichier `regles_urls.json` du lot 1, secrets posés dont `PGADMIN_*`, Firebase et connexion Google préalables **à la prod seulement**) ; étape 1 dépôt (`make restauration-deposer ENV=preprod DUMP=… DATE=…`) ; étape 2 restauration (`make restauration-lancer ENV=preprod PREFIXE=…` ou workflow `Restauration`), contrôles dans le navigateur (front, panel, `https://preprod.db.urbankiff.com`, `https://preprod.stockage.urbankiff.com`, décomptes de tables égaux à ceux de `make sauvegarde-repeter`, images servies depuis l'hôte de la preprod) ; rejouer autant de fois que nécessaire ; même geste sur la prod avec **la sauvegarde de la prod** (`ENV=prod`, approbation `prod`, mot `prod`) ; mot de passe de l'administrateur (recréé par `prodseed` dans le Job après restauration) ; DNS et TLS (enregistrements des hôtes des outils créés par le développeur) ; retour arrière ; rotation des secrets. Le format du dépôt Wasabi est conservé ; plus aucune mention de `restauration.active`, `purger`, `copierFichiers`, ni de suppression du préfixe.

- [ ] **Étape 1** : relire contre `infra/restauration/` (format du dépôt, décomptes) et la spec § 5.2 et § 6.
- [ ] **Étape 2** : réécrire en conservant la structure « action puis contrôle » par étape.
- [ ] **Étape 3** : `grep -nE 'restauration\.(active|purger)|copierFichiers' docs/v1/infra/premier-deploiement-prod.md` ne trouve rien ; cocher ; commit.

---

### Tâche 11 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint` vert ; `make typecheck` : sans objet pour ce lot (aucun code api, panel ni nextjs modifié), lancé pour confirmer qu'il n'est pas dégradé.
- [ ] `make deploiement-test` (tous les bats du lot, y compris `inventaire-cles.bats` tolérant), `make deploiement-lint` (shellcheck) et `make workflow-lint` (actionlint) verts.
- [ ] `make secrets-scan` vert (aucun secret dans le dépôt).
- [ ] `make test-cible` et `make coverage-diff BASE=feature/outils-donnees` : sans objet (aucun code Python ni TypeScript) ; la couverture des chemins du script est celle des bats (chaque branche de `cmd_restaurer` et `cmd_exporter_anonyme` a un test).
- [ ] `make check-generated` et `make migrations-check` : sans objet pour ce lot (aucun modèle, aucun fichier généré).
- [ ] e2e : sans objet (aucun test e2e dans le projet).
- [ ] Périmètre : `make devteam-perimetre LOT=deploiement PLAN=docs/v1/plans/outils-donnees/5-deploiement.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler (dont ceux ci-dessous).

## Problèmes de contrat et points à signaler (pour le lead)

1. **Contrôle du préfixe côté serveur (étape 1 de la spec)** : le compte `deploy` n'a ni `rclone` ni `aws` ; le plan le fait avec `curl --aws-sigv4` (curl ≥ 7.75, identifiants sur `-K -`) vers `https://s3.<WASABI_REGION>.wasabisys.com/<WASABI_BUCKET>/<prefixe>base.dump`. Hypothèses : point d'accès Wasabi standard par région et curl suffisamment récent sur le serveur A (à vérifier par le développeur, ou lot 7).
2. **Journal de fin du Job `urbankiff-apres-restauration`** : le contrat 8.3 n'en fixe pas ; le script se fie à `status.succeeded`. Seuls `restauration terminée` et `export terminé` sont exigés.
3. **`inventaire-cles.bats` et `secrets.txt`** : `secrets.txt` ne gagne les deux clés qu'avec le lot 6 ; le plan rend les tests tolérants sur la branche du lot (ensemble `CLES_CONTRAT`), le serrage vers l'égalité stricte revient à la PR finale. De même `deploy` réel avec les anciens `secrets.txt` ne transmettrait pas `PGADMIN_*` : les deux lots arrivent ensemble.
4. **`urbankiff-secrets` existant** : un Secret créé avant ce lot (preprod en service) n'a pas `PGADMIN_*` ; `lire_cluster` refuse alors `restaurer` (et `deploy` sans entrée) tant que `make secrets-cluster` n'a pas complété le Secret.
5. **Rôle `deploy`** : les droits actuels couvrent `jobs` (écriture), `pods/log`, `deployments/scale` ; `helm get values` lit les Secrets de release. Aucun changement requis pour ce lot hors `middlewares` (lot 7).
6. **`restaurer` du préfixe `-prod-anonyme/` en prod** : refusé (code 2), arbitrage B2.
7. **Version de rendu** : le script rend les Jobs avec les charts de la version déployée (`image.etiquette` de la release `urbankiff`), pas la dernière ; les gabarits des lots 3 et 4 doivent donc être publiés dans une version déployée avant la première restauration.
8. **Découpage** : les tâches 6 à 8 (poste, workflows) ne dépendent que du format des commandes, pas du code du script ; le lot pourrait se scinder en « script » (tâches 1 à 5) et « poste et CI » (6 à 8), mais le gain est faible (aucun fichier partagé hors `make/restauration.mk`) : recommandation, ne pas scinder.
