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
- requêtes mémoire : régime établi 936 Mi (api 200, nextjs 192, workers 128, panel 32, PostgreSQL 192, Redis 32,
  RustFS 64, pgAdmin 96), plus Barman 256, le pod de mise à jour 200 et le plus gros Job 128 : 1 520 Mi pour un quota de
  requêtes de 1 536 Mi. Ce contrôle est dans `controle.rb` (`make helm-controle`) ; pgAdmin ne peut pas dépasser
  112 Mi de requête sans le faire échouer.
- La console RustFS tourne dans les 192 Mi de limite de RustFS ; à surveiller à l'usage.

## Points à vérifier sur la preprod

- **Limite de débit et adresse du client** : le Middleware `urbankiff-outils-limite-debit` utilise `ipStrategy depth 0`
  (adresse de la connexion). Derrière le ServiceLB de k3s, cette adresse peut être celle du noeud : tous les clients
  partageraient alors un seul seau (20 req/s, rafale 50) et un chargement de pgAdmin (nombreux fichiers statiques)
  pourrait le saturer. Si c'est le cas : `externalTrafficPolicy: Local` sur le Service de Traefik, ou
  `X-Forwarded-For` avec un `depth` adapté.
- **pgAdmin 9.9.0 en lecture seule** : l'entrypoint de l'image écrit les variables `PGADMIN_CONFIG_*` dans
  `/pgadmin4/config_distro.py`, non monté inscriptible (seuls données, tmp, journaux et pgpass le sont). Si le démarrage
  échoue sur ce point, prévoir un `emptyDir` ou un `config_distro.py` fourni par ConfigMap. Non vérifiable par les
  tests de rendu (risque d'exécution 7 du plan).
