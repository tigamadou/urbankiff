# Réécriture des URL de fichiers (`reecrire_urls`) — Plan d'implémentation

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir la commande Django `python manage.py reecrire_urls`, qui remplace dans la base les préfixes
d'URL absolues de fichiers (règles « source → `FILES_CDN_ENDPOINT` ») après une restauration, de façon idempotente,
avec un journal par colonne.

**Architecture** : une commande de gestion dans l'app `file` (`apps/file/management/commands/reecrire_urls.py`). Les
règles vivent dans `apps/file/regles_urls.json` (liste d'objets `{"source": "<préfixe>"}`) ; la cible est lue dans
`settings.FILES_CDN_ENDPOINT`. Un inventaire figé de colonnes (constante de la commande) distingue deux modes :
**préfixe** (la colonne est une URL : on remplace le début) et **contenu** (la colonne est du texte qui peut embarquer
des URL : on remplace chaque occurrence). Les mises à jour passent par `QuerySet.update()` avec les fonctions SQL
`Concat`, `Substr`, `Replace` (une requête par colonne et par règle, dans une transaction), sans toucher à
`updated_at`.

**Stack** : Python 3.9, Django, PostgreSQL (base de test Django), `django.test.TestCase`.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité). Plan de la mission `outils-donnees`, lot 1 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : issue `lot:reecriture-urls` créée par le superviseur
- **Branche** : `feature/outils-donnees-reecriture-urls` · **Base** : `feature/outils-donnees` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : ✅ terminé

- [x] **Tâche 1** Squelette, chargement et validation des règles, garde-fou de la cible · `feature/outils-donnees-reecriture-urls`
  - [x] Tests (fichier livré, fichier invalide, cible absente) écrits et vus en échec
  - [x] `management/__init__.py`, `commands/__init__.py`, `regles_urls.json`, commande (chargement seul)
  - [x] Tests verts
- [x] **Tâche 2** Colonnes en mode « préfixe », journal, idempotence
  - [x] Tests (une colonne par test, journal, idempotence, valeurs hors règle intactes) écrits et vus en échec
  - [x] Réécriture et journal
  - [x] Tests verts
- [x] **Tâche 3** Colonnes en mode « contenu », règles `s3*`, cas limites
  - [x] Tests (contenu HTML, règle à chemin de bucket, frontière de préfixe, cible préfixée par la source, atomicité) écrits et vus en échec
  - [x] Implémentation
  - [x] Tests verts
- [x] **Tâche 4** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `apps/api/apps/file/management/commands/reecrire_urls.py` [nouveau]
- `apps/api/apps/file/regles_urls.json` [nouveau]
- `apps/api/apps/file/test_reecrire_urls.py` [nouveau]
- `apps/api/apps/file/management/__init__.py` [nouveau, vide ; absent aujourd'hui]
- `apps/api/apps/file/management/commands/__init__.py` [nouveau, vide ; absent aujourd'hui]
- `docs/v1/plans/outils-donnees/1-reecriture-urls.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (§ 5.3 et § 8.3 : contrat de la commande) et tous les
  fichiers exclusifs des autres lots (notamment `apps/api/apps/user/management/commands/anonymiser.py`, lot 2).
- Les modèles lus pour l'inventaire : `apps/api/apps/file/models.py`, `apps/api/apps/post/models.py`,
  `apps/api/apps/banner/models.py`, `apps/api/apps/scrapper/models.py`, `apps/api/apps/page/models.py`,
  `apps/api/apps/user/models.py`, `apps/api/apps/menu/models.py`, et leurs migrations. Aucun changement de modèle :
  `make migrations-check` doit rester vert.
- `apps/api/project/**` (notamment `settings.py` : `FILES_CDN_ENDPOINT` ; `test_runner.py`), `apps/api/apps/user/factories.py`,
  `apps/api/apps/file/views.py` (format d'URL produit à l'envoi : `<FILES_CDN_ENDPOINT>/<nom>`),
  `apps/api/apps/workers/management/commands/clearcache.py` (modèle de commande existant), `make/standard.mk`,
  `.claude/**`, `CLAUDE.md`.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : tests Django lancés par `make test-cible T=apps/api/...`
(le chemin `apps/api/apps/file/test_reecrire_urls.py` devient le label `apps.file.test_reecrire_urls`) ; le lanceur
`project.test_runner.AgentLotTestRunner` refuse toute base autre que `urbankiff_<lot>` quand `AGENT_LOT` est défini (ne
jamais contourner ce garde-fou) ; couverture par `make coverage-diff BASE=feature/outils-donnees` ; lint par
`make lint` (flake8 de l'api). Au minimum : aucun mock de la base ni de l'ORM (tests sur la base de test, enregistrements
créés par l'ORM, `UserFactory` pour les utilisateurs) ; ne jamais modifier le code de production pour faire passer un
test (s'arrêter et le signaler) ; couverture de 100 % du code modifié ; pas de `retry` ni de contournement pour masquer
une instabilité ; toutes les commandes passent par `make`.

Contrat 8.3 de la spec, à respecter exactement (s'il faut le changer, s'arrêter et le signaler) :

- commande : `python manage.py reecrire_urls` ;
- règles lues dans `apps/api/apps/file/regles_urls.json` : liste d'objets `{"source": "<préfixe>"}` ; cible =
  `FILES_CDN_ENDPOINT` de l'environnement ;
- idempotente ; journal : une ligne `reecrire_urls : <table>.<colonne> : <n> ligne(s)` par colonne ; code 0 si succès ;
- le fichier livré contient au moins `https://api.urbankiff.com/file` ; les règles `s3*` sont ajoutées par le
  développeur après l'inspection de la sauvegarde (hors de ce lot : le plan ne les invente pas) ;
- consommateur : le Job `urbankiff-apres-restauration` (lot 4) lance `python manage.py migrate && python manage.py
  reecrire_urls && python manage.py prodseed && python manage.py clearcache`. La commande ne demande donc **aucun
  argument** et ne doit pas dépendre d'un état laissé par `migrate`.

Ajouts compatibles avec le contrat (facultatifs pour l'appelant) : l'option `--regles <chemin>` (fichier de règles
alternatif, utile aux tests ; défaut : le fichier versionné).

**Inventaire des colonnes** (établi à partir des modèles ; table SQL = `<app>_<modèle>`, colonnes en minuscules) :

| Table.colonne | Type | Mode | Raison |
| --- | --- | --- | --- |
| `file_file.url` | URLField(500) | préfixe | URL publique du fichier téléversé (`<CDN>/<nom>`) |
| `post_post.image` | CharField(5000) | préfixe | image d'article |
| `post_post.audio` | CharField(5000), nullable | préfixe | fichier audio hébergé |
| `post_post.video` | CharField(5000), nullable | préfixe | fichier vidéo hébergé |
| `banner_media.file` | URLField | préfixe | média de bannière |
| `scrapper_scrapper.image` | CharField(1000) | préfixe | image d'article importé |
| `user_user.id_img` | CharField(1000), nullable | préfixe | image du profil / pièce d'identité |
| `post_post.content` | TextField | contenu | HTML d'article : images insérées par l'éditeur |
| `post_post.intro` | CharField(10000) | contenu | peut contenir du HTML avec images |
| `page_page.content` | TextField | contenu | HTML de page |
| `scrapper_scrapper.content` | TextField | contenu | HTML d'article importé |

Colonnes examinées et **exclues** (liens de navigation ou externes, pas des fichiers du bucket) : `post_post.url`,
`banner_media.url` (lien de clic de la bannière), `scrapper_scrapper.link` et `.website`, `menu_menu.url`. Le plan
d'exécution reporte dans l'issue tout écart constaté avec l'inventaire (par exemple une colonne utilisée en pratique
pour un fichier). Aucune colonne `ImageField` / `FileField` n'existe (`File` ne stocke que `name`, `path`, `url`), donc
rien à réécrire côté `FileField`.

## Points de revue

1. **Idempotence réelle** : deux exécutions de suite donnent la même base ; la seconde journalise `0 ligne(s)` partout.
   Cas piégeux couverts par un test : la cible commence par la source (par exemple source `https://h/file`, cible
   `https://h/file/v2`) ne doit pas re-réécrire indéfiniment.
2. **Frontière de préfixe** : la source `https://api.urbankiff.com/file` ne réécrit pas `https://api.urbankiff.com/files-x/…`
   (le préfixe est comparé avec une `/` finale, que la source ou la cible en aient une ou non).
3. **Aucune donnée hors règle n'est touchée** : URL externes (`https://exemple.org/x.jpg`), valeurs vides ou `NULL`,
   colonnes exclues de l'inventaire.
4. **Atomicité** : si une colonne échoue (valeur trop longue après réécriture, par exemple), rien n'est modifié, le
   code de sortie est non nul, l'erreur est lisible.
5. **Pas de secret ni d'URL de l'environnement dans le fichier de règles** : seules les sources (anciens hôtes) y sont.
6. **Le journal reste exactement au format du contrat** (le script du lot 5 et les humains le lisent).

---

### Tâche 1 : squelette, chargement et validation des règles

**Fichiers :**
- Créer : `apps/api/apps/file/management/__init__.py`, `apps/api/apps/file/management/commands/__init__.py` (vides),
  `apps/api/apps/file/regles_urls.json`, `apps/api/apps/file/management/commands/reecrire_urls.py`,
  `apps/api/apps/file/test_reecrire_urls.py`
- Modifier : aucun
- Test : `apps/api/apps/file/test_reecrire_urls.py`

**Interfaces :**
- Consomme : `settings.FILES_CDN_ENDPOINT` (`apps/api/project/settings.py`, lecture seule) ; option `--regles`.
- Produit : commande `reecrire_urls` (`BaseCommand`) ; constante `COLONNES` (inventaire ci-dessus, tuples
  `(modèle, champ, mode)`) ; fonction de chargement des règles qui renvoie la liste de sources normalisées (espaces
  retirés, `/` finale retirée) ; fichier `regles_urls.json` contenant `[{"source": "https://api.urbankiff.com/file"}]`.

- [ ] **Étape 1** : écrire les tests (`TestCase`, `call_command(..., stdout=StringIO())`, `override_settings`), les voir
  échouer :
  - le fichier livré `regles_urls.json` est du JSON valide, une liste d'objets, et contient la source
    `https://api.urbankiff.com/file` ;
  - `FILES_CDN_ENDPOINT` absent ou vide (`override_settings(FILES_CDN_ENDPOINT=None)`) → `CommandError`, message
    clair, aucune ligne modifiée (créer un `Post` avec une URL qui correspondrait, vérifier qu'elle est intacte) ;
  - fichier de règles invalide via `--regles` (JSON cassé, racine non liste, objet sans `source`, `source` vide ou non
    texte, fichier inexistant) → `CommandError` à chaque fois ;
  - liste de règles vide → succès, journal sans modification (la ligne `0 ligne(s)` est testée à la tâche 2).
  Les fichiers de règles de test sont écrits dans un dossier temporaire (`tempfile.TemporaryDirectory`).
- [ ] **Étape 2** : créer les deux `__init__.py` vides, `regles_urls.json` (JSON indenté, un objet par ligne), et la
  commande : `add_arguments` (`--regles`, défaut = `regles_urls.json` à côté du module de l'app), chargement et
  validation, lecture de la cible (retirer la `/` finale), `handle` qui ne réécrit rien encore.
- [ ] **Étape 3** : relancer `make test-cible T=apps/api/apps/file/test_reecrire_urls.py`, tout vert ; `make lint` ;
  cocher l'Avancement ; commit d'une ligne (`feat: commande reecrire_urls, chargement des regles`).

---

### Tâche 2 : colonnes en mode « préfixe », journal, idempotence

**Fichiers :**
- Modifier : `apps/api/apps/file/management/commands/reecrire_urls.py`
- Test : `apps/api/apps/file/test_reecrire_urls.py`

**Interfaces :**
- Consomme : la tâche 1 (règles chargées, `COLONNES`, cible) ; les modèles `File`, `Post`, `Media` (banner),
  `Scrapper`, `User` (lecture seule).
- Produit : pour chaque colonne de mode « préfixe » et chaque règle, `UPDATE … SET col = <cible>/ || SUBSTR(col, n)`
  filtré par `col LIKE '<source>/%'` et `NOT col LIKE '<cible>/%'` ; une ligne de journal par colonne de l'inventaire
  (**toutes** les colonnes, même à 0), format exact `reecrire_urls : <table>.<colonne> : <n> ligne(s)`, où `<n>` est
  la somme des lignes changées par toutes les règles ; écrite sur `self.stdout`.

- [ ] **Étape 1** : tests, vus en échec. Données créées par l'ORM (`UserFactory` pour `owner` / `author`,
  `Category.objects.create` pour `Post.category`, `Campaign.objects.create` pour `Media.campaign`) :
  - un test par colonne de mode préfixe : `File.url`, `Post.image`, `Post.audio`, `Post.video`, `Media.file`,
    `Scrapper.image`, `User.id_img` valent après `https://api.urbankiff.com/file/x.jpg` →
    `<cible>/x.jpg` (cible = `override_settings(FILES_CDN_ENDPOINT='https://preprod.api.urbankiff.com/file')`),
    relues avec `refresh_from_db()` ;
  - journal : la sortie contient exactement les lignes attendues avec les bons décomptes (par exemple deux `Post` à
    réécrire → `reecrire_urls : post_post.image : 2 ligne(s)`), et une ligne par colonne de l'inventaire, y compris
    à `0 ligne(s)` ; code de sortie 0 (la commande ne lève pas) ;
  - idempotence : deuxième `call_command` → base identique et tous les décomptes à 0 ;
  - une cible égale à la source (prod) → rien ne change, décomptes à 0 ;
  - valeurs intactes : URL externe, chaîne vide, `NULL` (`audio`, `video`, `id_img`), URL déjà à la cible, colonnes
    exclues (`Post.url`, `Media.url`, `Scrapper.link`, `Menu.url` contenant la source : inchangées) ;
  - deux règles dans le fichier (`--regles` temporaire) : les deux sources sont réécrites vers la même cible.
- [ ] **Étape 2** : implémenter la boucle règles × colonnes en mode préfixe avec `Concat`, `Substr`, `Value` et
  `startswith` de l'ORM (le motif `LIKE` est échappé par Django), dans `transaction.atomic()` ; accumuler les décomptes
  par colonne ; écrire le journal à la fin (dans l'ordre de `COLONNES`) ; `Value` converti avec `output_field`
  explicite.
- [ ] **Étape 3** : tests verts, `make lint` ; cocher l'Avancement ; commit d'une ligne
  (`feat: reecriture des urls de fichiers en mode prefixe, journal et idempotence`).

---

### Tâche 3 : colonnes en mode « contenu », règles `s3*`, cas limites

**Fichiers :**
- Modifier : `apps/api/apps/file/management/commands/reecrire_urls.py`
- Test : `apps/api/apps/file/test_reecrire_urls.py`

**Interfaces :**
- Consomme : la tâche 2 (boucle, journal, atomicité).
- Produit : pour les colonnes de mode « contenu » (`Post.content`, `Post.intro`, `Page.content`,
  `Scrapper.content`), `UPDATE … SET col = REPLACE(col, '<source>/', '<cible>/')` filtré par
  `col LIKE '%<source>/%'` ; règle ignorée dans ce mode, avec un avertissement sur `self.stderr`, si la cible commence
  par la source (le remplacement se répéterait à chaque passage) ; toutes les sources de type chemin de bucket
  (`https://s3.exemple.org/urbankiff`) fonctionnent sans code spécifique.

- [ ] **Étape 1** : tests, vus en échec :
  - un `Post.content` HTML (`<p><img src="https://api.urbankiff.com/file/a.png"> et <img src="…/file/b.png"></p>`)
    voit **chaque** occurrence réécrite, le reste du HTML intact ; idem `Post.intro`, `Page.content`,
    `Scrapper.content` ; décomptes en lignes (pas en occurrences) ;
  - règle à chemin de bucket (fichier de règles de test `{"source": "https://s3.exemple.org/urbankiff"}`) :
    `Post.image` et un `Post.content` contenant `https://s3.exemple.org/urbankiff/x.png` pointent vers
    `<cible>/x.png` (cas des anciennes URL MinIO du plan `k3s-ansible/8-restauration.md`) ;
  - frontière de préfixe : `https://api.urbankiff.com/files-x/y.png` et `https://api.urbankiff.com/filex` ne sont
    pas réécrits (source `https://api.urbankiff.com/file`) ; source et cible données avec ou sans `/` finale donnent
    le même résultat ;
  - cible qui commence par la source (source `https://h.example/file`, cible `https://h.example/file/v2`) : deuxième
    passage identique au premier, aucun `…/v2/v2` ; avertissement présent pour le mode contenu ;
  - atomicité : une réécriture qui dépasse la longueur de colonne (`File.url`, 500 caractères : valeur proche de 500 et
    cible plus longue que la source) fait lever une erreur de base, **aucune** autre colonne n'est modifiée (la
    transaction est annulée ; le test s'exécute avec `TransactionTestCase` si `TestCase` masque le comportement, sinon
    `assertRaises` + relecture) ; le code de sortie de `manage.py` serait non nul (l'exception remonte).
- [ ] **Étape 2** : implémenter le mode contenu (`Replace`, filtre `contains`), l'avertissement, et rendre la boucle
  commune aux deux modes sans duplication ; vérifier que `COLONNES` est le seul endroit à modifier pour ajouter une
  colonne.
- [ ] **Étape 3** : tests verts, `make lint` ; cocher l'Avancement ; commit d'une ligne
  (`feat: reecriture des urls en mode contenu et cas limites`).

---

### Tâche 4 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint` et `make typecheck` verts (`typecheck` : sans objet pour l'api, à constater).
- [ ] Tests ciblés du lot : `make test-cible T=apps/api/apps/file` (les tests existants de `file` restent verts avec
  les nouveaux).
- [ ] Contrôle de contrat à la main sur la base du worktree (`make` seulement, sans mock) : exécuter la commande
  complète, par une cible `make` du profil `api` qui lance `python manage.py reecrire_urls` si elle existe ; sinon, le
  test de bout en bout `call_command('reecrire_urls')` sans option (fichier livré, cible de l'environnement de test)
  fait foi, et le signaler dans le rapport. Vérifier le format du journal et le code 0.
- [ ] `make coverage-diff BASE=feature/outils-donnees` : 100 % du code modifié.
- [ ] `make check-generated` : sans objet (aucun fichier généré versionné). `make migrations-check` : vert (aucun
  modèle modifié).
- [ ] e2e du lot : sans objet (aucun test e2e pour l'instant, profil `api`).
- [ ] Périmètre : `make devteam-perimetre LOT=reecriture-urls PLAN=docs/v1/plans/outils-donnees/1-reecriture-urls.md BASE=origin/feature/outils-donnees` ;
  attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler
  (écarts avec l'inventaire des colonnes ; rappel : les règles `s3*` sont ajoutées par le développeur après
  `make sauvegarde-inspecter`, hors lot).
