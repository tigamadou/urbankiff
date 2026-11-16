# Charts Helm et déploiement sur k3s

Source : spec `docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 5.3, 5.4, 8.3, 8.5) et plan `docs/v1/plans/k3s-ansible/6-charts.md`.
Ce document ne contient **jamais de valeur de secret**, seulement des noms. Les charts sont dans `infra/helm/` ; rien
n'y est déployé par ce lot.

## Rôle des charts

| Chart | Namespace | Contenu |
| --- | --- | --- |
| `urbankiff-donnees` | `prod`, `preprod` | `Cluster` CloudNativePG `urbankiff-pg` (PostgreSQL, une instance), `ObjectStore` Barman Cloud vers Wasabi, `ScheduledBackup` quotidien, Redis (StatefulSet, mot de passe, AOF), RustFS (StatefulSet), Job de création du bucket, CronJob rclone de copie des fichiers, Job de restauration (sur demande), NetworkPolicies du refus par défaut et des données |
| `urbankiff` | `prod`, `preprod` | api, workers, Next, panel, Job de migrations (crochet), Ingress, NetworkPolicies des applications |

Aucun des deux charts ne crée de namespace, de `ResourceQuota` ni de `LimitRange` (rôle `plateforme` d'Ansible, spec
§ 8.5 A9), ni de Secret : tout Secret est créé avant eux par le script de déploiement.

### Ordre de déploiement

1. Secret `urbankiff-secrets` et ConfigMap `urbankiff-config` (script de déploiement, spec § 8.5 A5).
2. `urbankiff-donnees` (sans `--atomic`, volumes) : refus par défaut, PostgreSQL, Redis, RustFS, sauvegardes.
3. `urbankiff` (avec `--atomic --wait`) : le Job de migrations (crochet `pre-install,pre-upgrade`) attend que le Secret
   `urbankiff-pg-app`, généré par CloudNativePG, existe : il est rejoué (`backoffLimit: 6`) tant que la base ne répond pas.

Le Job de migrations court avant les ressources du chart `urbankiff` (crochet `pre-install`) : ses NetworkPolicies
(entrée de PostgreSQL, Redis, RustFS depuis `migrations`, et `migrations-sortie`) vivent donc dans le chart
`urbankiff-donnees`, déployé avant. Le Secret `urbankiff-secrets` et la ConfigMap `urbankiff-config` doivent exister
avant les deux charts.

## Contrats

- Valeurs : `environnement` (`prod` ou `preprod`, sinon le rendu échoue), `image.etiquette` (version de la release,
  obligatoire), `secretsChecksum` (empreinte des secrets), `sms.actif`, `restauration.active`, `restauration.prefixe`,
  `wasabi.region` et `wasabi.bucket` (obligatoires, passées par `--set` par le script de déploiement, spec § 8.5 A5),
  `image.secretTirage` (facultatif, vide par défaut : paquets GHCR publics, A1), `hosts.{web,api,panel}`.
- Images : api `ghcr.io/tigamadou/urbankiff-api:<version>` ; Next et panel `…-nextjs:<version>-<environnement>` et
  `…-panel:<version>-<environnement>`.
- Services : `urbankiff-api:8000`, `urbankiff-nextjs:3000`, `urbankiff-panel:8080`, `urbankiff-redis:6379`,
  `urbankiff-rustfs:9000`, `urbankiff-pg-rw:5432`.
- Fichiers de valeurs : `values.yaml` (commun), `values-prod.yaml`, `values-preprod.yaml` dans chaque chart.

## Libellés

Tous les pods portent `app.kubernetes.io/part-of: urbankiff` (le script de déploiement s'en sert pour mettre à zéro les
Deployments et StatefulSets de la preprod, A2) et `app.kubernetes.io/component`.

| `component` | Pod |
| --- | --- |
| `api`, `workers`, `nextjs`, `panel` | Deployments applicatifs |
| `migrations` | Job de migrations |
| `redis`, `rustfs` | StatefulSets |
| `postgres` | pods du `Cluster` (libellés posés par `inheritedMetadata`, plus `cnpg.io/cluster: urbankiff-pg` posé par l'opérateur) |
| `rustfs-bucket` | Job de création du bucket |
| `sauvegarde-fichiers` | CronJob rclone |
| `restauration` | Job de restauration |

Les NetworkPolicies ne s'appuient que sur ces libellés (`podSelector`, même namespace). Les seules `namespaceSelector`
visent `kube-system` (Traefik, CoreDNS) et le namespace de la plateforme (`reseau.namespacePlateforme`, défaut
`plateforme`, opérateur CloudNativePG).

## NetworkPolicies

Principe : refus par défaut en entrée et en sortie dans le namespace, puis ouvertures explicites. La sortie Internet est
**par port, pas par nom** : le contrôleur de NetworkPolicy de k3s ne filtre pas par nom de domaine. Toute règle
`ipBlock` d'Internet exclut `reseau.cidrExclus` (plages des pods `10.42.0.0/16` et des services `10.43.0.0/16` de k3s,
et plages privées) : aucun flux n'est donc possible entre `prod` et `preprod`, ni par un sélecteur de namespace ni par
une adresse IP. Le DNS passe par une règle commune vers CoreDNS de `kube-system`, y compris pour les pods sans autre
sortie.

| Politique | Chart | Pods visés | Source → destination | Ports |
| --- | --- | --- | --- | --- |
| `default-deny` | donnees | tous | tout refusé (entrée et sortie) | — |
| `autoriser-dns` | donnees | tous | → CoreDNS (`kube-system`) | 53 UDP et TCP |
| `postgres-entree` | donnees | PostgreSQL | api, workers, migrations, restauration → PostgreSQL ; opérateur (`plateforme`) → PostgreSQL | 5432 ; 5432 et 8000 |
| `redis-entree` | donnees | Redis | api, workers, migrations → Redis | 6379 |
| `rustfs-entree` | donnees | RustFS | api, workers, migrations, rustfs-bucket, sauvegarde-fichiers, restauration → RustFS | 9000 |
| `postgres-sortie` | donnees | PostgreSQL | → Wasabi (Internet hors `cidrExclus`) ; → API Kubernetes (hors plages pod et service) | 443 ; 6443 |
| `rustfs-bucket-sortie` | donnees | rustfs-bucket | → RustFS | 9000 |
| `sauvegarde-fichiers-sortie` | donnees | sauvegarde-fichiers | → RustFS ; → Wasabi | 9000 ; 443 |
| `restauration-sortie` | donnees | restauration | → PostgreSQL ; → RustFS ; → Wasabi | 5432 ; 9000 ; 443 |
| `migrations-sortie` | donnees | migrations | → PostgreSQL ; → Redis ; → RustFS ; → Internet hors `cidrExclus` | 5432 ; 6379 ; 9000 ; 443, 465, 587 |
| `api-entree` | urbankiff | api | Traefik (`kube-system`), Next → api | 8000 |
| `nextjs-entree` | urbankiff | Next | Traefik → Next | 3000 |
| `panel-entree` | urbankiff | panel | Traefik → panel | 8080 |
| `solveur-http01-entree` | urbankiff | solveurs HTTP-01 de cert-manager (`acme.cert-manager.io/http01-solver`) | Traefik → solveur | 8089 |
| `applications-sortie` | urbankiff | api, workers | → PostgreSQL ; → Redis ; → RustFS ; → Internet hors `cidrExclus` | 5432 ; 6379 ; 9000 ; 443, 465, 587 |
| `nextjs-sortie` | urbankiff | Next | → api | 8000 |

Le panel (statique) n'a aucune sortie, les workers aucune entrée. Les tests de rendu énumèrent ces politiques : en
ajouter ou en retirer une fait échouer `make helm-test`.

Points à connaître :

- Next n'a **aucune** sortie Internet (spec § 5.3). Or le code lit `NEXT_PUBLIC_BACKEND_URL || BACKEND_URL`, valeurs
  figées à la construction et égales à l'URL publique de l'api : si le rendu serveur appelle cette URL publique, la sortie
  est refusée. À vérifier au premier déploiement ; la solution (sortie 443 pour Next, ou URL interne à la construction)
  relève du lot `fronts-prod` ou d'une décision du développeur.
- L'API Kubernetes est jointe sur le port 6443 de l'hôte (`reseau.apiKubernetes`, adresse `0.0.0.0/0` hors plages pod
  et service par défaut). Pour la restreindre, passer `reseau.apiKubernetes.cidr=<IP du nœud>/32`.
- L'entrée de l'opérateur CloudNativePG vise tout le namespace `plateforme` (pas de `podSelector`) ; restreindre aux pods
  de l'opérateur est possible une fois leur libellé confirmé.

## Ressources et quota

Limites mémoire des valeurs `values-<env>.yaml` (spec § 5.4), requêtes / limites :

| Composant | Prod | Preprod |
| --- | --- | --- |
| api | 300 / 512 Mi | 200 / 384 Mi |
| workers | 200 / 384 Mi | 128 / 256 Mi |
| Next | 256 / 512 Mi | 192 / 384 Mi |
| panel | 32 / 64 Mi | 32 / 64 Mi |
| PostgreSQL | 384 / 768 Mi | 192 / 384 Mi |
| Redis | 32 / 128 Mi | 32 / 64 Mi |
| RustFS | 128 / 256 Mi | 64 / 192 Mi |
| Job de migrations | 200 / 512 Mi | 128 / 256 Mi |
| Jobs et CronJob rclone | 32 / 128 Mi | 32 / 128 Mi |

Quota de la preprod : **2 Gio** de limites mémoire et 1,5 Gio de requêtes, créé par le rôle `plateforme` d'Ansible
(A9). La somme des limites de la preprod en régime établi est de **1 728 Mi** (celle du tableau de la spec, qui dépasse
1,5 Gio) ; le Job de migrations (256 Mi, la limite la plus basse que le chart retient pour qu'il tienne) s'y ajoute, soit
1 984 Mi. Le contrôle transverse de `make helm-test` échoue si cette somme dépasse 2 048 Mi.

## Durcissement

Tous les pods rendus (Deployments, StatefulSets, Jobs, CronJobs, init-conteneurs compris) : `runAsNonRoot`, UID
explicite non nul (10001), `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`,
`capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true` avec des `emptyDir` sur `/tmp` (et `/app/.next/cache` pour
Next), `requests` et `limits` mémoire sur chaque conteneur, `automountServiceAccountToken: false`, sondes `readiness`
et `liveness` sur les Deployments et StatefulSets. Les workers n'ont pas de port : leurs sondes vérifient seulement que
le processus (PID 1) existe. Les sondes de l'api envoient l'en-tête `Host` du nom public de l'api (sinon Django refuse
l'IP du pod) avec `timeoutSeconds: 3` (A13).

**Limites imposées par CloudNativePG** : les pods PostgreSQL sont créés par l'opérateur, pas par un gabarit du chart. Le
chart règle ce que la spec du `Cluster` permet (`securityContext`, `podSecurityContext`, `seccompProfile`, UID 26,
`resources`), et le test vérifie ces champs. Le jeton de compte de service reste monté (l'instance parle à l'API
Kubernetes), le conteneur auxiliaire du plugin Barman Cloud et les sondes sont réglés par l'opérateur et le plugin :
leurs limites mémoire ne sont pas ceux de `postgres.ressources` et ne sont pas comptés par le test de quota.

## Variables et Secrets consommés

Secret `urbankiff-secrets` (clés de `scripts/secrets/secrets.txt`) et ConfigMap `urbankiff-config` (variables de
`variables-<env>.txt`) sont injectés en bloc (`envFrom`) dans l'api, les workers et les migrations. Les variables
suivantes sont posées par le chart et l'emportent sur `envFrom` :

| Variable | Origine |
| --- | --- |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_HOST` | Secret `urbankiff-pg-app` (généré par CloudNativePG : `username`, `password`, `dbname`, `host`), A3 ; base et propriétaire `urbankiff` |
| `REDIS_PASSWORD` | clé `REDIS_PASSWORD` de `urbankiff-secrets` |
| `REDIS_ENDPOINT` | construite : `redis://:$(REDIS_PASSWORD)@urbankiff-redis:6379/0` (déclarée après `REDIS_PASSWORD`) |
| `MINIO_ENDPOINT` | construite : `urbankiff-rustfs:9000` (A4) |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | `sms.actif: true` : clés du Secret ; sinon valeur inerte `desactive` (A6) |

Autres lectures de `urbankiff-secrets` : `MINIO_ROOT_USER` et `MINIO_ROOT_PASSWORD` (RustFS, rclone), `REDIS_PASSWORD`
(Redis), `WASABI_ACCESS_KEY_ID` et `WASABI_SECRET_ACCESS_KEY` (Barman Cloud, rclone). De `urbankiff-config` :
`MINIO_DEFAULT_BUCKETS` (nom du bucket, Job de création et copies rclone). `POSTGRES_PASSWORD` n'est **pas** lu dans
`urbankiff-secrets` (A3).

`sms.actif: false` (preprod) ne neutralise que la variable d'environnement : le code de l'api n'est pas modifié.

## Hibernation de la preprod

Le chart ne pose jamais l'annotation `cnpg.io/hibernation` (un `helm upgrade` ne doit pas défaire l'état d'hibernation) ;
elle n'est rendue que si `postgres.hibernation` est fourni explicitement (`"on"` ou `"off"`). C'est le script de
déploiement qui la bascule sur le `Cluster` `urbankiff-pg` (`make preprod-arret`, `make preprod-demarrage`) et met à zéro
les Deployments et StatefulSets portant `app.kubernetes.io/part-of: urbankiff`. Effet : l'instance PostgreSQL s'arrête,
volumes et Secrets sont conservés.

## PostgreSQL, version et restauration

- `postgres.version` (défaut 15, entier) : image `ghcr.io/cloudnative-pg/postgresql:<version>`. Règle (spec § 5.11) :
  alignée ou supérieure à la version du dump à restaurer, jamais inférieure ; le rendu refuse une valeur sous 15.
- **Restauration à un instant précis** (valeur `postgres.restauration`, jamais active par défaut) :

  ```yaml
  postgres:
    serveur: urbankiff-pg-restauree        # nouveau nom d'archive, différent de la source
    restauration:
      actif: true
      instant: "2026-12-01 10:00:00+00"
      serveurSource: urbankiff-pg          # nom d'archive d'origine dans Wasabi
  ```

  Le `Cluster` passe de `bootstrap.initdb` à `bootstrap.recovery` (`targetTime`, source `externalClusters` par le plugin
  Barman Cloud). `serveurSource` doit différer de `serveur` : sinon la nouvelle archive se mélange à l'ancienne. À
  utiliser sur un namespace dont le `Cluster` a été supprimé.
- **Job de restauration d'une sauvegarde déposée** (`restauration.active: true`, § 5.10) : le Job `urbankiff-restauration`
  est absent par défaut. Valeurs : `restauration.prefixe` (obligatoire, relatif à la racine du bucket, par exemple
  `restauration/2026-12-01/`), `restauration.fichierDump` (défaut `base.dump`), `restauration.copierFichiers` (défaut vrai),
  `restauration.purger` (défaut vrai). Trois temps : init-conteneur rclone (récupère le préfixe de Wasabi), init-conteneur
  `pg_restore --no-owner --no-privileges --schema=public --dbname=…` (image PostgreSQL de `postgres.version`, mot de passe
  du Secret `urbankiff-pg-app`), conteneur rclone (copie `fichiers/` vers RustFS, puis supprime le préfixe de Wasabi). Le Job
  n'est pas un crochet et ne se rejoue pas : le supprimer avant de relancer. Format (A10) : `<préfixe>/base.dump` (format
  custom de `pg_dump`) et `<préfixe>/fichiers/`.

## Utilisation de `make helm-*`

Toutes les cibles lancent des conteneurs aux versions épinglées (`make/helm.mk`) ; le dépôt est monté en lecture seule.

| Cible | Effet |
| --- | --- |
| `make helm-lint` | `helm lint --strict` des deux charts avec les valeurs `prod` et `preprod` |
| `make helm-rendu ENV=<prod\|preprod> [CHART=…]` | rend les charts (sortie standard) |
| `make helm-valider ENV=<prod\|preprod>` | rendu puis kubeconform strict (schémas locaux de `infra/helm/schemas/`, aucun schéma manquant toléré) |
| `make helm-unittest [CHART=…]` | tests helm-unittest seuls |
| `make helm-test` | helm-unittest puis contrôles transverses (`infra/helm/tests-transverses/controle.rb`, sur les quatre rendus) |
| `make helm-garde` | test d'outillage : les cibles échouent proprement sans chart ou sans `ENV` |
| `make helm-controle` | lint, tests, garde et validation des deux environnements |
| `make helm-paquet VERSION=x.y.z` | `helm package` dans `.superpowers/helm-paquets/` (publication OCI : lot `deploiement`) |
| `make helm-schemas` | régénère les schémas (seule cible avec accès réseau) |

Les cibles de rendu passent des valeurs de test (`ETIQUETTE`, `WASABI_REGION`, `WASABI_BUCKET`, sans secret) ; les
valeurs réelles viennent du script de déploiement.

## Points laissés aux lots voisins

- **ClusterIssuer** : l'annotation `cert-manager.io/cluster-issuer` vaut `ingress.clusterIssuer` (défaut `letsencrypt`, A7) ;
  le rôle `plateforme` d'Ansible doit créer l'émetteur de ce nom.
- **Variables Wasabi** : `wasabi.region` et `wasabi.bucket` n'ont pas de valeur dans le dépôt (vides dans
  `variables-<env>.txt`, à fournir par le développeur) ; le script de déploiement les passe en `--set` (A5).
- **Nom du fichier de dump** : `base.dump` et `fichiers/` sous `restauration/<date>/` (A10) à garder alignés avec
  `infra/restauration/` et `docs/v1/infra/premier-deploiement-prod.md`.
- **Secret `urbankiff-pg-app`** : le script de déploiement ne crée pas de Secret pour PostgreSQL ; `POSTGRES_PASSWORD` est
  retiré de `secrets.txt` (A3).
- **Secrets du chart des données** : `urbankiff-secrets` et `urbankiff-config` doivent exister avant `urbankiff-donnees`.
- **Schémas CRD** : issus du catalogue public (voir `infra/helm/README.md`), à comparer aux CRD des versions épinglées par
  le rôle `plateforme`.
