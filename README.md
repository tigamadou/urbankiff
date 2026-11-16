# ubnews

## Structure (monorepo)

Toutes les applications sont versionnées dans ce dépôt, avec leur historique :

| Dossier | Application | Ancien dépôt |
| --- | --- | --- |
| `apps/api` | API Django | `urbankiff-api` |
| `apps/nextjs` | Front public Next.js | `urbankiff-nextjs` |
| `apps/panel` | Panel d'administration | `urbankiff-panel` |
| `apps/minio` | Configuration de déploiement S3 | `urbankiff-minio` |
| `apps/backup_service` | Sauvegardes | — |

`apps/mobile` (Expo) reste un dépôt séparé (`urbankiff-mobile`), ignoré ici et cloné par `make init`.

Les fichiers `.env` locaux des applications ne sont pas versionnés. Spec du passage en monorepo :
`docs/v1/specs/2026-11-15-monorepo-devteam.md`.

### Releases et déploiements

Les workflows de `.github/workflows/` sont préfixés par l'application (`api-deploy-to-prod.yml`…). Une release ne
déploie que l'application de son tag : `<app>/vX.Y.Z` (par exemple `api/v1.5.0`), pré-release pour la preprod,
release publiée pour la prod. `minio` se déploie sur push vers `main` (prod) ou `staging` (preprod) quand
`apps/minio/**` change.

### Passer un poste existant au monorepo

1. Sauvegarder les `.env` locaux de `apps/*` (non versionnés).
2. Recloner ce dépôt (ou déplacer les anciens `apps/<app>` hors du dépôt), puis restaurer les `.env`.
3. `make start`.

> ### Step to launch this projects

```shell
# Run
make init
```

### Launch for the first time with build

```
# Run
make start-b
```

### Seed with fake data

```
# Run
make seed
```

### Connect to S3 and upload dummy files
Open the s3 server here [s3.urbankiff.local](http://s3.urbankiff.local).

login with the following access

```
username: urbankiff
password: urbankiff_pass
```

Access the ``defaultbucket``

Upload all the files in the folder ``dummy_data``


### Open the apps
[urbankiff.local](http://urbankiff.local)

[api.urbankiff.local](http://api.urbankiff.local)

[panel.urbankiff.local](http://panel.urbankiff.local)