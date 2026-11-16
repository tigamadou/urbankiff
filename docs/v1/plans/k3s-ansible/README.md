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
| 1 | socle | `1-socle.md` | api | — | 3 | #3 | ✅ |
| 2 | nettoyage | `2-nettoyage.md` | complet | — | 5 | #4 | ✅ |
| 3 | api-prod | `3-api-prod.md` | api | — | 4 | #5 | ✅ |
| 4 | fronts-prod | `4-fronts-prod.md` | api | — | 3 | #6 | ✅ |
| 5 | ansible | `5-ansible.md` | api | socle | 9 | #7 | ✅ |
| 6 | charts | `6-charts.md` | api | socle | 10 | #8 | ✅ |
| 7 | deploiement | `7-deploiement.md` | api | socle | 7 | #9 | ✅ |
| 8 | restauration | `8-restauration.md` | api | socle | 8 | #10 | ✅ |

États : ⬜ à faire · 🟡 en cours · 🔵 en revue · ✅ fusionné.

## Après la PR finale

Mise en service avec le développeur (spec § 5.10) : réinstallation de A, `make infra-ansible`, inspection de la
sauvegarde, paquets GHCR publics, premier déploiement de la preprod. Le premier déploiement de la prod attend le chantier
séparé Firebase et connexion Google.

**Preprod en service le 2026-11-17** (`v0.1.0-rc.4`). Le premier passage réel a révélé sept défauts que les tests en
conteneur ne pouvaient pas voir, corrigés par les PR #37 à #43 : diff des manifestes à la première installation et
kubeconfig du rôle `deploiement` (#37), Wasabi passé au mauvais chart (#38), RustFS sans `/logs` en racine lecture
seule (#39), lecture des `replicasets` pour `helm --wait` (#40), workers `OOMKilled` (un processus par CPU, #41), quota
de preprod trop juste (A18, #42), NodePorts de Traefik publiés hors ufw (#43). Restent : inspection de la sauvegarde,
données de démonstration de la preprod (non implémentées), premier déploiement de la prod.
