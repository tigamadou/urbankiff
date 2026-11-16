# Charts Helm d'Urbankiff

Deux charts : `urbankiff-donnees` (état : PostgreSQL CloudNativePG, Redis, RustFS, sauvegardes) et `urbankiff`
(applications). Documentation : `docs/v1/infra/kubernetes.md`. Cibles : `make helm-lint`, `helm-test`,
`helm-rendu ENV=…`, `helm-valider ENV=…`, `helm-paquet VERSION=…`, `helm-controle`.

## Schémas de validation (`schemas/`)

Schémas JSON des CRD `Cluster` et `ScheduledBackup` (`postgresql.cnpg.io`), `ObjectStore` (`barmancloud.cnpg.io`) et
`Certificate` (`cert-manager.io`), pris dans le catalogue public `datreeio/CRDs-catalog` (branche `main`, état du
2026-11-16) et **versionnés ici** : la validation ne télécharge rien. Versions visées : CloudNativePG 1.25, plugin
Barman Cloud 0.x, cert-manager 1.16 ; le catalogue n'est pas figé par version, vérifier les champs contre les CRD du
rôle `plateforme` d'Ansible lors d'une montée de version.

Régénération (seul chemin avec accès réseau) : `make helm-schemas`.
