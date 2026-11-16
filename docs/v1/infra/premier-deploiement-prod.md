# Premier déploiement de la prod : restauration de la sauvegarde

Procédure écrite par la mission `k3s-ansible` (spec `docs/v1/specs/2026-11-16-k3s-ansible.md`, § 5.10 et § 5.11). **Rien de ce
qui est décrit ici n'est exécuté par la mission** : le développeur la déroule à la main, une fois le chantier Firebase et
connexion Google terminé. Chaque étape a une action et un contrôle ; ne passer à la suivante que si le contrôle est bon.

Valeurs du chart `urbankiff-donnees` utilisées (lot charts) : `restauration.active`, `restauration.prefixe` (relatif à la
racine du bucket Wasabi, par exemple `restauration/<date>/`), `restauration.fichierDump` (`base.dump`),
`restauration.copierFichiers` et `restauration.purger` (vrais par défaut). Le Job `urbankiff-restauration` lance
`pg_restore --no-owner --no-privileges --schema=public` sur le cluster CloudNativePG `urbankiff-pg` (identifiants dans le
Secret `urbankiff-pg-app`), copie `fichiers/` dans le bucket RustFS (nom lu dans la ConfigMap `urbankiff-config`,
clé `MINIO_DEFAULT_BUCKETS`), puis supprime le préfixe temporaire de Wasabi.

Format du dépôt dans Wasabi :

```
restauration/<date>/base.dump     # dump PostgreSQL au format custom
restauration/<date>/fichiers/     # contenu du bucket
```

## 0. Préalables

- Chantier Firebase et connexion Google terminé.
- Sur le poste du développeur, sur la sauvegarde du 2026-11-16 : `make sauvegarde-inspecter DUMP=<dump> BUCKET=<dossier>` puis
  `make sauvegarde-repeter DUMP=<dump>`. Contrôle : rapports lus et validés par le développeur, décision prise sur les URL
  `s3*` et `s30*` (réécriture ou validation), décomptes de la répétition égaux.
- La version PostgreSQL du chart (`postgres.version`) est égale ou supérieure à celle du rapport d'inspection.
- Secrets de l'environnement `prod` posés (`docs/v1/infra/secrets.md`). DNS non encore basculé.

## 1. Dépôt de la sauvegarde dans Wasabi

Action : depuis le poste, copier le dump vers `restauration/<date>/base.dump` et le dossier du bucket vers
`restauration/<date>/fichiers/` dans le bucket Wasabi de la prod, avec le chiffrement côté serveur, par l'outil choisi par le
développeur. L'identifiant d'accès n'est jamais écrit dans le dépôt ni passé en argument (variable d'environnement ou
saisie masquée).

Contrôle : la liste du préfixe montre `base.dump` et `fichiers/` ; la taille de `base.dump` égale celle du fichier local.

## 2. Restauration de la base et des fichiers

Action : déployer `urbankiff-donnees` dans `prod` avec `restauration.active=true` et
`restauration.prefixe=restauration/<date>/`. Suivre le Job : `kubectl -n prod logs job/urbankiff-restauration --all-containers`
(par le compte de déploiement ou l'accès administrateur du développeur).

Contrôle :
1. le Job est terminé avec succès (message `restauration terminée`) ;
2. les décomptes exacts de chaque table du schéma `public` de la base `urbankiff-pg` sont égaux à ceux du rapport de
   répétition (`make sauvegarde-repeter`) ;
3. le nombre d'objets du bucket RustFS correspond à la section Bucket du rapport d'inspection ;
4. le préfixe `restauration/<date>/` a disparu de Wasabi (le Job le supprime avec `restauration.purger=true` ; sinon le
   supprimer à la main).

Puis redéployer `urbankiff-donnees` avec `restauration.active=false` ; contrôle : le Job `urbankiff-restauration` n'existe plus.

## 3. Copie des fichiers dans RustFS

Le Job de l'étape 2 copie `fichiers/` dans RustFS (`restauration.copierFichiers=true`, valeur par défaut) avant de purger le
préfixe : cette étape n'a pas d'action propre. Contrôle (déjà listé à l'étape 2) : comparer le décompte des objets du bucket
RustFS à la section Bucket du rapport d'inspection. Si `copierFichiers` avait été mis à faux, refaire l'étape 2 complète sur
une base vide, le chart ne prévoyant pas de copie seule.

## 4. Mot de passe de l'administrateur `prodseed`

Action : changer le mot de passe de l'administrateur `prodseed` existant par la commande Django prévue, exécutée dans un pod
de l'api (`kubectl -n prod exec -it deploy/<api> -- python manage.py changepassword <identifiant>`), saisie interactive : ni
argument ni historique du shell.

Contrôle : connexion au panel avec le nouveau mot de passe ; l'ancien est refusé.

## 5. DNS et contrôle TLS

Action : faire pointer `urbankiff.com`, `api.urbankiff.com` et `panel.urbankiff.com` vers A (enregistrements A).

Contrôle : les trois certificats sont émis par cert-manager (`kubectl -n prod get certificate` : `Ready`), le navigateur ne
signale aucune erreur TLS, et `https://api.urbankiff.com/api/health/` répond.

## 6. Retour arrière

- Étape 1 : supprimer `restauration/<date>/` de Wasabi ; le dump source reste sur le poste.
- Étape 2 : la base est recréable : supprimer le cluster et son volume de `prod` (confirmation du développeur), redéployer
  le chart (base vide) et refaire l'étape 2. Rien ne dépend encore du DNS.
- Étape 4 : définir un nouveau mot de passe.
- Étape 5 : remettre les enregistrements DNS d'origine (le TTL borne la durée du retour).

## 7. Rotation

Rappel : les secrets qui ont transité (identifiant d'accès Wasabi utilisé depuis le poste, mot de passe temporaire éventuel)
sont à renouveler selon `docs/v1/infra/rotation-secrets.md`.
