# Mission `k3s-ansible` — Déploiement k3s, serveur Ansible et secrets GitHub

Spec : `docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 8 Organisation du travail, § 8.5 arbitrages).
Branche de la mission : `feature/k3s-ansible`, partie de `development`. PR finale vers `development`, fusionnée par le
développeur.

## Graphe

```
1 socle ──┬── 5 ansible
          ├── 6 charts
          ├── 7 deploiement
          └── 8 restauration
2 nettoyage      (indépendant)
3 api-prod       (indépendant)
4 fronts-prod    (indépendant)
```

## Tableau de bord

| n | Lot | Plan | Profil | Dépend de | Tâches | Issue | État |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | socle | `1-socle.md` | api | — | 3 | — | ⬜ |
| 2 | nettoyage | `2-nettoyage.md` | complet | — | 5 | — | ⬜ |
| 3 | api-prod | `3-api-prod.md` | api | — | 4 | — | ⬜ |
| 4 | fronts-prod | `4-fronts-prod.md` | api | — | 3 | — | ⬜ |
| 5 | ansible | `5-ansible.md` | api | socle | 9 | — | ⬜ |
| 6 | charts | `6-charts.md` | api | socle | 10 | — | ⬜ |
| 7 | deploiement | `7-deploiement.md` | api | socle | 7 | — | ⬜ |
| 8 | restauration | `8-restauration.md` | api | socle | 8 | — | ⬜ |

États : ⬜ à faire · 🟡 en cours · 🔵 en revue · ✅ fusionné.

## Après la PR finale

Mise en service avec le développeur (spec § 5.10) : réinstallation de A, `make infra-ansible`, inspection de la
sauvegarde, paquets GHCR publics, premier déploiement de la preprod. Le premier déploiement de la prod attend le chantier
séparé Firebase et connexion Google.
