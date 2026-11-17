# Mission `outils-donnees` — tableau de bord

Preprod iso, restauration rejouable, outils web des données. Spec :
`docs/v1/specs/2026-11-17-preprod-iso-outils-donnees.md` (§ 8 : organisation du travail, § 8.5 : arbitrages).
Branche de la mission : `feature/outils-donnees`, partie de `development`.

## Graphe

Sept lots indépendants, sans socle : les interfaces sont fixées par les contrats du § 8.3 de la spec.

```
reecriture-urls · anonymisation · outils-web · jobs-donnees · deploiement · iso-secrets · ansible
```

## Lots

| n | Lot | Plan | Profil | Dépend de | Issue | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `reecriture-urls` | [1-reecriture-urls.md](1-reecriture-urls.md) | `api` | — | | ⬜ |
| 2 | `anonymisation` | [2-anonymisation.md](2-anonymisation.md) | `api` | — | | ⬜ |
| 3 | `outils-web` | [3-outils-web.md](3-outils-web.md) | `api` | — | | ⬜ |
| 4 | `jobs-donnees` | [4-jobs-donnees.md](4-jobs-donnees.md) | `api` | — | | ⬜ |
| 5 | `deploiement` | [5-deploiement.md](5-deploiement.md) | `api` | — | | ⬜ |
| 6 | `iso-secrets` | [6-iso-secrets.md](6-iso-secrets.md) | `api` | — | | ⬜ |
| 7 | `ansible` | [7-ansible.md](7-ansible.md) | `api` | — | | ⬜ |

Statuts : ⬜ à faire · 🟡 en cours · 🔵 en revue · ✅ fusionné.

## Après la PR finale (développeur)

- Rejouer le playbook Ansible (droit `middlewares`, clé `BUCKET_COPIE_PREPROD`) avant tout déploiement des outils web
  ou export.
- Poser les nouveaux secrets (`PGADMIN_*`, `MINIO_ROOT_*` en saisie, Twilio de la prod en preprod), créer les
  enregistrements DNS `preprod.db`, `preprod.stockage`, `db`, `stockage`.
- Rétablir l'égalité stricte de l'inventaire des secrets (B8), puis vérifier les critères « réels » du § 7.
