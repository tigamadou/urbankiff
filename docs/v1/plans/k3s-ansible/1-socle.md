# Socle — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : aucun arbitrage ne modifie ce lot ; le motif infra/**/.travail/ est confirmé.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : ouvrir le `Makefile` racine aux nouveaux fichiers `make/*.mk` (contrat 8.3 « Inclusion make ») et faire
ignorer par git l'inventaire Ansible réel et les dossiers de travail temporaires des lots infra.

**Architecture** : une seule ligne `-include $(filter-out …,$(wildcard make/*.mk))` ajoutée en fin de `Makefile`,
après les inclusions existantes (la cible par défaut reste `init`, première cible du fichier). Les quatre fichiers déjà
inclus explicitement sont exclus du joker pour éviter toute double inclusion. Deux lignes ajoutées à `.gitignore`.

**Stack** : GNU Make, git. Aucun code applicatif.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité). Plan de
la mission `k3s-ansible`, lot 1 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/k3s-ansible-socle` · **Base** : `feature/k3s-ansible` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ⬜ à faire · Prochaine tâche : 1

- [ ] **Tâche 1** Inclusion générique des `make/*.mk` dans le `Makefile` · `feature/k3s-ansible-socle`
  - [ ] Test : fichier temporaire `make/essai-socle.mk`, cible invisible avant, visible après
  - [ ] Ajouter la ligne d'inclusion
  - [ ] Contrôles : cible par défaut, `make help`, pas de double inclusion, nettoyage du fichier temporaire
- [ ] **Tâche 2** Ignorer l'inventaire Ansible et les dossiers `.travail/` dans `.gitignore` · `feature/k3s-ansible-socle`
  - [ ] Test `git check-ignore` rouge puis vert
  - [ ] Ajouter les deux motifs
- [ ] **Tâche 3** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `Makefile`
- `.gitignore`
- `docs/v1/plans/k3s-ansible/1-socle.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docs/v1/specs/2026-11-16-k3s-ansible.md`, `make/devteam.mk`, `make/standard.mk`, `make/secrets.mk`,
`make/devteam-agent.mk`, `.github/workflows/devteam-ci.yml`, `.claude/devteam.projet.md`, et tous les fichiers
exclusifs des autres lots.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles de test lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : aucune commande sur l'hôte hors `docker`, `make`,
`git`, `gh` ; pas de contournement de hook ; commits Conventional Commits ASCII sans trailer ; preuve avant
affirmation (lancer la commande, rapporter le résultat). Ce lot ne touche ni code applicatif, ni base, ni ORM : pas de
mock, pas de `retry`. Le « test » est un scénario `make -n` / `git check-ignore` ; les cibles `lint`, `typecheck`,
`coverage-diff` ne s'appliquent pas au code de ce lot (aucun fichier `apps/**` modifié) et sont lancées en
vérification de non-régression seulement. Le fichier temporaire `make/essai-socle.mk` ne doit **jamais** être commité.

## Points de revue

1. La nouvelle ligne est placée **après** les inclusions existantes : la cible par défaut (`init`) et les recettes des
   cibles existantes sont inchangées ; le joker exclut exactement `make/devteam.mk make/standard.mk make/secrets.mk
   make/devteam-agent.mk` (contrat 8.3, texte identique).
2. `-include` (tolérant) conservé, cohérent avec les inclusions existantes ; aucune double inclusion
   (`overriding recipe` absent de la sortie de `make -n`).
3. `.gitignore` : `infra/ansible/inventory.yml` ignoré mais pas un éventuel `infra/ansible/inventory.yml.example` ;
   `infra/**/.travail/` ignoré à toute profondeur.

---

### Tâche 1 : inclusion générique des `make/*.mk`

**Fichiers :**
- Modifier : `Makefile` (ajout en toute fin)
- Test : `make/essai-socle.mk` [temporaire, créé puis supprimé par le test, jamais commité]

**Interfaces :**
- Consomme : contrat 8.3 « Inclusion make (socle) » ; cible `help` de `make/standard.mk` (lit `$(MAKEFILE_LIST)`).
- Produit : tout `make/*.mk` ajouté par un lot aval (`infra.mk`, `helm.mk`, `deploiement.mk`, `restauration.mk`) est
  chargé automatiquement.

- [ ] **Étape 1** : écrire le test, le voir échouer.
  - Créer `make/essai-socle.mk` avec le contenu :
    ```
    .PHONY: essai-socle
    essai-socle: ## Cible temporaire du test du socle
    	@echo essai-socle
    ```
    (la recette commence par une tabulation).
  - `make -n essai-socle` : attendu **échec** (`No rule to make target 'essai-socle'`), preuve que le fichier n'est pas
    encore inclus.
- [ ] **Étape 2** : implémenter. Ajouter en fin de `Makefile`, après le bloc `-include make/secrets.mk` :
  ```
  -include $(filter-out make/devteam.mk make/standard.mk make/secrets.mk make/devteam-agent.mk,$(wildcard make/*.mk))
  ```
- [ ] **Étape 3** : relancer, tout vert.
  - `make -n essai-socle` : attendu `echo essai-socle`, code 0.
  - `make help` : la sortie contient `essai-socle` **et** les cibles existantes (`help`, `lint`, `test-cible`…).
  - Double inclusion : `make -n 2>&1 | grep -ci "overriding recipe\|ignoring old recipe"` : attendu `0` ; idem avec
    `make -n help` et `make -n essai-socle`.
  - Cible par défaut inchangée : `make -n` affiche la recette de `init` (`chmod +x init.sh && ./init.sh`) et non celle
    de `essai-socle`.
  - Supprimer `make/essai-socle.mk` (`rm` du fichier temporaire seul) ; `make -n essai-socle` échoue de nouveau ;
    `git status --short` ne montre que `Makefile` modifié (aucun `make/essai-socle.mk`).
  - Cocher l'Avancement ; commit d'une ligne : `chore: include make/*.mk files not already included`.

---

### Tâche 2 : `.gitignore`

**Fichiers :**
- Modifier : `.gitignore`

**Interfaces :**
- Consomme : chemins du contrat ansible (`infra/ansible/inventory.yml`, réel, jamais versionné) ; dossiers de travail
  temporaires des lots infra (convention proposée : `infra/**/.travail/`, à confirmer par le lead dev).
- Produit : motifs ignorés pour les lots `ansible`, `charts`, `deploiement`, `restauration`.

- [ ] **Étape 1** : écrire le test, le voir échouer. `git check-ignore -v infra/ansible/inventory.yml
  infra/ansible/.travail/x infra/helm/urbankiff/.travail/y` : attendu code 1 (rien d'ignoré) ;
  `git check-ignore infra/ansible/inventory.yml.example` : code 1 aussi (et il doit le rester à la fin).
- [ ] **Étape 2** : implémenter. Ajouter en fin de `.gitignore` :
  ```
  infra/ansible/inventory.yml
  infra/**/.travail/
  ```
- [ ] **Étape 3** : relancer. `git check-ignore -v` sur les trois premiers chemins : code 0, motif affiché pour
  chacun ; `infra/ansible/inventory.yml.example` : toujours code 1. Cocher l'Avancement ; commit d'une ligne :
  `chore: ignore ansible inventory and infra work directories`.

*(Les tâches 1 et 2 touchent des fichiers distincts mais sont ordonnées par simplicité ; le lot est court et
cohérent, aucun signal de scission.)*

---

### Tâche 3 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint` et `make typecheck` : non-régression (aucun fichier `apps/**` modifié, attendu vert).
- [ ] Tests ciblés : sans objet (aucun code de production) ; les scénarios des tâches 1 et 2 sont rejoués une dernière
  fois (recréer puis supprimer `make/essai-socle.mk`), `make -n` sans avertissement, `make help` complet.
- [ ] `make coverage-diff BASE=feature/k3s-ansible` : sans objet / vert (aucun code modifié).
- [ ] `make check-generated` et `make migrations-check` : sans objet (aucun fichier généré, aucun modèle).
- [ ] e2e : sans objet (aucun test e2e pour l'instant).
- [ ] Périmètre : `make devteam-perimetre LOT=1 PLAN=docs/v1/plans/k3s-ansible/1-socle.md BASE=origin/feature/k3s-ansible` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire
  disparaître). Vérifier aussi que `make/essai-socle.mk` n'existe plus.
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler.
