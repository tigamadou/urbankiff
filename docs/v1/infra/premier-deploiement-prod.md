# Premier déploiement de la prod : restauration de la sauvegarde

Procédure écrite par la mission `k3s-ansible` (spec `docs/v1/specs/2026-11-16-k3s-ansible.md`, § 5.10 et § 5.11), réécrite par
la mission `outils-donnees` (spec `docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md`, § 5.2 et § 5.8). **Rien de ce qui est
décrit ici n'est exécuté par une mission** : le développeur la déroule à la main. Principe : **répéter en preprod, puis jouer
en prod** le même geste. La restauration est rejouable autant de fois que nécessaire, car la sauvegarde reste dans Wasabi.
Chaque étape a une action et un contrôle ; ne passer à la suivante que si le contrôle est bon.

Le mécanisme est l'action serveur `restaurer <prefixe>` de `urbankiff-deploy` (déroulé en six étapes, échecs, relance :
`docs/v1/infra/deploiement.md`, section « Restauration »). Le Job `urbankiff-restauration` lance
`pg_restore --no-owner --no-privileges --schema=public` sur le cluster CloudNativePG `urbankiff-pg` après remise à zéro du
schéma `public`, puis copie `fichiers/` dans le bucket RustFS ; le Job `urbankiff-apres-restauration` rejoue les migrations
et recrée l'administrateur `prodseed`.

Format du dépôt dans Wasabi (inchangé) :

```
restauration/<AAAA-MM-JJ>/base.dump     # dump PostgreSQL au format custom
restauration/<AAAA-MM-JJ>/fichiers/     # contenu du bucket
```

## 0. Préalables

- Sur le poste du développeur, sur la sauvegarde du 2026-11-16 : `make sauvegarde-inspecter DUMP=<dump> BUCKET=<dossier>` puis
  `make sauvegarde-repeter DUMP=<dump>`. Contrôle : rapports lus et validés par le développeur, décision prise sur les règles
  `s3*` et `s30*` du fichier `regles_urls.json` (réécriture ou validation), décomptes de la répétition notés.
- La version PostgreSQL du chart (`postgres.version`) est égale ou supérieure à celle du rapport d'inspection.
- Secrets de chaque environnement posés (`docs/v1/infra/secrets.md`), **`PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` compris** ; un
  Secret `urbankiff-secrets` déployé avant eux se complète par `make secrets-cluster ENV=<env> VERSION=<version>`.
- Une version de l'application déployée dans l'environnement visé (le script lit la version de la release `urbankiff` et rend
  les Jobs avec les charts de cette version, qui doivent donc contenir les gabarits de restauration).
- Variables GitHub `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS`, `WASABI_BUCKET`, `WASABI_REGION` de l'environnement ; clé de déploiement
  chargée dans l'agent SSH ; identifiants Wasabi à portée (variables `WASABI_ACCESS_KEY_ID` et `WASABI_SECRET_ACCESS_KEY` du
  shell, ou saisie masquée).
- **Prod seulement** : chantier Firebase et connexion Google terminé. La répétition en preprod peut se faire avant.

## 1. Dépôt de la sauvegarde dans Wasabi

Action : depuis le poste, `make restauration-deposer ENV=<env> DUMP=<dump> FICHIERS=<dossier> DATE=<AAAA-MM-JJ>`
(`FICHIERS` facultatif). rclone (en conteneur) copie le dump vers `restauration/<date>/base.dump` et le dossier vers
`restauration/<date>/fichiers/` avec le chiffrement côté serveur. Les identifiants ne sont ni écrits dans le dépôt ni passés en
argument.

Contrôle : la commande se termine sans erreur après la comparaison de la taille du dump déposé avec celle du fichier local.

## 2. Restauration de la base et des fichiers

Action : `make restauration-lancer ENV=<env> PREFIXE=restauration/<date>/`, ou le workflow GitHub `Restauration`
(`environnement`, `prefixe`). En prod, il faut l'approbation de l'environnement GitHub `prod` (CI) ou la saisie du mot `prod`
(poste). Le message de fin est `restauration terminée : restauration/<date>/`.

Contrôle, dans le navigateur et sur l'environnement :
1. le front, le panel et les outils répondent : en preprod `https://preprod.db.urbankiff.com` (pgAdmin) et
   `https://preprod.stockage.urbankiff.com` (console RustFS) ; en prod, les hôtes de `docs/v1/infra/outils-donnees.md` ;
2. les décomptes exacts de chaque table du schéma `public` de la base `urbankiff-pg` (vus dans pgAdmin) sont égaux à ceux du
   rapport de `make sauvegarde-repeter` ;
3. le nombre d'objets du bucket RustFS correspond à la section Bucket du rapport d'inspection ;
4. les images du front sont servies depuis l'hôte de l'environnement ;
5. `restauration/<date>/` est toujours présent dans Wasabi (la sauvegarde n'est jamais supprimée).

En cas d'échec, l'application reste arrêtée : lire les journaux du Job conservé, corriger, relancer la même commande.

**Répétition en preprod** : avec une sauvegarde de la preprod, rejouer les étapes 1 et 2 avec `ENV=preprod` autant de fois que
nécessaire. La copie anonymisée de la prod (`make copie-prod-preprod`) ne se joue jamais en sens inverse : un préfixe
`-prod-anonyme/` est refusé en prod.

**Jeu en prod** : même geste avec **la sauvegarde de la prod** (`ENV=prod`, approbation `prod` ou mot `prod`).

## 3. Copie des fichiers dans RustFS

Le Job de l'étape 2 copie `fichiers/` dans RustFS (ajoute et remplace, ne supprime pas) s'il existe dans le préfixe, sans
échouer s'il est absent : cette étape n'a pas d'action propre. Contrôle : le décompte des objets du bucket (étape 2, point 3).
Pour copier de nouveau des fichiers, redéposer et relancer la restauration (étapes 1 et 2).

## 4. Mot de passe de l'administrateur `prodseed`

Le Job après restauration recrée l'administrateur `prodseed` avec le mot de passe `DJANGO_SUPERUSER_PASSWORD` du Secret.
Action, si un autre mot de passe est voulu : le changer par la commande Django prévue, exécutée dans un pod de l'api
(`kubectl -n <env> exec -it deploy/<api> -- python manage.py changepassword <identifiant>`), saisie interactive : ni argument ni
historique du shell.

Contrôle : connexion au panel avec le mot de passe attendu ; un autre est refusé.

## 5. DNS et contrôle TLS

Action : faire pointer `urbankiff.com`, `api.urbankiff.com`, `panel.urbankiff.com` et les hôtes des outils de la prod
(enregistrements créés par le développeur, liste dans `docs/v1/infra/outils-donnees.md`) vers A (enregistrements A).

Contrôle : les certificats sont émis par cert-manager (`kubectl -n prod get certificate` : `Ready`), le navigateur ne signale
aucune erreur TLS, et `https://api.urbankiff.com/api/health/` répond.

## 6. Retour arrière

- Étape 1 : supprimer `restauration/<date>/` de Wasabi à la main si on ne veut plus le rejouer ; le dump source reste sur le poste.
- Étape 2 : la restauration se rejoue (même commande) ; la remise à zéro du schéma `public` précède chaque `pg_restore`. Si la
  base doit être entièrement recréée : supprimer le cluster et son volume de l'environnement (confirmation du développeur),
  redéployer le chart (base vide), puis refaire l'étape 2. Rien ne dépend encore du DNS en prod.
- Étape 4 : définir un nouveau mot de passe.
- Étape 5 : remettre les enregistrements DNS d'origine (le TTL borne la durée du retour).

## 7. Rotation

Rappel : les secrets qui ont transité (identifiants Wasabi utilisés depuis le poste, mot de passe temporaire éventuel) sont à
renouveler selon `docs/v1/infra/rotation-secrets.md`.
