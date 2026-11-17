# Anonymisation (commande `anonymiser`, règles, garde-fous) — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d'écart) : B1.

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : fournir la commande `python manage.py anonymiser` qui remplace, sur une base PostgreSQL **locale et
jetable**, toutes les données de personnes par des valeurs factices, avec un fichier de règles classant **colonne par
colonne** chaque table portant des données de personnes, un garde-fou de classement (une colonne personnelle non
classée fait échouer) et un garde-fou d'environnement (refus sur une vraie base).

**Architecture** : une commande Django unique (`apps/user/management/commands/anonymiser.py`) qui contient le
garde-fou d'environnement, le chargement et la validation des règles, le garde-fou de classement
(`verifier_classement`, fonction pure alimentée par le schéma introspecté de la base) et le moteur d'application
(SQL ensembliste, une transaction, `SET CONSTRAINTS ALL IMMEDIATE` en fin de transaction pour valider l'intégrité).
Le fichier `apps/user/regles_anonymisation.json` est la seule source des règles. Le Job d'export du lot 4 lance la
commande dans un PostgreSQL temporaire du pod avec `ANONYMISATION_AUTORISEE=1` et `POSTGRES_HOST=127.0.0.1`.

**Stack** : Python 3.9, Django 4.1.13, PostgreSQL (psycopg2), tests Django (`TestCase`) sur la base de test du lot.
Aucun modèle, aucune migration, aucune dépendance nouvelle.

**Spec** : `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (section « Organisation du travail » ; elle fait
autorité). Plan de la mission `outils-donnees`, lot 2 sur 7.

## Exécution

- **Mission** : `outils-donnees` · **Issue** : issue `lot:anonymisation` créée par le superviseur
- **Branche** : `feature/outils-donnees-anonymisation` · **Base** : `feature/outils-donnees` · **Profil** : api
- **Dépendances** : aucune (lots qui doivent être fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 7

- [x] **Tâche 1** Garde-fou d'environnement et squelette de la commande · `feature/outils-donnees-anonymisation`
  - [x] Tests du garde-fou (code 2, rien modifié) écrits et vus en échec
  - [x] Commande `anonymiser` (garde-fou, option `--regles`, chargement et validation du format des règles)
  - [x] Tests verts
- [x] **Tâche 2** Moteur d'application des traitements
  - [x] Tests (chaque traitement, vidage de table, journal, idempotence, intégrité) écrits et vus en échec
  - [x] Moteur SQL en une transaction
  - [x] Tests verts
- [x] **Tâche 3** Garde-fou de classement
  - [x] Tests (colonne non classée, table inconnue, colonne suspecte, vraie table temporaire) écrits et vus en échec
  - [x] `verifier_classement` branché au début de la commande
  - [x] Tests verts
- [x] **Tâche 4** Inventaire et fichier de règles complet
  - [x] Test « le vrai schéma est entièrement classé » vu en échec
  - [x] `regles_anonymisation.json` : toutes les tables et colonnes de personnes
  - [x] Tests verts
- [x] **Tâche 5** Aucune valeur d'origine ne subsiste, compatibilité `prodseed`
  - [x] Tests de bout en bout (jeu de données de sentinelles, balayage de toute la base) écrits
  - [x] Corrections de règles si une valeur subsiste
  - [x] Tests verts
- [x] **Tâche 6** Commande `lister_fichiers_publics` (arbitrage B1)
  - [x] Tests (garde-fou, clés citées, dédoublonnage, exclusion avatar et pièces d'identité) écrits et vus en échec
  - [x] Commande `lister_fichiers_publics`
  - [x] Tests verts
- [ ] **Tâche 7** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `apps/api/apps/user/management/commands/anonymiser.py` [nouveau]
- `apps/api/apps/user/regles_anonymisation.json` [nouveau]
- `apps/api/apps/user/test_anonymiser.py` [nouveau]
- `apps/api/apps/user/management/commands/lister_fichiers_publics.py` [nouveau]
- `apps/api/apps/user/test_lister_fichiers_publics.py` [nouveau]
- `docs/v1/plans/outils-donnees/2-anonymisation.md` (ce plan : Avancement)

## Fichiers en lecture seule

- La spec `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` et tous les fichiers exclusifs des autres lots.
- Tous les modèles : `apps/api/apps/**/models.py`, `apps/api/apps/user/base.py`, et les migrations. **Aucun modèle,
  aucune migration** dans ce lot : `make migrations-check` doit rester vert sans rien générer.
- `apps/api/apps/user/management/commands/prodseed.py`, `clearcache.py`, `apps/api/apps/user/test_prodseed.py`,
  `apps/api/apps/user/factories.py` (utilisés, jamais modifiés).
- `apps/api/project/**` (notamment `settings.py` : liste des applications installées, `test_runner.py`).
- `.claude/**`, `CLAUDE.md`, `make/**`, `.github/**`, `infra/**`.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : tests Django lancés par
`make test-cible T=apps/api/apps/user/test_anonymiser.py` (le chemin devient le label `apps.user.test_anonymiser`) ;
le lanceur `project.test_runner.AgentLotTestRunner` refuse toute base autre que `urbankiff_<lot>` quand `AGENT_LOT`
est défini (ne jamais contourner) ; couverture par `make coverage-diff BASE=feature/outils-donnees` ; lint par
`make lint-api` (flake8, `--ignore E501,E722,F821,W504`). Au minimum : aucun mock de la base ni de l'ORM ; fabriques
(`UserFactory`) ou création ORM directe pour les données ; ne jamais modifier le code de production pour faire passer
un test (s'arrêter et le signaler) ; couverture de 100 % du code modifié ; pas de `retry` ni de contournement pour
masquer une instabilité ; toutes les commandes passent par `make`.

Contraintes propres au lot :

- **Garde-fou d'environnement (contrat 8.3)** : `python manage.py anonymiser` refuse de tourner, **code 2, rien
  modifié**, sauf si `ANONYMISATION_AUTORISEE=1` **et** `POSTGRES_HOST` vaut `127.0.0.1` ou `localhost`. Le contrôle
  se fait **avant** toute lecture de la base et avant le chargement des règles. Réalisé par
  `CommandError(message, returncode=2)`. Succès : code 0. Dans les tests, la base de test n'est pas locale
  (`POSTGRES_HOST` = service Compose) : les tests qui doivent faire tourner la commande posent les deux variables avec
  `mock.patch.dict(os.environ, ...)` (mock d'**environnement** seulement, jamais de l'ORM).
- **Autres échecs** (règles invalides, classement incomplet) : `CommandError` de code 1, rien modifié. Le Job du lot 4
  traite tout code non nul comme un échec.
- La commande ne lit que `os.environ` et la connexion Django par défaut ; elle n'écrit rien en dehors de la base.
- SQL construit avec `connection.ops.quote_name` pour les identifiants et des paramètres (`%s`) pour les valeurs ;
  jamais de valeur issue de la base dans le texte SQL.
- **Rien d'inventé dans le journal** : chaque ligne `anonymiser : <table>.<colonne> : <n> ligne(s)` (colonnes) ou
  `anonymiser : <table> : <n> ligne(s) supprimée(s)` (tables vidées), et la ligne finale `anonymisation terminée`.
  Jamais de valeur de donnée dans les journaux.
- Aucun nouveau fichier hors des cinq fichiers du lot. Les identifiants et chaînes de code sont en anglais ou en
  français comme le reste du lot (noms de règles en français, valeurs factices ASCII).

## Format du fichier de règles

`apps/api/apps/user/regles_anonymisation.json` :

```json
{
  "version": 1,
  "motifs_suspects": ["email", "mail", "phone", "contact", "name", "firstname", "lastname", "username", "ip",
                      "addr", "address", "token", "password", "otp", "secret", "birthday", "bio", "nationality",
                      "uid", "agent", "browser", "registration"],
  "tables_a_vider": ["django_session", "authtoken_token"],
  "tables_classees": {
    "user_user": {
      "cle": "id",
      "colonnes": {
        "id":        {"action": "garder"},
        "email":     {"action": "anonymiser", "traitement": "texte_par_id", "modele": "user-{id}@exemple.invalid"},
        "contact":   {"action": "anonymiser", "traitement": "nombre_par_id", "base": 99000000000},
        "password":  {"action": "anonymiser", "traitement": "aleatoire", "prefixe": "!"},
        "birthday":  {"action": "anonymiser", "traitement": "valeur_fixe", "valeur": null}
      }
    }
  },
  "sans_donnees_personnelles": {
    "category_category": {"name": "nom de rubrique éditoriale, pas une personne"},
    "post_post": {}
  }
}
```

- `tables_a_vider` : tables dont **toutes** les lignes sont supprimées (jetons, sessions, journaux d'accès, files de
  messages). Aucune classification de colonnes (il ne reste rien). Ordre libre : les contraintes de clé étrangère de
  Django sont différées, la validation a lieu en fin de transaction.
- `tables_classees` : tables « personnes » dont les lignes restent. `cle` : colonne de clé primaire (défaut `id`).
  **Chaque colonne de la table** est `garder` ou `anonymiser` ; `anonymiser` exige un `traitement` parmi :
  - `texte_par_id` : `modele` avec le motif `{id}` remplacé par la clé (e-mails, noms, identifiants, jetons uniques) ;
  - `nombre_par_id` : `base` + clé (téléphones : numéro factice non attribuable) ;
  - `aleatoire` : `prefixe` + `md5(random()::text || clé)` (mots de passe inutilisables, préfixe `!` comme
    `make_password(None)` ; secrets) ;
  - `valeur_fixe` : `valeur` constante (JSON : `null`, `""`, `{}`, nombre, texte, adresse IP de documentation
    `192.0.2.1`).
- `sans_donnees_personnelles` : toutes les autres tables du schéma. Valeur = dictionnaire des colonnes dont le nom
  correspond à un motif suspect, **chacune justifiée** par une phrase (sinon le garde-fou échoue).
- `motifs_suspects` : mots (séparés par `_` dans le nom de colonne) qui font soupçonner une donnée personnelle.

## Inventaire des données de personnes

Établi à partir des modèles de `apps/api/apps/**/models.py` et des applications installées
(`apps/api/project/settings.py`). Les noms de tables sont `<app>_<modèle>` en minuscules ; l'exécutant **vérifie
chaque nom et chaque colonne** par introspection (tâche 4) : cette liste est le point de départ, le garde-fou de la
tâche 3 est l'arbitre.

**Tables vidées (`tables_a_vider`)** :

| Table | Pourquoi |
| --- | --- |
| `django_session` | sessions (clé, données) |
| `authtoken_token` | jetons d'API (`rest_framework.authtoken`) |
| `user_passwordresettoken` | jetons de réinitialisation de mot de passe |
| `mail_otp` | adresses e-mail et codes à usage unique |
| `mail_mail` | boîte d'envoi : `to_email`, `data` (JSON avec e-mail, noms, liens), `body`, `subject`, `api_response_text` |
| `error_error` | `ip`, `platform`, `browser`, `message` (JSON de requête possible) |
| `rest_framework_tracking_apirequestlog` | `drf-api-tracking` : `remote_addr`, `host`, `path`, `query_params`, `data`, `response`, utilisateur |
| `push_notifications_gcmdevice`, `…_apnsdevice`, `…_wnsdevice`, `…_webpushdevice` | `registration_id`, `device_id`, clés Web Push, utilisateur |
| `oauth2_provider_accesstoken`, `…_refreshtoken`, `…_grant`, `…_idtoken` | jetons OAuth2 (`django-oauth-toolkit`) |
| `social_auth_usersocialauth`, `…_nonce`, `…_association`, `…_code`, `…_partial` | identifiants de comptes Google (`uid`, `extra_data` : e-mail, nom), codes de vérification, états partiels |
| `django_admin_log` | `object_repr`, `change_message` (valeurs saisies dans l'admin) |

**Tables classées « personnes » (lignes conservées, colonnes classées)** :

| Table | À anonymiser | À garder |
| --- | --- | --- |
| `user_user` | `email` → `user-{id}@exemple.invalid` ; `contact` → `99000000000 + id` ; `firstname` → `Prenom{id}` ; `lastname` → `Nom{id}` ; `username` → `utilisateur-{id}` ; `password` → `!` + aléatoire ; `avatar` → `images/fck2c7a8-gc4v-4q3s-behi-5fhnqti9mak4.jpg` (valeur par défaut de `prodseed`, B1) ; `bio`, `address`, `birthday`, `id_img` (pièce d'identité, vidé, B1), `nationality`, `residence_country` → `null` | `id`, `last_login`, `is_superuser`, `deleted`, `status`, `is_staff`, `is_active`, `date_joined` |
| `user_device` | `registration_id` → `appareil-{id}` | `id`, `created_at` |
| `user_invitation` | `invitee_email` → `invite-{id}@exemple.invalid` ; `token` → `invitation-{id}` ; `message` → `null` | `id`, `inviter_id`, `status`, `role`, `created_at`, `expires_at` |
| `comment_report` | `ip` → `192.0.2.1` ; `browser` → `""` | `id`, `reason`, `date`, `post_id`, `comment_id`, `reporter_id` |
| `post_postview` | `ip_address` → `null` ; `user_agent` → `null` | `id`, `post_id`, `viewed_at` |
| `workers_task` | `args`, `kwargs` → `{}` ; `error` → `""` | `id`, `handler`, `schedule`, `run_at`, `created_at`, `completed_at`, `status` |
| `oauth2_provider_application` | `client_secret` → aléatoire (secret de la prod, voir « Décisions de classement ») | tout le reste, dont `user_id` |

**Sans données de personnes (`sans_donnees_personnelles`)** : tout le reste du schéma, avec justification des
colonnes suspectes : `category_category`, `post_tag`, `post_post` (+ table de liaison des étiquettes), `page_page`,
`menu_menu`, `banner_campaign`, `banner_media`, `scrapper_scrapper`, `file_file`, `like_like`, `comment_comment`,
`comment_subcomment`, `comment_comment_sub_comments`, `comment_comment_users`, `comment_comment_posts`,
`mail_template`, `mail_layout`, `twilio_twilioservice`, `user_user_devices`, `user_user_groups`,
`user_user_user_permissions`, `auth_group`, `auth_group_permissions`, `auth_permission`, `django_content_type`,
`django_migrations`, `admin_interface_theme`, `oauth2_provider_*` restantes si présentes, et toute autre table
d'application tierce trouvée à l'introspection.

**Décisions de classement à signaler au développeur dans l'issue** (le plan les tranche ainsi, elles sont réversibles
par une ligne du fichier de règles) :

1. `user_user.avatar` : **anonymisé** (arbitrage B1) : remis à la valeur par défaut de `prodseed`. Le fichier
   d'avatar d'origine n'est jamais copié (voir tâche 6).
2. `user_user.id_img` : **vidé** (pièce d'identité, B1). Le fichier pointé n'est jamais copié : la liste de
   `lister_fichiers_publics` ne le contient pas.
3. `oauth2_provider_application.client_secret` : remplacé (secret de la prod, ne doit pas aller en preprod) ; les
   lignes restent. Conséquence : l'application OAuth2 de la preprod devra être recréée ou son secret reposé à la main.
4. `comment_comment.content`, `comment_subcomment.content`, `comment_report.reason` : gardés (texte public ou de
   modération ; peut contenir des données saisies librement, risque résiduel accepté à confirmer).
5. `twilio_twilioservice.service_id` : gardé (identifiant du service Verify de la configuration, pas une personne ;
   même compte Twilio en preprod, spec § 5.1).
6. L'administrateur de la prod est anonymisé comme les autres (spec § 5.6) ; les groupes et rôles restent : il garde
   son rôle sous l'adresse `user-<id>@exemple.invalid`, son mot de passe est inutilisable. `prodseed` recrée
   `urbankiff@admin.com` avec le mot de passe de la preprod.

---

### Tâche 1 : garde-fou d'environnement et squelette de la commande

**Fichiers :**
- Créer : `apps/api/apps/user/management/commands/anonymiser.py`, `apps/api/apps/user/test_anonymiser.py`,
  `apps/api/apps/user/regles_anonymisation.json` (version minimale : `{"version": 1, "motifs_suspects": [],
  "tables_a_vider": [], "tables_classees": {}, "sans_donnees_personnelles": {}}`)
- Modifier : aucun
- Test : `apps/api/apps/user/test_anonymiser.py`

**Interfaces :**
- Consomme : `os.environ` (`ANONYMISATION_AUTORISEE`, `POSTGRES_HOST`), contrat 8.3.
- Produit : `Command` (option `--regles <chemin>` facultative, défaut = `regles_anonymisation.json` à côté de
  l'application ; sert aux tests et ne change pas le contrat) ; `charger_regles(chemin)` qui valide le format (clés
  obligatoires, `action` ∈ {garder, anonymiser}, `traitement` connu avec ses paramètres, motif `{id}` présent pour
  `texte_par_id`, aucune table présente dans deux sections) et lève `CommandError` (code 1) sinon.

- [ ] **Étape 1** : écrire les tests, les voir échouer. Classe `GardeFouEnvironnementTests(TestCase)` : un utilisateur
  créé avec `UserFactory(email="origine@exemple.org")` ; pour chaque cas de refus, `call_command("anonymiser")` lève
  `CommandError` avec `returncode == 2` **et** l'e-mail de l'utilisateur est inchangé : variable absente, valeur `0`,
  valeur `true`, `POSTGRES_HOST=postgresDB`, `POSTGRES_HOST=db.prod.example`, `POSTGRES_HOST` absent, hôte avec
  préfixe (`127.0.0.1.evil.example`), les deux conditions réunies seulement avec `ANONYMISATION_AUTORISEE=1` et
  `127.0.0.1` ou `localhost` passent le garde-fou (utiliser un fichier de règles vide : code 0). Test que le refus
  intervient **avant** le chargement des règles (chemin `--regles` inexistant + garde-fou non satisfait → code 2, pas
  code 1). Classe `ChargementReglesTests` : un fichier JSON temporaire (`tempfile`) par cas invalide (JSON illisible,
  traitement inconnu, `texte_par_id` sans `{id}`, `action` inconnue, table dans deux sections, `nombre_par_id` sans
  `base`) → `CommandError` de code 1 ; et le fichier livré se charge.
- [ ] **Étape 2** : implémenter le garde-fou (fonction `verifier_environnement()` appelée en premier dans `handle`),
  `charger_regles`, l'option `--regles`.
- [ ] **Étape 3** : `make test-cible T=apps/api/apps/user/test_anonymiser.py` vert ; cocher l'Avancement ; commit
  d'une ligne (`feat: garde-fou et chargement des regles de anonymiser`).

---

### Tâche 2 : moteur d'application des traitements

**Fichiers :**
- Modifier : `apps/api/apps/user/management/commands/anonymiser.py`, `apps/api/apps/user/test_anonymiser.py`
- Test : `apps/api/apps/user/test_anonymiser.py`

**Interfaces :**
- Consomme : règles chargées (tâche 1), connexion Django par défaut.
- Produit : `appliquer(regles, stdout)` : dans `transaction.atomic()`, pour chaque table de `tables_a_vider` un
  `DELETE FROM`, pour chaque colonne `anonymiser` un `UPDATE` ensembliste (une seule requête par colonne) ; en fin de
  transaction `SET CONSTRAINTS ALL IMMEDIATE` ; journal `anonymiser : <table>.<colonne> : <n> ligne(s)`,
  `anonymiser : <table> : <n> ligne(s) supprimée(s)`, puis `anonymisation terminée`.

- [ ] **Étape 1** : tests d'abord, avec un fichier de règles **de test** (temporaire, sur `user_user`,
  `user_invitation`, `mail_otp`, `django_session`) : chaque traitement produit la valeur attendue
  (`texte_par_id` : e-mail `user-<id>@exemple.invalid`, prénom `Prenom<id>`, valeurs distinctes pour deux utilisateurs
  donc contrainte `unique` de `email` et `username` respectée ; `nombre_par_id` : `contact == base + id` ;
  `aleatoire` : préfixe `!`, deux lignes différentes, `has_usable_password()` faux et `check_password` faux ;
  `valeur_fixe` à `null`, chaîne vide, JSON) ; les lignes des tables vidées disparaissent (`count() == 0`) ; une
  colonne `garder` n'est pas touchée ; nombre de lignes de `user_user` inchangé ; clés étrangères intactes
  (`Invitation.inviter` résolu) ; le journal contient les lignes attendues et **aucune valeur d'origine** ; **idempotence** :
  deux exécutions de suite donnent le même état (les valeurs par identifiant sont stables) ; une violation d'intégrité
  provoquée (règle qui viderait `user_user` alors que `user_invitation` la référence) fait échouer la commande et
  **annule tout** (la transaction est défaite : les e-mails d'origine sont toujours là).
- [ ] **Étape 2** : implémenter `appliquer` (identifiants cités par `quote_name`, valeurs en paramètres, motif `{id}`
  découpé en parties passées en paramètres et concaténées en SQL, colonne de clé = `cle`).
- [ ] **Étape 3** : relancer, tout vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 3 : garde-fou de classement

**Fichiers :**
- Modifier : `apps/api/apps/user/management/commands/anonymiser.py`, `apps/api/apps/user/test_anonymiser.py`
- Test : `apps/api/apps/user/test_anonymiser.py`

**Interfaces :**
- Consomme : règles chargées ; schéma de la base.
- Produit : `lire_schema(connection)` (dictionnaire `table → [colonnes]` de **toutes** les tables du schéma `public`,
  par `connection.introspection.table_names()` et `get_table_description`, sans modèle ni mock) ;
  `verifier_classement(regles, schema)` (fonction pure) qui renvoie la liste des problèmes ; `handle` l'appelle après
  le garde-fou d'environnement et avant toute modification : un problème → `CommandError` (code 1) listant chaque
  problème, **rien modifié**. Problèmes détectés :
  1. table du schéma absente des trois sections (table nouvelle non classée) ;
  2. table de `tables_classees` dont une colonne du schéma n'est ni `garder` ni `anonymiser` (colonne non classée),
     ou dont une colonne classée n'existe plus (règle périmée) ;
  3. table de `sans_donnees_personnelles` ou colonne d'une table `garder` dont le nom contient un motif suspect (mot
     séparé par `_`) sans justification dans le fichier ;
  4. table des règles absente du schéma (règle périmée) ;
  5. colonne `garder` dont le nom évoque une donnée personnelle dans une table `tables_classees` **sans** que la
     règle porte une `justification` (une colonne suspecte gardée doit dire pourquoi ; ex. `avatar`, `reason`).

- [ ] **Étape 1** : tests d'abord. Cas purs avec un schéma synthétique (dictionnaires, pas de mock) : schéma complet
  → aucun problème ; une colonne `phone` ajoutée à une table classée sans règle → problème 2 ; une table nouvelle
  `nouvelle_table(id, email)` → problème 1 ; une table nouvelle sans colonne suspecte mais non classée → problème 1
  quand même ; `contact_name` dans une table `sans_donnees_personnelles` sans justification → problème 3, avec
  justification → aucun problème ; colonne `ip_address` gardée sans justification → problème 5 ; règle périmée →
  problèmes 2 et 4 ; détection par mot (`description` ne déclenche pas `ip`, `ip_address` oui, `remote_addr` oui).
  Cas **réel** : dans un `TestCase`, créer par `cursor.execute` une table `CREATE TABLE zz_nouvelle (id serial,
  email varchar(50))` (annulée à la fin du test par la transaction), lire le schéma réel, vérifier que
  `verifier_classement` la signale ; et que la commande, lancée avec le garde-fou d'environnement satisfait, échoue
  (code 1) sans rien modifier (e-mail d'un utilisateur inchangé) tant que la table n'est pas classée.
- [ ] **Étape 2** : implémenter `lire_schema`, `verifier_classement`, le branchement dans `handle`.
- [ ] **Étape 3** : relancer ; les tests de la tâche 2 (règles de test limitées à quelques tables) doivent désormais
  fournir un fichier de règles classant **tout** le schéma : ajouter dans le fichier de test une fonction
  `regles_de_test(**sections)` qui part des vraies tables lues (`lire_schema`) et place automatiquement dans
  `sans_donnees_personnelles` (avec justifications synthétiques) tout ce que le test ne classe pas. Tout vert ;
  cocher l'Avancement ; commit d'une ligne.

---

### Tâche 4 : inventaire et fichier de règles complet

**Fichiers :**
- Modifier : `apps/api/apps/user/regles_anonymisation.json`, `apps/api/apps/user/test_anonymiser.py`
- Test : `apps/api/apps/user/test_anonymiser.py`

**Interfaces :**
- Consomme : schéma réel de la base de test (toutes les applications installées, y compris
  `rest_framework_tracking`, `push_notifications`, `oauth2_provider`, `social_django`, `authtoken`, `sessions`,
  `admin`).
- Produit : le fichier livré classe **toutes** les tables du schéma (inventaire ci-dessus).

- [ ] **Étape 1** : test d'abord, `ReglesLivreesTests` : `verifier_classement(charger_regles(fichier livré),
  lire_schema(connection))` renvoie une liste vide. Vu en échec avec le fichier minimal de la tâche 1 (affichage de la
  liste des problèmes : c'est la feuille de route). Test complémentaire : chaque table de `tables_a_vider` et de
  `tables_classees` existe, et chacun des noms de tables d'**applications locales** (`apps.get_models(
  include_auto_created=True)` filtré sur les `app_label` de `apps.*`) apparaît dans une section.
- [ ] **Étape 2** : rédiger `regles_anonymisation.json` d'après l'inventaire. Pour chaque table de la sortie du
  garde-fou, relire **le modèle** (ou, pour les tiers, les colonnes introspectées) et classer chaque colonne ; une
  colonne gardée dont le nom évoque une personne porte une `justification`. Aucune table classée « sans données de
  personnes » sans avoir lu ses colonnes. Si une table tierce contient des données de personnes absentes de
  l'inventaire, l'ajouter et le noter dans l'issue.
- [ ] **Étape 3** : relancer, tout vert ; `make lint-api` ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 5 : aucune valeur d'origine ne subsiste, compatibilité `prodseed`

**Fichiers :**
- Modifier : `apps/api/apps/user/test_anonymiser.py` ; `apps/api/apps/user/regles_anonymisation.json` seulement si
  une valeur subsiste (correction de règle)
- Test : `apps/api/apps/user/test_anonymiser.py`

**Interfaces :**
- Consomme : fichier de règles livré, commande complète (garde-fou, classement, moteur).
- Produit : la preuve exigée par la spec § 5.6 et § 7.

- [ ] **Étape 1** : tests (ils échouent tant qu'une règle manque). Classe `AucuneValeurOrigineTests(TestCase)` : un
  jeu de données de **sentinelles** créé par l'ORM (sans mock), couvrant chaque table de l'inventaire :
  utilisateurs (`UserFactory` avec e-mail `sentinelle.<n>@vrai-domaine.org`, `contact=22998877665`, prénom, nom,
  `username`, `bio`, `address`, `birthday=1990-05-17`, `id_img`, `nationality`, `residence_country`, mot de passe
  réel via `set_password`), administrateur (`is_superuser`, rôle `administrator`), `Device`, `PasswordResetToken`,
  `Invitation`, `OTP`, `Mail` (avec `data` JSON contenant l'e-mail et le nom), `Report` (`ip=203.0.113.77`),
  `Error`, `PostView` (`ip_address=203.0.113.78`, `user_agent`), `Task` (`args` avec e-mail), `Token` DRF, session
  Django, `Application` et `AccessToken`/`RefreshToken` OAuth2, `UserSocialAuth`, `GCMDevice`, `APIRequestLog`,
  `LogEntry` de l'admin. Contenus à garder : un `Post`, une `Category`, un `Comment`, une `File`. Après
  `call_command("anonymiser")` (environnement posé par `mock.patch.dict`) :
  1. **balayage global** : pour **toutes** les tables du schéma (introspection), toutes les colonnes lues en
     `::text`, aucune valeur ne contient `sentinelle`, `vrai-domaine`, `22998877665`, `203.0.113.7`, `1990-05-17`, ni
     l'une des valeurs de sentinelle posées (liste construite à partir des objets créés) ;
  2. chaque table de `tables_a_vider` est vide ;
  3. chaque colonne `anonymiser` de `tables_classees` ne contient plus aucune des valeurs d'origine enregistrées
     avant l'exécution (comparaison ligne à ligne par clé, y compris celles que le balayage textuel ne couvre pas :
     nombres, dates) ;
  4. les colonnes `garder` sont inchangées (`Post.title`, `Category.name`, `File.name`, dates, clés étrangères) et le
     nombre de lignes des tables classées est inchangé ;
  5. aucun mot de passe d'origine ne se valide (`check_password` faux, `has_usable_password()` faux), aucun e-mail
     d'origine ne se retrouve par `User.objects.filter(email=…)` ;
  6. second passage : idempotent, mêmes résultats.
- [ ] **Étape 2** : test de **compatibilité `prodseed`** (spec § 5.6, ordre des étapes) : après anonymisation du jeu
  précédent (qui contient `urbankiff@admin.com`), `call_command("prodseed")` avec `DJANGO_SUPERUSER_PASSWORD` posé crée
  l'administrateur de la preprod sans collision (`username`/`email` uniques) et `check_password` vaut le mot de passe
  fourni ; l'ancien administrateur existe sous `user-<id>@exemple.invalid` avec un mot de passe inutilisable.
- [ ] **Étape 3** : si une valeur subsiste, corriger **la règle** (pas le test) ; relancer tout vert ; cocher
  l'Avancement ; commit d'une ligne.

---

### Tâche 6 : commande `lister_fichiers_publics` (arbitrage B1)

**Fichiers :**
- Créer : `apps/api/apps/user/management/commands/lister_fichiers_publics.py`,
  `apps/api/apps/user/test_lister_fichiers_publics.py`
- Modifier : aucun

**Interfaces :**
- Consomme : base **déjà anonymisée** ; garde-fou d'environnement de la tâche 1 (`verifier_environnement`, importé de
  `anonymiser` : même contrat, code 2 sinon, avant toute lecture de la base) ; `FILES_CDN_ENDPOINT` pour reconnaître
  les URL de fichiers.
- Produit : `python manage.py lister_fichiers_publics` écrit sur la sortie standard **une clé d'objet du bucket par
  ligne**, relative à la racine du bucket, dédoublonnée (ordre trié, rien d'autre sur la sortie standard), code 0.
  Colonnes publiques lues : `post_post.image`, `audio`, `video` ; URL de fichiers dans `post_post.content` et
  `post_post.intro` ; `page_page.content` ; `banner_media.file` ; `scrapper_scrapper.image` et `content` ;
  `file_file.url` **des seuls fichiers cités** par ces colonnes. Jamais `user_user.avatar`, `user_user.id_img` ni une
  autre colonne de personnes.

- [ ] **Étape 1** : tests d'abord (base de test, ORM réel, environnement posé par `mock.patch.dict`). Garde-fou :
  mêmes variantes de refus que la tâche 1 (code 2, sortie vide). Contenu : un `Post` avec `image`, `audio`, `video`,
  une URL de fichier dans `content` et dans `intro`, une `Page` avec URL dans `content`, un `Media` de bannière, un
  `Scrapper` (image et `content`), deux `File` dont un seul cité (seul celui-là sort) ; l'URL au préfixe du CDN et la
  valeur déjà relative donnent la même clé ; une clé citée deux fois sort une fois ; une URL externe (hors CDN) est
  ignorée ; un utilisateur avec `avatar` et `id_img` sentinelles : **aucune** de ces clés dans la sortie ; base vide →
  sortie vide, code 0 ; rien n'est modifié en base.
- [ ] **Étape 2** : implémenter la commande (lecture seule, SQL ou ORM, extraction des URL par expression régulière
  sur le préfixe du CDN, jamais de valeur issue d'une autre colonne).
- [ ] **Étape 3** : tests verts ; `make lint-api` ; cocher l'Avancement ; commit d'une ligne
  (`feat: commande lister_fichiers_publics`).

---

### Tâche 7 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make lint` et `make typecheck` verts (`typecheck` : sans objet pour l'api, noter la sortie).
- [ ] Tests ciblés du lot : `make test-cible T=apps/api/apps/user/test_anonymiser.py apps/api/apps/user/test_lister_fichiers_publics.py`, puis
  `make test-cible T=apps/api/apps/user/test_prodseed.py` (non régression).
- [ ] `make coverage-diff BASE=feature/outils-donnees` : 100 % du code modifié.
- [ ] `make migrations-check` vert (aucun modèle touché) ; `make check-generated` : sans objet (aucun fichier généré
  versionné).
- [ ] e2e du lot : sans objet (aucun test e2e pour l'instant).
- [ ] Contrôle de contrat 8.3 : la commande refuse (code 2) sans `ANONYMISATION_AUTORISEE=1` ou avec un hôte non
  local, et rien n'est modifié ; code 0 sinon ; règles lues dans `apps/api/apps/user/regles_anonymisation.json`.
- [ ] Périmètre : `make devteam-perimetre LOT=anonymisation PLAN=docs/v1/plans/outils-donnees/2-anonymisation.md
  BASE=origin/feature/outils-donnees` ; attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou
  signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats, points à signaler
  (décisions de classement 1 à 6 ci-dessus, signalements ci-dessous).

## Points de revue

1. Le garde-fou d'environnement s'exécute **avant** toute lecture de la base et des règles ; refus = code 2 et aucune
   écriture (tests sur chaque variante de `POSTGRES_HOST`, dont les préfixes trompeurs).
2. Toutes les tables du schéma sont classées (y compris tables tierces et tables de liaison) ; une table nouvelle ou
   une colonne personnelle non classée fait échouer **la commande** et **le test**.
3. Le test « aucune valeur d'origine ne subsiste » balaie **toute** la base (toutes tables, toutes colonnes en
   texte), pas seulement les colonnes listées dans les règles.
4. Aucune valeur de donnée dans le journal ni dans les messages d'erreur.
5. Mots de passe : préfixe `!` (inutilisables), jamais de hash conservé ; jetons, sessions, codes, journaux d'accès :
   vidés.
6. `lister_fichiers_publics` n'émet que des clés citées par le contenu public, dédoublonnées, relatives au bucket ;
   ni avatar ni `id_img` n'y figurent ; même garde-fou d'environnement que `anonymiser`.
7. Les décisions de classement 1 à 6 sont tracées dans l'issue pour validation du développeur.

## Signalements (non traités par ce lot)

- **Fichiers copiés (B1, résolu)** : l'export ne copie que les fichiers listés par `lister_fichiers_publics` (tâche 6) ; le lot 4 copie avec `rclone copy --files-from`. Ni avatars réels ni pièces d'identité.
- **Version de l'image** : la commande classe le schéma de l'image qui la porte ; si la base de la prod contient une
  table ou colonne absente des règles (déploiement décalé), l'export échoue (code 1) : c'est voulu.
- **Ordre des étapes** : l'export (lot 4) lance `anonymiser` sur la base temporaire, avant le dépôt ; `prodseed` tourne
  côté preprod après la restauration (Job après restauration) : conforme au test de compatibilité de la tâche 5.
