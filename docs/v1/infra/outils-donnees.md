# Outils web : pgAdmin et console du stockage

Deux outils d'administration sont exposés en HTTPS par le chart `urbankiff-donnees`, dans la preprod comme en prod :

| Outil | Rôle | Preprod | Prod |
|---|---|---|---|
| pgAdmin 4 | base `urbankiff-pg` (PostgreSQL) | `preprod.db.urbankiff.com` | `db.urbankiff.com` |
| Console RustFS | fichiers du stockage interne | `preprod.stockage.urbankiff.com` | `stockage.urbankiff.com` |

Le port S3 (9000) de RustFS reste interne au cluster : seuls le port 443 de Traefik et ces deux hôtes sont publics.

## Enregistrements DNS à créer

À créer par le développeur chez le gestionnaire de la zone `urbankiff.com`, vers l'IP du serveur de chaque environnement :
`db`, `stockage`, `preprod.db` et `preprod.stockage`. Sans eux, cert-manager ne peut pas émettre les certificats
(`urbankiff-db-tls`, `urbankiff-stockage-tls`).

## pgAdmin

- Connexion : l'e-mail et le mot de passe viennent des secrets `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE`
  (`urbankiff-secrets`).
- Le serveur `urbankiff-pg` est préconfiguré (ConfigMap `urbankiff-pgadmin-config`, `servers.json`) : hôte
  `urbankiff-pg-rw`, port 5432, base et utilisateur `urbankiff`. Le mot de passe n'est jamais écrit dans la
  configuration : pgAdmin lit un fichier de mots de passe copié depuis le Secret `urbankiff-pg-app` (clé `pgpass`, généré
  par CloudNativePG) en `0600` par un init container.
- pgAdmin tourne en non root, système de fichiers en lecture seule, sans accès à Internet (vérification des mises à
  jour désactivée) ; ses données (`/var/lib/pgadmin`) sont éphémères : les préférences se perdent au redémarrage, la
  connexion préconfigurée est recréée.

## Console RustFS

- Servie par le pod `urbankiff-rustfs` existant (port 9001, aucun pod supplémentaire).
- Le login est le couple `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` de `urbankiff-secrets`.

## Protection

- Traefik applique une limitation de débit par IP source (`ingress.limiteDebit` : 20 requêtes par seconde en moyenne,
  rafale de 50) et des en-têtes HSTS (un an, sous-domaines compris, `nosniff`, `frameDeny`).
- **Aucune authentification côté Traefik** : le login de l'outil est la seule barrière. Conséquence : les mots de passe
  `PGADMIN_MOT_DE_PASSE` et `MINIO_ROOT_PASSWORD` doivent être forts, et leur compromission donne un accès complet à la
  base ou au stockage.
- NetworkPolicies : voir [kubernetes.md](kubernetes.md#outils-web).

## Quota de la preprod

Mesuré avec `make helm-controle` et `make helm-rendu ENV=preprod` :

- limites en régime établi : 2 048 Mi pour un quota de 3 072 Mi (pgAdmin : 320 Mi) ;
- pire chevauchement (migrations et CronJob) : 2 432 Mi ;
- requêtes mémoire en régime établi : 1 000 Mi (api 200, nextjs 192, workers 128, panel 32, PostgreSQL 192, Redis 32,
  RustFS 64, pgAdmin 160) pour un quota de requêtes de 1 536 Mi. Ce contrôle n'est pas encore dans `controle.rb` : il a été
  fait à la main sur le rendu.
- La console RustFS tourne dans les 192 Mi de limite de RustFS ; à surveiller à l'usage.
