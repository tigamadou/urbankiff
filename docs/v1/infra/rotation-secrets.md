# Runbook : rotation des secrets et publication

Source : spec `docs/v1/specs/2026-11-16-publication-depot-public.md`, plan
`docs/v1/plans/2026-11-16-publication-depot-public.md`, inventaire `docs/v1/infra/secrets.md`.

Toutes les actions de ce runbook sont faites par le développeur (serveurs, consoles, réglages GitHub). Aucune valeur
n'est écrite ici ni collée dans un terminal partagé, un ticket ou une conversation : les valeurs passent par un
gestionnaire de mots de passe ou directement par `make secrets-definir`. Cocher chaque case et noter la date.

`<A>` désigne le serveur applicatif, `<B>` le serveur de la base ; leurs adresses ne figurent pas dans le dépôt.

## Ordre des opérations

1. Mesures conservatoires sur A et B (tâche 5 du plan), **avant** toute publication.
2. Instantané, création et publication du nouveau dépôt (tâche 6).
3. Environnements GitHub et `make secrets-definir` pour `preprod` puis `prod` (tâche 7) : les nouvelles valeurs des
   fournisseurs sont créées dans leurs consoles juste avant, et saisies au script.
4. Révocation des anciennes valeurs chez les fournisseurs (tâche 8).

## 1. Mesures conservatoires

- [x] État de départ relevé : `make ports-scan HOTE=<A>` et `make ports-scan HOTE=<B>` — date : A le 2026-11-16 (22, 80, 443, 3000, 3051, 9002, 9003 ouverts) ; B le 2026-11-16 (pare-feu ouvrant 22, 80, 443 et 5432 à tout Internet ; PostgreSQL et Caddy en écoute)
- [x] A : conteneurs applicatifs de prod et de preprod arrêtés (`docker compose down` dans chaque dossier
      `prod_*` / `preprod_*`), Redis arrêté ; **volumes MinIO conservés** (pas de `-v`) — date : 2026-11-16 (tous les conteneurs passés en `restart=no` puis arrêtés)
- [x] A : pare-feu limité à 22 (plus strict : rien ne sert de trafic web avant la réinstallation ; 22, 80 et 443 à la reconstruction), par exemple :
      `ufw default deny incoming`, `ufw allow 22/tcp`, `ufw allow 80/tcp`, `ufw allow 443/tcp`, `ufw enable`.
      Docker publie ses ports en contournant `ufw` : les conteneurs qui publient un port (MinIO 9002/9003) sont
      arrêtés, ou leurs ports retirés — date : 2026-11-16
- [x] A : Caddy ne sert plus ni l'application ni les consoles MinIO : Caddy arrêté, ou ses blocs `*.urbankiff.com`,
      `s3*`, `s30*` et `preprod.*` retirés du Caddyfile puis Caddy rechargé. Les identifiants racine MinIO étant
      considérés comme volés, la console ne doit plus répondre, même par le port 443 — date : 2026-11-16 (Caddy arrêté)
- [x] Vérification depuis l'extérieur, pour chaque nom d'hôte de `caddyprod/CaddyFile` :
      `make hotes-scan` ; aucun ne doit afficher un code de réponse venant de l'application ou de MinIO — date : 2026-11-16 (10 noms d hôte : aucune réponse)
- [x] Firebase : projet supprimé (console Firebase → Paramètres du projet → Supprimer le projet). Il révoque la clé
      serveur FCM et la configuration du panel, qui figurent dans l'historique de l'archive — date : 2026-11-16
- [x] B : sauvegarde complète (`pg_dump -Fc`) copiée hors des serveurs, taille et somme de contrôle notées — date : 2026-11-16 (fait par le développeur, base et bucket MinIO)
- [x] B : PostgreSQL arrêté et désactivé au démarrage, Caddy arrêté, pare-feu limité à 22 (plus strict que « IP de A seulement » : la mission k3s restaure depuis la sauvegarde) — date : 2026-11-16
- [-] B : mot de passe de l'utilisateur applicatif changé (`ALTER ROLE <utilisateur> PASSWORD '…'`, saisi dans
      `psql` et non en argument de commande), nouvelle valeur gardée dans le gestionnaire de mots de passe : elle sert
      à l'export de la mission k3s et n'est **pas** le `POSTGRES_PASSWORD` de GitHub — sans objet : PostgreSQL arrêté et fermé au réseau, la nouvelle base est restaurée depuis la sauvegarde avec un nouveau mot de passe
- [x] A et B : anciennes clés de déploiement retirées de `~/.ssh/authorized_keys` (utilisateur de déploiement et
      `root`) ; aucune clé inconnue restante — date : A le 2026-11-16 (github-deploy-key retirée de root ; seule reste la clé personnelle du développeur, aucune clé inconnue ; refus de github-deploy-key vérifié depuis le poste) ; B le 2026-11-16 (seule la clé personnelle du développeur, pas de clé de déploiement)
- [x] A et B : connexion SSH par mot de passe désactivée (`/etc/ssh/sshd_config.d/10-durcissement.conf` :
      `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`, puis
      `sshd -t` et rechargement) ; vérifié depuis le poste : la clé passe, le mot de passe est refusé — date : A le
      2026-11-16 ; B le 2026-11-16
- [x] Vérification : `make ports-scan HOTE=<A>` n'affiche que 22 (A, tant qu'il n'est pas réinstallé) ;
      `make ports-scan HOTE=<B>` n'affiche que 22 — date : A le 2026-11-16 (22 seul) ; B le 2026-11-16 (`ss -tulpn` et `ufw status` sur B : seul 22 en écoute et autorisé)

## 2. Publication

- [x] `make secrets-scan` à zéro constat sur la branche de préparation — date : 2026-11-16
- [x] Instantané créé, `make secrets-scan-historique DOSSIER=../urbankiff-public` à zéro constat — date : 2026-11-16 (commit 3e9cf9f)
- [x] `tigamadou/urbankiff` renommé en `tigamadou/urbankiff-archive` (reste privé) — date : 2026-11-16
- [x] `tigamadou/urbankiff` créé, `development` et `main` poussées, branche par défaut `development`, dépôt passé en
      public — date : 2026-11-16 (premier push refusé par la protection au push : jeton Google dans un commentaire, retiré)

## 3. Nouvelles valeurs

Avant de lancer le script, créer chez chaque fournisseur la nouvelle valeur (sans encore révoquer l'ancienne) :

- [ ] Fournisseur SMTP : nouveau jeton créé — date :
- [ ] Twilio : nouveau jeton d'authentification généré (Console → Account → API keys & tokens ; le jeton secondaire
      permet de basculer avant de révoquer le principal) — date :
- [ ] Google Cloud : nouveau secret client OAuth créé (APIs & Services → Credentials → client OAuth → ajouter un
      secret) — date :
- [x] Environnements `preprod` et `prod` créés, analyse de secrets et protection au push activées — date : 2026-11-16 (prod : approbation obligatoire, tags v* seulement)
- [x] `make secrets-definir ENV=preprod REPO=tigamadou/urbankiff` : code 0 — date : 2026-11-16 (14 secrets, 18 variables)
- [x] `make secrets-definir ENV=prod REPO=tigamadou/urbankiff` : code 0 — date : 2026-11-16 (14 secrets, 18 variables)

> État au 2026-11-16 : les six secrets des fournisseurs (`SMTP_*`, `TWILIO_*`, `SOCIAL_AUTH_GOOGLE_OAUTH2_*`) ont
> reçu des **valeurs provisoires** dans `preprod` et `prod`. Les vraies valeurs seront créées dans les consoles puis
> posées avec `SEULEMENT="<noms>" make secrets-definir ENV=<env> REPO=tigamadou/urbankiff` avant le premier
> déploiement. Les révocations de la section 4 attendent ces nouvelles valeurs.

> État au 2026-11-16 : GitHub Actions ne crée aucune exécution sur le compte (quota inclus du mois épuisé, aucune
> cause trouvée côté dépôt ni côté budget). Le check obligatoire `ci-ok` a été **retiré temporairement** de la
> protection de `development` et `main` (force push et suppression restent interdits).

- [ ] Actions de nouveau fonctionnel (une PR déclenche `CI devteam`) et `ci-ok` rétabli comme check obligatoire sur
      `development` et `main` — date :

## 4. Révocations

- [ ] Fournisseur SMTP : ancien jeton révoqué — date :
- [ ] Twilio : ancien jeton d'authentification révoqué (promotion du jeton secondaire) — date :
- [ ] Google Cloud : ancien secret client OAuth supprimé — date :
- [ ] Ancien dépôt : secrets Actions de `tigamadou/urbankiff-archive` supprimés (`gh secret delete <NOM> --repo
      tigamadou/urbankiff-archive` pour chaque nom de `gh secret list`) — date :
- [ ] Anciens dépôts sources `tigamadou/urbankiff-api`, `urbankiff-nextjs`, `urbankiff-panel`, `urbankiff-minio` :
      secrets Actions supprimés de la même façon, dépôts archivés et laissés privés (leur historique contient les
      anciens `env.prod`) — date :
- [ ] Base migrée par la mission k3s : mot de passe de l'administrateur `prodseed` changé avant la remise en
      service (il valait `password`) — date :
