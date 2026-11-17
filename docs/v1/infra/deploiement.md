# Déploiement par version

Spec : `docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 5.7 à 5.8, § 8.3 et 8.5). Ce document ne contient aucune valeur de
secret, d'hôte ni de clé : seulement des noms. Inventaire des secrets et variables : `docs/v1/infra/secrets.md`.

## Vue d'ensemble

Deux chemins mènent au même script serveur, `urbankiff-deploy`, installé par Ansible en
`/usr/local/bin/urbankiff-deploy` :

```
CI (release GitHub)          poste du développeur
  meta -> images, charts       make images-publier / charts-publier
        -> deployer                 make deploiement | secrets-cluster
              \                          /
               ssh deploy@<hôte> "deploy <version>"      (clé propre à l'environnement)
                         |
          commande forcée : urbankiff-deploy <env>       (SSH_ORIGINAL_COMMAND)
                         |
   charts OCI (GHCR) -> urbankiff-donnees -> attente CloudNativePG -> urbankiff (--atomic) -> /api/health/
```

Fichiers : script `infra/deploiement/urbankiff-deploy.sh`, scripts du poste `infra/deploiement/poste/`, cibles
`make/deploiement.mk` et `make/restauration.mk`, workflows `.github/workflows/deploiement.yml`, `restauration.yml` et `copie-prod-preprod.yml`, tests `infra/deploiement/tests/`.

## Commande forcée et commandes acceptées

Chaque clé du compte `deploy` est liée à un environnement dans `authorized_keys` :
`command="/usr/local/bin/urbankiff-deploy <env>",restrict <clé>`. Le script lit l'environnement dans son **premier
argument** (le client ne peut pas le choisir) et la commande dans `SSH_ORIGINAL_COMMAND`. Il ne lit rien d'autre de
l'environnement SSH : le compte est en `restrict`, sans transmission de variables ; seuls les tests surchargent
`URBANKIFF_CONFIG_DIR` et `URBANKIFF_LOCK_FILE`.

Commandes acceptées, motif strict (aucun `eval`, aucune valeur interpolée dans un shell) :

| Commande | Effet |
| --- | --- |
| `deploy <X.Y.Z>` ou `deploy v<X.Y.Z>` | déploie la version ; une pré-release `X.Y.Z-rc.N` est refusée en prod |
| `preprod-arret` | charges applicatives à zéro réplica, base en hibernation (preprod seulement) |
| `preprod-demarrage` | réveille la base puis remet les charges à l'échelle d'origine (preprod seulement) |
| `restaurer restauration/<AAAA-MM-JJ>/` ou `restaurer restauration/<AAAA-MM-JJ>-prod-anonyme/` | restaure la base (et les fichiers) depuis le dépôt Wasabi, prod et preprod ; le préfixe `-prod-anonyme/` est refusé en prod (code 2) |
| `exporter-anonyme <AAAA-MM-JJ>` | exporte la base de la prod anonymisée vers `restauration/<date>-prod-anonyme/` du bucket de la preprod (prod seulement, refusé en preprod avant tout appel) |

Tout le reste est refusé (code de sortie 2). Configuration serveur : `/etc/urbankiff/deploy.<env>.env`
(`URBANKIFF_ENV`, `GHCR_OWNER`, `NAMESPACE`, `API_SERVER_CIDR`, et `BUCKET_COPIE_PREPROD` dans `deploy.prod.env` seulement : nom du bucket Wasabi de la preprod, requis par `exporter-anonyme`, refusé comme clé inconnue dans `deploy.preprod.env`), kubeconfig `/home/deploy/.kube/<env>`. Un seul déploiement à la fois
(`flock` sur `/var/lock/urbankiff-deploy.lock`). `API_SERVER_CIDR` (IP du noeud k3s en `/32`, ex. `203.0.113.10/32`, sans secret) est
obligatoire, validée strictement (IPv4 en `/32`), écrite par le rôle ansible `deploiement` et passée au chart `urbankiff-donnees`
par `--set reseau.apiKubernetes.cidr=...` (pas au chart `urbankiff`).

Entrée standard facultative, au plus 64 Ko, lignes `NOM=valeur` : les noms de `scripts/secrets/secrets.txt` forment le
Secret `urbankiff-secrets`, ceux de `scripts/secrets/variables-<env>.txt` la ConfigMap `urbankiff-config` (tous
obligatoires, non vides). `WASABI_REGION` et `WASABI_BUCKET` sont de plus passés au chart `urbankiff-donnees` (`--set wasabi.region=…`), qui sauvegarde la base et les fichiers dans Wasabi.
Sans entrée, le script réutilise le Secret et la ConfigMap du namespace et refuse s'ils manquent (« premier
déploiement »). L'empreinte `secretsChecksum` (SHA-256 tronquée, secrets et variables) force le redémarrage des pods
quand une valeur change. Aucune valeur n'est jamais en argument, journalisée ni écrite sur disque.

Les secrets `PGADMIN_EMAIL` et `PGADMIN_MOT_DE_PASSE` (pgAdmin, lot 6, `docs/v1/infra/secrets.md`) font partie de `SECRET_KEYS` : une entrée qui les omet est refusée. Un Secret `urbankiff-secrets` déployé avant eux ne les contient pas : `restaurer` répond « Secret incomplet : relancer make secrets-cluster » ; le compléter par `make secrets-cluster` avant la première restauration.

## CI et poste

| Étape | CI (`deploiement.yml`) | Poste du développeur |
| --- | --- | --- |
| Déclencheur | pré-release `vX.Y.Z-rc.N` vers `preprod` ; release `vX.Y.Z` vers `prod` (environnement GitHub `prod`, approbation) | `make deploiement ENV=<prod\|preprod> VERSION=<version>` |
| Images | `make images-publier` (api construite une fois en preprod, réétiquetée en prod) | `make images-publier VERSION=<v> ENV=<env>` |
| Charts | `make charts-publier` | `make charts-publier VERSION=<v>` |
| Secrets | envoyés sur l'entrée standard de SSH depuis l'environnement GitHub | non transmis, sauf `make secrets-cluster` |
| Appel | `ssh deploy@$DEPLOY_HOST "deploy <version>"` | idem, avec la clé de déploiement du poste |

Images : `ghcr.io/tigamadou/urbankiff-{api,nextjs,panel}` ; étiquettes `sha-<12>` et `<version>` (api), `<version>-<env>`
(Next, panel) ; `linux/amd64`. En prod, l'image api du commit (`sha-<12>`, publiée par la pré-release) est réétiquetée
`<version>` (même digest) ; sans elle, rien n'est publié. Next et panel sont construits par environnement avec les
variables GitHub de l'environnement (`NEXT_PUBLIC_BACKEND_URL`, `NEXT_PUBLIC_BACKEND_URL_FRONT`,
`NEXT_PUBLIC_GOOGLE_CLIENT_ID`, `BACKEND_URL`, `REACT_APP_BACKEND_URL`, `REACT_APP_IMAGEKIT_ENDPOINT`) ; une variable
absente fait échouer la cible avant toute construction.

Charts : `oci://ghcr.io/tigamadou/charts/{urbankiff-donnees,urbankiff}`, publiés à la version du tag.

Dans le workflow, `images` et `deployer` référencent l'environnement GitHub : pour `prod`, l'approbation est donc
demandée deux fois (construction, puis déploiement).

## Premier déploiement d'un environnement

Pas de Secret `urbankiff-secrets` tant qu'aucun déploiement n'a eu lieu. Deux voies :

1. **Par la CI** : poser les secrets et variables de l'environnement (`make secrets-definir`, `docs/v1/infra/secrets.md`)
   puis publier une pré-release (preprod). Le workflow envoie secrets et variables.
2. **Par le poste** : `make secrets-cluster ENV=<env> VERSION=<version>` demande chaque secret de
   `scripts/secrets/secrets.txt` en saisie masquée (vide = omis), lit les variables avec `gh variable list`, puis envoie
   le tout sur l'entrée standard de SSH. Rien n'est écrit sur disque ni passé en argument. Un secret aléatoire déjà
   posé dans GitHub n'est pas relisible : en saisir une valeur neuve.

Pour que `secrets-cluster` aboutisse, toutes les clés doivent être fournies, `WASABI_REGION` et `WASABI_BUCKET`
comprises.

## Déploiement courant

1. Publier les images et les charts : par la CI (créer la pré-release ou la release GitHub), ou
   `make images-publier VERSION=<v> ENV=<env>` puis `make charts-publier VERSION=<v>`.
2. Déployer : la CI le fait ; sinon `make deploiement ENV=<env> VERSION=<v>` (Secrets existants réutilisés).

Le script tire les deux charts, déploie `urbankiff-donnees` **sans** `--atomic` mais avec `--wait`, attend que le
`Cluster` CloudNativePG `urbankiff-pg` soit prêt, puis déploie `urbankiff` avec `--atomic --wait --timeout 10m`, et
contrôle `https://<hôte de l'Ingress urbankiff-api>/api/health/` pendant deux minutes au plus.

## Rollback

- `--atomic` annule seul une mise à jour de l'application qui n'atteint pas l'état prêt.
- Le Secret `urbankiff-secrets` et le ConfigMap `urbankiff-config` sont appliqués avant `helm --atomic` : si la mise à jour
  échoue et est annulée, ils gardent leurs nouvelles valeurs (Helm ne les gère pas). Les corriger en redéployant la
  version précédente avec les valeurs précédentes.
- Version défaillante constatée après coup : redéployer la version précédente (`make deploiement ENV=<env> VERSION=<précédente>`,
  ou publier de nouveau sa release).
- Sur le serveur, `helm rollback urbankiff -n <namespace>` est possible, mais le script de déploiement reste la voie
  normale.
- **Règle des migrations N-1** : toute migration doit rester compatible avec la version précédente de l'application ;
  un rollback ne les annule jamais. Une migration incompatible se livre en deux versions.

## Preprod à la demande

`make preprod-arret` met à zéro les Deployments et StatefulSets portant `app.kubernetes.io/part-of=urbankiff`
(réplicas notés dans l'annotation `urbankiff.com/replicas-avant`) puis hiberne le `Cluster` (`cnpg.io/hibernation=on`).
`make preprod-demarrage` réveille la base, attend qu'elle soit prête et remet les charges à l'échelle d'origine.
Les deux sont idempotents ; aucun PVC ni Secret n'est supprimé.

## Restauration

`restaurer <prefixe>` est le seul chemin de restauration, en prod comme en preprod (il n'y a aucune restauration par
`helm upgrade`). Il lit les Secrets déjà présents dans le namespace (aucune entrée standard) et déroule six étapes, chacune
vérifiée avant la suivante :

1. **Contrôle** : `<prefixe>base.dump` existe dans le bucket Wasabi (requête signée par `curl`, identifiants lus sur
   l'entrée standard de `curl`, jamais en argument) et le `Cluster` CloudNativePG `urbankiff-pg` est prêt. Sinon,
   « préfixe introuvable dans le bucket … » : **rien n'est arrêté**.
2. **Arrêt** : version déployée lue dans la release `urbankiff` (`image.etiquette`), charts de cette version tirés, puis
   Deployments `app.kubernetes.io/part-of=urbankiff` mis à zéro (réplicas notés dans `urbankiff.com/replicas-avant`).
3. **Job `urbankiff-restauration`** (chart `urbankiff-donnees`, seul `restauration.prefixe` est passé) ; le script exige le
   journal `restauration terminée`.
4. **Job `urbankiff-apres-restauration`** (chart `urbankiff`, `apresRestauration.actif=true` : migrations, recréation de
   l'administrateur par `prodseed`) ; seul l'état `succeeded` du Job est exigé.
5. **Remise en service** : réplicas d'avant rétablis, annotation retirée, attente de la disponibilité des Deployments.
6. **Santé** : `/api/health/` puis `restauration terminée : <prefixe>`.

Les Jobs sont rendus à la demande par `helm template --show-only` avec les valeurs de la release en place, créés, suivis
(6 minutes sur 5 secondes de pas, `URBANKIFF_JOB_TENTATIVES` en test) et supprimés en cas de succès. Un Job en échec est
**conservé** pour l'enquête (`kubectl logs job/<nom> -n <namespace>`). La sauvegarde n'est jamais supprimée de Wasabi.

**En cas d'échec aux étapes 3 ou 4, l'application reste arrêtée** (la base peut être à moitié restaurée) : le message
« l'application reste arrêtée » le dit. Marche à suivre : lire les journaux du Job conservé, corriger la cause, puis
**relancer la même commande** ; elle supprime le Job homonyme, rejoue la restauration et reprend les réplicas d'avant (une
charge déjà à zéro garde son annotation). La restauration est rejouable autant de fois que nécessaire.

## Copie prod vers preprod anonymisée

`exporter-anonyme <date>` (prod seulement) rend le Job `urbankiff-export-anonyme` (chart `urbankiff`, avec
`exportAnonyme.prefixe=restauration/<date>-prod-anonyme/`, `exportAnonyme.bucketCible=<BUCKET_COPIE_PREPROD>`,
`environnement=prod`, `wasabi.region`, `wasabi.endpoint`), l'exécute et exige le journal `export terminé`. **L'application de
la prod n'est pas arrêtée.** La copie complète enchaîne cet export (prod) puis `restaurer restauration/<date>-prod-anonyme/`
(preprod), et s'arrête au premier échec.

## Restauration et copie : CI et poste

| Geste | CI | Poste du développeur |
| --- | --- | --- |
| Déposer une sauvegarde dans Wasabi | sans objet | `make restauration-deposer ENV=<env> DUMP=<fichier> [FICHIERS=<dossier>] DATE=<AAAA-MM-JJ>` (rclone en conteneur ; identifiants Wasabi dans l'environnement du shell ou saisie masquée ; contrôle de la taille du dump) |
| Restaurer | workflow manuel `Restauration` (`restauration.yml`, entrées `environnement` et `prefixe` ; `prod` demande l'approbation de l'environnement GitHub) | `make restauration-lancer ENV=<env> PREFIXE=restauration/<date>[-prod-anonyme]/` ; en prod, saisie du mot `prod` |
| Copie anonymisée | workflow manuel `Copie prod vers preprod` (`copie-prod-preprod.yml` : export sous l'environnement `prod`, puis restauration sous `preprod`) | `make copie-prod-preprod [DATE=<AAAA-MM-JJ>]` ; saisie du mot `prod` |

Les deux workflows n'utilisent que `secrets.DEPLOY_SSH_KEY` (aucun secret applicatif), valident leurs entrées avant `ssh`
et n'envoient aucune entrée standard.

## Secrets et variables requis par environnement

Dans l'environnement GitHub `prod` et `preprod` : les secrets de `scripts/secrets/secrets.txt` et les variables de
`scripts/secrets/variables-<env>.txt` (posés par `make secrets-definir`), plus `DEPLOY_SSH_KEY` (secret),
`DEPLOY_HOST` et `DEPLOY_KNOWN_HOSTS` (variables), décrits dans `docs/v1/infra/secrets.md`. `POSTGRES_PASSWORD` n'en
fait pas partie : il est généré par CloudNativePG.

## Prérequis posés par le développeur à la mise en service

- `DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS` dans chaque environnement GitHub ; une clé par environnement,
  enregistrée dans `authorized_keys` avec son environnement (voir plus haut).
- Environnement GitHub `prod` avec approbation obligatoire du développeur.
- Paquets GHCR `urbankiff-api`, `urbankiff-nextjs`, `urbankiff-panel`, `charts/urbankiff` et `charts/urbankiff-donnees`
  rendus **publics** (Settings du paquet, Danger Zone) : le cluster ne porte aucun Secret de tirage (arbitrage A1). Le
  premier push crée des paquets privés.
- Poste : agent SSH chargé avec la clé de déploiement, fichier de la clé publique à `~/.ssh/urbankiff-deploy-<env>.pub`
  (ou `DEPLOY_IDENTITE=<chemin>`) car la connexion utilise `IdentitiesOnly=yes` ; `gh` authentifié avec accès en lecture
  aux variables d'environnement et `read:packages`/`write:packages` pour GHCR.

## Dépannage

| Symptôme | Cause probable |
| --- | --- |
| `un déploiement est déjà en cours` | un autre déploiement tient le verrou ; attendre sa fin |
| `commande refusée` | commande hors liste, pré-release en prod, `preprod-*` ou préfixe `-prod-anonyme/` en prod, `exporter-anonyme` en preprod |
| `chart introuvable` | charts non publiés pour cette version : `make charts-publier` |
| `premier déploiement : fournir les Secrets` | Secret ou ConfigMap absent : voir « Premier déploiement » |
| `clé obligatoire absente ou vide : <NOM>` | secret ou variable manquant dans l'entrée (ou `WASABI_*` vides) |
| `variable de construction absente de l'environnement` | variable GitHub manquante pour construire Next ou panel |
| `image … sha-<12> absente` | publier d'abord la pré-release du même commit |
| `CloudNativePG n'est pas prêt` | voir `kubectl get cluster -n <namespace>` ; l'application n'est pas déployée |
| ssh refuse l'hôte | `DEPLOY_KNOWN_HOSTS` ne correspond pas à l'hôte |
| `préfixe introuvable dans le bucket` | la sauvegarde n'est pas déposée sous ce préfixe : `make restauration-deposer`, ou vérifier la date ; rien n'a été arrêté |
| `le Job <nom> a échoué` ou `… n'est pas terminé après le délai` | journaux affichés ; Job conservé (`kubectl logs job/<nom> -n <namespace>`), corriger puis relancer la même commande |
| `l'application reste arrêtée` | échec en cours de restauration : voir « Restauration », relancer la même commande |
| `Secret incomplet : relancer make secrets-cluster` | le Secret déployé n'a pas `PGADMIN_*` |
| `configuration : BUCKET_COPIE_PREPROD absent` | `deploy.prod.env` sans le bucket de la preprod (rôle Ansible `deploy`) |

## Cibles make et tests

| Cible | Rôle |
| --- | --- |
| `images-publier`, `charts-publier` | publication GHCR |
| `deploiement`, `secrets-cluster` | déploiement sans / avec Secrets |
| `preprod-arret`, `preprod-demarrage` | preprod à la demande |
| `restauration-deposer`, `restauration-lancer` | dépôt Wasabi et restauration depuis le poste |
| `copie-prod-preprod` | export anonymisé de la prod puis restauration de la preprod |
| `deploiement-test` | tests bats en conteneur (`alpine:3.20`) avec de faux `kubectl`, `helm`, `curl`, `flock`, `sleep`, `docker`, `gh`, `ssh` |
| `deploiement-lint` | shellcheck `koalaman/shellcheck:v0.10.0` |
| `workflow-lint` | actionlint `rhysd/actionlint:1.7.4` ; la publication des charts utilise `alpine/helm:3.16.3` |

Les versions d'images sont des variables en tête de `make/deploiement.mk`. Le premier déploiement de `prod` est hors de
la mission et n'est exercé par aucun test.
