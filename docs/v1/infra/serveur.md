# Serveur : mise en place de k3s par Ansible

Un VPS Ubuntu 24.04 nu devient un nœud k3s durci (SSH par clé, ufw, chiffrement des Secrets, Flannel avec WireGuard),
avec la plateforme (cert-manager, CloudNativePG, plugin Barman Cloud, `ClusterIssuer` `letsencrypt`) et le compte
`deploy` à droits limités par namespace. Tout vit dans `infra/ansible/` ; la spec est
`docs/v1/specs/2026-11-16-k3s-ansible.md` (§ 5.2 et § 8.5).

## Vue d'ensemble

| Rôle | Ce qu'il fait | Testé localement |
| --- | --- | --- |
| `base` | paquets, administrateurs à clé, suppression des comptes absents de `admin_users`, sshd durci, ufw, fail2ban | oui (`make infra-test`) |
| `k3s` | k3s à version épinglée (serveur ou agent), Helm 3 | non (lint et `--syntax-check` seulement) |
| `plateforme` | manifestes vendus : cert-manager, opérateur CloudNativePG et plugin Barman Cloud (ces deux-là dans le namespace `cnpg-system`, celui des manifestes officiels) ; `ClusterIssuer`, namespaces `plateforme`, `prod` et `preprod`, quota et limites par défaut | non (lint seulement) |
| `deploiement` | compte `deploy` verrouillé, `authorized_keys` à commande forcée (une clé par environnement), `/etc/urbankiff/deploy.<env>.env`, script de déploiement ; ServiceAccount, Role et kubeconfig par namespace | volet utilisateur oui ; volet Kubernetes non |
| `fermeture_root` | ferme la connexion SSH de `root`, jouée en dernier après tous les autres plays | oui (`make infra-test`) |

La mise en service réelle (spec § 7) valide ce qui n'est pas testé localement : k3s, la plateforme et le volet
Kubernetes de `deploiement` n'ont jamais tourné sur un cluster réel avant elle.

Commandes (`make help` les liste) : `make infra-ansible LIMITE=<groupe ou hôte>`, `make infra-lint`,
`make infra-test`, `make infra-test-assert`, `make infra-vendre`.

## Prérequis

- Docker ; aucune autre commande n'est nécessaire sur le poste. Ansible tourne dans une image à versions épinglées
  (`infra/ansible/Dockerfile`, `requirements.yml`).
- Une clé SSH chargée dans l'agent : `ssh-add -l` doit la lister. La clé n'est jamais copiée : le conteneur reçoit le
  socket de l'agent (`/run/host-services/ssh-auth.sock` avec Docker Desktop ; sous Linux,
  `make infra-ansible LIMITE=noeuds SSH_SOCKET_HOTE=$SSH_AUTH_SOCK`).
- Le fichier `~/.ssh/known_hosts` du poste, monté en lecture seule : la vérification de l'empreinte du serveur reste
  active (`KNOWN_HOSTS_HOTE` pour un autre chemin).

## Réinstaller le serveur A chez Contabo

1. Dans la console Contabo, réinstaller le VPS en Ubuntu 24.04 et y injecter la clé publique de l'agent SSH.
   **Tout le contenu du serveur est effacé.** L'adresse IP ne change pas.
2. Relever l'empreinte SSH affichée dans la console, puis faire un premier `ssh root@<IP-de-A>` : comparer
   l'empreinte proposée à celle de la console avant d'accepter. La ligne est alors ajoutée à `known_hosts`.

## Inventaire

```sh
cp infra/ansible/inventory.example.yml infra/ansible/inventory.yml
```

`inventory.yml` est ignoré par git. À compléter :

- `ansible_host` de `urbankiff-a` (`ansible_user: root` au premier passage) ;
- `admin_users` : nom et clé publique **sans commentaire e-mail** (le contrôle refuse un `@`) ;
- `letsencrypt_email` : uniquement ici, jamais dans `group_vars` ;
- `deploy_keys`, voir ci-dessous. Jamais de clé privée dans l'inventaire.

## Clés de déploiement

Une clé par environnement, de types distincts pour `prod` et `preprod` :

```sh
ssh-keygen -t ed25519 -N '' -C '' -f ./cle-deploy-preprod
ssh-keygen -t ed25519 -N '' -C '' -f ./cle-deploy-prod
```

- Les clés publiques (`*.pub`) vont dans `deploy_keys.preprod` et `deploy_keys.prod` de l'inventaire.
- Les clés privées vont dans le secret `DEPLOY_SSH_KEY` de chaque environnement GitHub, avec les variables
  `DEPLOY_HOST` et `DEPLOY_KNOWN_HOSTS` : `make secrets-definir ENV=<prod|preprod> REPO=<owner/depot>`
  (voir `docs/v1/infra/secrets.md`). Supprimer ensuite les fichiers de clé du poste.

## Premier passage

```sh
make infra-ansible LIMITE=noeuds
```

Le premier passage se fait en `root` (image Contabo) : il crée les administrateurs et active ufw ; la connexion
de `root` n'est coupée qu'en dernier (rôle `fermeture_root`, dernier play de `site.yml`), après la réussite de tous
les autres plays. Un échec en cours de route laisse donc `root` utilisable : corriger puis rejouer la même commande
sans changer `ansible_user`. Une fois le passage terminé, changer `ansible_user` dans `inventory.yml` pour le nom d'un compte de `admin_users` et
rejouer ; un second passage ne doit rien changer (`changed=0`). Le contrôle de `site.yml` n'accepte comme
`ansible_user` que `root` ou un compte de `admin_users`, pour qu'on ne supprime jamais le compte qui se connecte.

Pour prévisualiser : `make infra-ansible LIMITE=noeuds ARGS="--check --diff"`.

## Vérifications

- Ports vus de l'extérieur : `make ports-scan HOTE=<IP-de-A>` doit répondre 22, 80 et 443 seulement.
- Mot de passe refusé : `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no <admin>@<IP-de-A>`.
- Nœud prêt : `ssh <admin>@<IP-de-A> sudo k3s kubectl get nodes`.
- Droits du compte `deploy`, sur le serveur, `sudo -u deploy` :
  - `kubectl auth can-i --list --kubeconfig /home/deploy/.kube/preprod` ne montre que le namespace `preprod` ;
  - `kubectl auth can-i create clusterroles --kubeconfig /home/deploy/.kube/prod` répond `no`.
  - ces deux vérifications sont à jouer à la mise en service : le volet Kubernetes de `deploiement` n'est pas testé
    en conteneur, elles sont la seule preuve que les droits sont bien limités par namespace.
- Le compte `deploy` n'ouvre pas de shell : `ssh deploy@<IP-de-A>` sans commande est refusé par le script de
  déploiement (commande forcée, `restrict`).

## Ajouter le nœud B

1. Réinstaller B en Ubuntu 24.04 (ses données sont effacées), comme pour A.
2. L'ajouter au groupe `agents` de `inventory.yml` (exemple commenté dans le fichier).
3. Rejouer **`make infra-ansible LIMITE=noeuds`**, pas seulement `LIMITE=<B>` : les règles ufw du nœud A changent
   (6443, 10250 et 51820/udp ne sont ouverts qu'entre les IP des nœuds).
4. `sudo k3s kubectl get nodes` sur A doit lister les deux nœuds.

Le plan de contrôle reste unique (A) : B n'est qu'un agent.

## Retirer un administrateur

Le retirer de `admin_users`, rejouer : son compte et son répertoire personnel sont supprimés.

## Rotation d'une clé de déploiement

Générer une nouvelle paire, remplacer la clé publique dans `deploy_keys`, rejouer `LIMITE=noeuds`, puis mettre à jour
`DEPLOY_SSH_KEY` de l'environnement (`make secrets-definir`). `authorized_keys` de `deploy` est exclusif : l'ancienne
clé disparaît au passage.

## Monter une version

Les versions (k3s, Helm, cert-manager, CloudNativePG, plugin Barman Cloud) sont dans `infra/ansible/group_vars/all.yml`.
Pour k3s, mettre aussi à jour `k3s_install_sha256` (somme du `install.sh` à cette étiquette). Pour la plateforme :

```sh
make infra-vendre      # télécharge les manifestes officiels et réécrit SHA256SUMS
git diff --stat        # relire : pas de latest, pas d'image non épinglée
make infra-lint        # vérifie les sommes et la concordance avec group_vars
make infra-ansible LIMITE=serveur
```

Le rôle n'applique jamais d'URL distante : seuls les fichiers vendus dans `roles/plateforme/files/` sont appliqués.

## Dépannage

- **SSH coupé** (clé perdue, mauvaise règle ufw) : console de secours Contabo, puis corriger `/etc/ssh/sshd_config.d/`
  ou `ufw`.
- **Que changerait un passage ?** `make infra-ansible LIMITE=noeuds ARGS="--check --diff"`.
- **Tester sans serveur** : `make infra-test` joue `base` et le volet utilisateur de `deploiement` sur un conteneur
  Ubuntu 24.04 jetable (deux passages, second à zéro changement, puis vérifications) ; `make infra-test-assert`
  vérifie que les inventaires invalides sont refusés ; `make infra-lint` lance ansible-lint, le contrôle de syntaxe et
  les contrôles statiques (options k3s, sommes SHA-256).

## Limites connues

- Un seul nœud de contrôle (A) : sa perte arrête l'API du cluster.
- `flannel-backend: wireguard-native` est fixé à l'installation : en changer exige de réinstaller le cluster.
- k3s, la plateforme et le volet Kubernetes de `deploiement` ne sont pas testés en conteneur (pas de k3s en conteneur
  dans ce lot) ; la mise en service réelle les valide.
- Compatibilité à vérifier à la mise en service : la version du plugin Barman Cloud doit être compatible avec celle
  de l'opérateur CloudNativePG (voir les notes de version du plugin) ; les deux sont épinglées dans `group_vars/all.yml`.
- Les namespaces, le quota de `preprod` (2 Gio de limites, 1,5 Gio de requêtes) et le `LimitRange` sont créés par le
  rôle `plateforme` ; le compte `deploy` ne peut pas les modifier.
- `deploy.<env>.env` remplace le `deploy.env` unique du contrat initial (arbitrage A8 de la spec).
- `API_SERVER_CIDR=<IP>/32` de `deploy.<env>.env` est l'IP du nœud k3s : `api_server_ip` dans `deploiement_envs.<env>` de l'inventaire, sinon `ansible_default_ipv4.address`. Le script de déploiement la passe au chart (`reseau.apiKubernetes.cidr`).
