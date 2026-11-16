# Ansible — Plan d'implémentation

> **Arbitrages de la relecture croisée** (spec § 8.5, ils priment sur ce plan en cas d écart) : A7 (ClusterIssuer letsencrypt), A8 (commande forcée urbankiff-deploy <env>, /etc/urbankiff/deploy.<env>.env), A9 (namespaces prod et preprod, ResourceQuota preprod 2 Gio de limites et 1,5 Gio de requêtes, LimitRange, créés par le rôle plateforme).

> **Pour les agents d'exécution** : exécuter tâche par tâche, tests d'abord. Les étapes utilisent la syntaxe à cases
> `- [ ]`.

**Objectif** : un VPS Ubuntu 24.04 nu devient, par `make infra-ansible LIMITE=noeuds`, un nœud k3s durci (SSH par clé,
ufw, chiffrement des Secrets, Flannel WireGuard), avec la plateforme (cert-manager, CloudNativePG, plugin Barman Cloud,
ClusterIssuer) et le compte `deploy` à droits limités par namespace ; rejouable sans changement ; ajout d'un nœud =
une ligne d'inventaire. Documentation de mise en place dans `docs/v1/infra/serveur.md`.

**Architecture** : `infra/ansible/` (inventaire d'exemple, `group_vars/all.yml` avec versions épinglées, `site.yml`
en deux plays : tous les nœuds `base` + `k3s`, puis le nœud serveur `plateforme` + `deploiement`). Ansible, ansible-lint
et collections dans une image locale à versions épinglées (`infra/ansible/Dockerfile`), clé SSH via l'agent SSH. Les
manifestes cert-manager, CloudNativePG et Barman Cloud sont **vendus** dans `roles/plateforme/files/` avec leurs
sommes SHA-256 (jamais d'URL distante à l'application). Tests sans serveur réel : `ansible-lint`, `--syntax-check`,
test d'échec de l'assert, et exécution de `base` et du volet « utilisateur » de `deploiement` sur un conteneur Ubuntu
24.04 jetable avec systemd (deux passages : changements puis zéro changement, puis vérifications).

**Stack** : Ansible (ansible-core épinglé), ansible-lint, collections `ansible.posix` et `community.general`
(versions épinglées), Docker, GNU Make, shell POSIX pour les scripts de test et de vente des manifestes.

**Spec** : `docs/v1/specs/2026-11-16-k3s-ansible.md` (section « Organisation du travail » ; elle fait autorité). Plan de
la mission `k3s-ansible`, lot 5 sur 8.

## Exécution

- **Mission** : `k3s-ansible` · **Issue** : à renseigner par le superviseur
- **Branche** : `feature/k3s-ansible-ansible` · **Base** : `feature/k3s-ansible` · **Profil** : api
- **Dépendances** : `socle` (inclusion des `make/*.mk` dans le `Makefile` et `.gitignore`) (lots qui doivent être
  fusionnés dans la base avant de démarrer).
- Toutes les commandes `make` se lancent dans le worktree du lot.
- En exécution automatisée, un commit par tâche est autorisé sur la branche du lot ; message d'une ligne, au format
  Conventional Commits de la convention du projet, sans numéro d'issue, sans trailer, **jamais de mention de
  co-auteur IA**. Sinon, aucun commit sans demande explicite. Jamais de commit sur la branche d'intégration ni sur une
  branche protégée, jamais de `--force`, jamais de `--no-verify`.

## Avancement

Statut : 🟡 en cours · Prochaine tâche : 5

- [x] **Tâche 1** Socle du lot : image Ansible épinglée, `make/infra.mk` (`infra-image`, `infra-ansible`, `infra-lint`), configuration, inventaire d'exemple, `group_vars` · `feature/k3s-ansible-ansible`
  - [x] Vérifier l'inclusion `make/*.mk` et l'ignore de `inventory.yml` (socle fusionné)
  - [x] Test rouge : `make infra-lint` échoue (rien à vérifier / cible absente)
  - [x] `Dockerfile`, `ansible.cfg`, `requirements.yml`, `.ansible-lint`, `inventory.example.yml`, `group_vars/all.yml`
  - [x] `make/infra.mk` : `infra-image`, `infra-ansible`, `infra-lint`
- [x] **Tâche 2** `site.yml` et assert des variables obligatoires · `feature/k3s-ansible-ansible`
  - [x] Test d'échec de l'assert (inventaire invalide), rouge puis vert
  - [x] `site.yml` (deux plays, rôles vides) ; cible `infra-test-assert`
- [x] **Tâche 3** Harnais de test sur conteneur Ubuntu 24.04 (rouge) · `feature/k3s-ansible-ansible`
  - [x] Image cible systemd + sshd, script `tests/lancer.sh`, `tests/verifier.yml`, cible `infra-test`
  - [x] Constater l'échec des vérifications (rôles vides)
- [x] **Tâche 4** Rôle `base` · `feature/k3s-ansible-ansible`
  - [x] Paquets, mises à jour auto, administrateurs, sudo, suppression des comptes absents
  - [x] sshd durci, ufw, fail2ban
  - [x] `make infra-test` vert pour `base` (deux passages, zéro changement au second)
- [ ] **Tâche 5** Rôle `k3s` (serveur ou agent, Helm) · `feature/k3s-ansible-ansible`
  - [ ] Configuration `config.yaml` (secrets-encryption, wireguard-native), installation épinglée et vérifiée
  - [ ] Jeton lu sur le serveur, agent ; Helm
  - [ ] `infra-lint` vert (k3s réel non testé localement)
- [ ] **Tâche 6** Manifestes vendus et rôle `plateforme` · `feature/k3s-ansible-ansible`
  - [ ] `make infra-vendre` : téléchargement en conteneur, sommes SHA-256, contrôle `infra-lint`
  - [ ] Rôle : application différentielle, attentes, ClusterIssuer
- [ ] **Tâche 7** Rôle `deploiement` · `feature/k3s-ansible-ansible`
  - [ ] Volet utilisateur (compte, `deploy.env`, script, `authorized_keys`) testé sur conteneur
  - [ ] Volet Kubernetes (namespaces, ServiceAccount, Role, kubeconfig par environnement), non testé localement
- [ ] **Tâche 8** Documentation `docs/v1/infra/serveur.md` · `feature/k3s-ansible-ansible`
- [ ] **Tâche 9** Vérification du lot

> Reprise : (vide)

Statuts : ⬜ à faire · 🟡 en cours · ✅ terminé. Cocher une case **seulement après tests verts**. Interruption en cours
de tâche : cocher ce qui est fini et noter ici `> Reprise :` l'étape en cours, les fichiers touchés et la prochaine
étape.

## Fichiers du lot (exclusifs)

- `infra/ansible/**` [nouveau] (dont `.travail/`, dossier de travail ignoré par git : clés de test éphémères)
- `make/infra.mk` [nouveau]
- `docs/v1/infra/serveur.md` [nouveau]
- `docs/v1/plans/k3s-ansible/5-ansible.md` (ce plan : Avancement)

## Fichiers en lecture seule

`docs/v1/specs/2026-11-16-k3s-ansible.md`, `Makefile` et `.gitignore` (socle), `make/devteam.mk`, `make/standard.mk`,
`make/secrets.mk` (cible `ports-scan`, `secrets-scan`, `secrets-definir`), `make/devteam-agent.mk`,
`docs/v1/infra/rotation-secrets.md`, `docs/v1/infra/secrets.md`, `.github/workflows/devteam-ci.yml`,
**`infra/deploiement/urbankiff-deploy.sh`** (produit par le lot `deploiement` ; le rôle ne fait que le copier ; son
absence pendant les tests est gérée, voir tâche 7), et tous les fichiers exclusifs des autres lots. Référence steamy
(hors dépôt, à lire seulement) : `/Users/amadou/Devs/projects/steamy/infra/ansible/` et `docs/infra/`.

Besoin d'y toucher → **s'arrêter et le signaler dans l'issue** (jamais de modification de ces fichiers depuis ce
lot).

## Contraintes globales

Règles lues dans `.claude/devteam.projet.md` et `CLAUDE.md` : toutes les commandes passent par des cibles `make` qui
lancent des conteneurs (sur l'hôte : `docker`, `make`, `git`, `gh` seulement) ; commits en ASCII, Conventional
Commits, aucune mention d'IA ; aucun secret dans le dépôt (`make secrets-scan` à zéro). Au minimum : tests d'abord ;
aucun mock ; ne jamais modifier le code de production pour faire passer un test (s'arrêter et le signaler) ; pas de
`retry` ni de contournement pour masquer une instabilité. Spécifique au lot (le code est ici de l'infrastructure, la
couverture à 100 % s'entend comme : chaque rôle et chaque comportement du § 5.2 de la spec est couvert par une
vérification de `make infra-test`, ou déclaré explicitement non testé localement) :

- **À ne pas reproduire de steamy** : (1) compte `deploy` administrateur du cluster : ici un ServiceAccount et un Role
  **par namespace** (`prod`, `preprod`), aucun ClusterRole ni `cluster-admin`, et jamais de copie de
  `/etc/rancher/k3s/k3s.yaml` ; (2) manifestes appliqués depuis des URL distantes : ici fichiers vendus, vérifiés par
  SHA-256, copiés puis appliqués localement ; la seule URL permise est celle du **vendeur** (`make infra-vendre`) ;
  (3) administrateurs retirés mais non supprimés : suppression des comptes absents de `admin_users` ;
  (4) variable `ansible_ssh_private_key` invalide : on n'utilise **jamais** de clé privée dans l'inventaire, la clé
  vient de l'agent SSH ; (5) adresse e-mail dans des clés versionnées : `admin_users[].pubkey` sans commentaire
  e-mail (assert : pas de `@`), et `letsencrypt_email` vit **uniquement** dans `inventory.yml` (ignoré par git),
  jamais dans `group_vars/all.yml`.
- Aucune clé privée, aucun jeton k3s ni jeton de ServiceAccount dans le dépôt, dans l'image ou dans les logs
  (`no_log: true` sur toute tâche qui les manipule).
- Idempotence : un second passage ne change rien (critère de fin de la spec, § 7) ; `changed_when` explicite sur
  toute tâche `command`/`shell`.
- Versions épinglées dans `group_vars/all.yml` seulement (k3s, Helm 3 : le script de déploiement utilise `--atomic`,
  renommé en Helm 4 ; cert-manager, CloudNativePG, plugin Barman Cloud) et dans le `Dockerfile` /
  `requirements.yml` (ansible-core, ansible-lint, collections, image de base). Points de départ pris dans steamy
  (k3s `v1.36.5+k3s1`, Helm `v3.22.0`, cert-manager `v1.21.2`, CloudNativePG `1.30.1`, Barman Cloud `v0.15.1`) : les
  **contrôler** contre les publications officielles au moment de la tâche, et noter le résultat dans le message de
  commit ou le rapport.
- Cibles `make` : `infra-image`, `infra-ansible`, `infra-lint`, `infra-test`, `infra-test-assert`, `infra-vendre`
  (noms intermédiaires laissés au constructeur par la spec). Chaque cible porte un `##` d'aide.
- Le lot ne modifie ni `Makefile` ni `.gitignore` (socle). Si `infra/ansible/inventory.yml` ou
  `infra/ansible/.travail/` n'est pas ignoré à la base : s'arrêter et le signaler.
- Docker Desktop (poste du développeur) : socket de l'agent SSH à `/run/host-services/ssh-auth.sock` ; sous Linux,
  `make infra-ansible SSH_SOCKET_HOTE=$SSH_AUTH_SOCK` (variable surchargeable). Jamais de copie de clé.

## Points de revue

1. **Contrat « Serveur » à clarifier (signalé au superviseur)** : deux clés (preprod, prod) pour **un seul** compte
   `deploy` et une commande forcée sans argument ne permettent pas au script de savoir quel environnement une clé
   désigne, alors que le contrat ne prévoit qu'un `/etc/urbankiff/deploy.env` (`URBANKIFF_ENV` unique). Option
   retenue par défaut dans ce plan, **à valider avec le lot `deploiement`** : la commande forcée porte l'environnement
   en argument (`command="/usr/local/bin/urbankiff-deploy preprod",restrict`) ; le rôle écrit
   `/etc/urbankiff/deploy.<env>.env` (mêmes clés `URBANKIFF_ENV`, `GHCR_OWNER`, `NAMESPACE`, une valeur propre à chaque
   environnement) **et** `/etc/urbankiff/deploy.env` conforme au contrat ; le script lit son premier argument. Si le
   lead tranche autrement, seuls le gabarit `authorized_keys` et les fichiers `.env` changent (tâche 7).
2. Le compte `deploy` n'a aucun droit sur le cluster hors de `prod` et `preprod` : relire les règles du Role
   (`deploiement_role_regles`) ; elles couvrent ce dont `helm` (stockage des releases en Secrets), les deux charts et
   `preprod-arret`/`preprod-demarrage` ont besoin, et rien de plus (pas de `resourcequotas`, pas de `namespaces`).
3. `ResourceQuota` de `preprod` (1,5 Go de limites mémoire, spec § 5.4) : créée par ce lot avec les namespaces (le
   compte de déploiement ne peut pas la modifier) ; à confirmer avec le lot `charts` pour éviter un doublon.
4. Ordre des pare-feux : ufw n'ouvre 6443, 10250 et 51820/udp qu'entre les IP de `groups['noeuds']` ; les réseaux
   internes de k3s (`10.42.0.0/16`, `10.43.0.0/16`) sont autorisés en entrée pour les pods vers l'hôte, sans exposition
   externe. Vérifier qu'ajouter un nœud exige de rejouer `LIMITE=noeuds` (les règles du nœud existant changent).
5. La connexion de premier passage se fait en `root` (image Contabo) puis plus jamais : l'assert accepte `root` ou un
   compte de `admin_users`, jamais un autre, pour qu'on ne supprime pas le compte qui se connecte.
6. k3s, plateforme et volet Kubernetes de `deploiement` ne sont **pas exécutés localement** (pas de k3s en conteneur
   dans ce lot) ; ils sont couverts par ansible-lint, `--syntax-check` et relecture ; la mise en service réelle
   (spec § 7) les valide.

---

### Tâche 1 : socle du lot (image, make, configuration, variables)

**Fichiers :**
- Créer : `infra/ansible/Dockerfile`, `infra/ansible/ansible.cfg`, `infra/ansible/requirements.yml`,
  `infra/ansible/.ansible-lint`, `infra/ansible/inventory.example.yml`, `infra/ansible/group_vars/all.yml`,
  `make/infra.mk`
- Test : `make infra-lint` (cible créée dans cette tâche), `git check-ignore`

**Interfaces :**
- Consomme : inclusion `make/*.mk` du `Makefile` (contrat 8.3 « Inclusion make », socle) ; ignore de
  `infra/ansible/inventory.yml` et `infra/**/.travail/` (socle).
- Produit : image locale `urbankiff-ansible:<étiquette dérivée du hash du Dockerfile et de requirements.yml>` ;
  cibles `infra-image`, `infra-ansible`, `infra-lint` ; variables de make `ANSIBLE_IMAGE`, `SSH_SOCKET_HOTE`,
  `LIMITE`, `ARGS` ; noms de groupes d'inventaire `noeuds` (enfants `serveur`, `agents`) ; variables d'inventaire
  `ansible_host`, `ansible_user`, `admin_users`, `letsencrypt_email`, `deploy_keys` (clé `prod`, clé `preprod`).

- [ ] **Étape 1** : vérifier que `make help` (ou `make -pn | grep infra`) voit le mécanisme d'inclusion du socle
  (`make/*.mk` ajouté en base) et que `git check-ignore infra/ansible/inventory.yml infra/ansible/.travail/x` répond
  (sinon : arrêt et signalement). Écrire le test : `make infra-lint` doit échouer (cible inconnue).
- [ ] **Étape 2** : implémenter.
  - `Dockerfile` : `python:3.12-slim` épinglé (étiquette précise, digest si disponible), `pip install` de
    `ansible-core==<v>` et `ansible-lint==<v>` (versions épinglées, vérifiées), `openssh-client`, `sshpass` absent
    (aucun mot de passe), utilisateur non root pour les contrôles ; collections par `requirements.yml` avec
    versions exactes (`ansible.posix`, `community.general`) installées à la construction.
  - `ansible.cfg` : `inventory = inventory.yml`, `roles_path = roles`, `host_key_checking = True`,
    `pipelining = True`, `interpreter_python = auto_silent`, `callback_result_format = yaml`.
  - `.ansible-lint` : profil `production`, chemins exclus (`.travail/`, `files/`).
  - `inventory.example.yml` : groupe `noeuds` avec enfants `serveur` (un hôte : `urbankiff-a`, `ansible_host:
    203.0.113.10`, `ansible_user: root` au premier passage avec commentaire « puis un compte de admin_users ») et
    `agents` (vide, avec un exemple commenté pour B) ; variables de groupe `noeuds` : `admin_users` (nom + clé
    publique **sans commentaire e-mail**, valeur factice), `letsencrypt_email`, `deploy_keys` (`preprod`, `prod` :
    clés publiques `ssh-ed25519 AAAA…` factices). Aucune clé privée.
  - `group_vars/all.yml` : versions épinglées (k3s, Helm, cert-manager, CloudNativePG, Barman, somme SHA-256 du
    `install.sh` de k3s à la version choisie), `ghcr_owner: tigamadou`, `deploiement_envs` (`prod` → namespace `prod`,
    `preprod` → namespace `preprod`), `ports_cluster`, `reseaux_internes_k3s`, `preprod_quota_memoire_limites:
    1536Mi`. **Aucun e-mail, aucune clé.**
  - `make/infra.mk` : `infra-image` (docker build avec étiquette dérivée du contenu), `infra-ansible` (exige
    `LIMITE`, monte `infra/ansible` et le dépôt en `/repo`, socket SSH de l'agent montée à `/ssh-agent` avec
    `SSH_AUTH_SOCK=/ssh-agent`, `known_hosts` du poste monté en lecture seule, `ansible-playbook site.yml --limit
    $(LIMITE) $(ARGS)`), `infra-lint` (`ansible-lint` puis `ansible-playbook site.yml --syntax-check` avec
    l'inventaire d'exemple, tous deux en conteneur).
- [ ] **Étape 3** : `make infra-image` puis `make infra-lint` verts ; `make infra-ansible` sans `LIMITE` → message
  d'usage et code 2. Cocher l'Avancement ; commit d'une ligne.

---

### Tâche 2 : `site.yml` et assert des variables obligatoires

**Fichiers :**
- Créer : `infra/ansible/site.yml`, `infra/ansible/tests/inventaire-invalide.yml`
- Modifier : `make/infra.mk` (cible `infra-test-assert`)
- Test : `infra/ansible/tests/inventaire-invalide.yml` joué par `make infra-test-assert`

**Interfaces :**
- Consomme : variables de la tâche 1.
- Produit : `site.yml` (play 1 `noeuds` : assert puis `base`, `k3s` ; play 2 `serveur` : `plateforme`,
  `deploiement`) ; liste des assert : `admin_users` non vide, chaque clé commence par `ssh-` et ne contient pas `@`,
  `ansible_user` ∈ `{root} ∪ noms(admin_users)`, `letsencrypt_email` non vide, `deploy_keys.prod` et
  `deploy_keys.preprod` distinctes et valides, `groups['serveur'] | length == 1`, hôtes de `noeuds` = `serveur` ∪
  `agents`.

- [ ] **Étape 1** : écrire le test, le voir échouer. `tests/inventaire-invalide.yml` (connexion locale, variables
  manquantes ou invalides : clé avec e-mail, clés `prod` = `preprod`, `ansible_user` hors liste). `make
  infra-test-assert` doit constater que `site.yml` **s'arrête sur l'assert** pour chaque cas (un cas par groupe d'hôtes
  de test, message `fail_msg` lu) ; avant `site.yml`, la cible échoue.
- [ ] **Étape 2** : implémenter `site.yml` (rôles encore vides), `fail_msg` clairs, `gather_facts: false` sur
  l'assert ; cible `infra-test-assert`.
- [ ] **Étape 3** : `make infra-test-assert` et `make infra-lint` verts ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 3 : harnais de test sur conteneur Ubuntu 24.04 (rouge)

**Fichiers :**
- Créer : `infra/ansible/tests/Dockerfile.cible`, `infra/ansible/tests/lancer.sh`, `infra/ansible/tests/site-test.yml`,
  `infra/ansible/tests/inventaire-test.yml`, `infra/ansible/tests/verifier.yml`
- Modifier : `make/infra.mk` (cible `infra-test`)

**Interfaces :**
- Consomme : image Ansible (tâche 1), `site.yml` (tâche 2).
- Produit : `make infra-test` ; `tests/site-test.yml` (joue `base` puis `deploiement` avec `deploiement_k8s: false`,
  `deploiement_script_requis: false`, `base_gerer_ufw` activé) ; `tests/verifier.yml` (vérifications du § 4/7).

- [ ] **Étape 1** : écrire les vérifications d'abord, en rouge.
  - `Dockerfile.cible` : `ubuntu:24.04` épinglé + systemd + `openssh-server`, `python3`, `sudo`, `iproute2`,
    `iptables` ; démarré avec `--cap-add NET_ADMIN --cap-add SYS_ADMIN --tmpfs /run --tmpfs /tmp --cgroupns=host -v
    /sys/fs/cgroup:/sys/fs/cgroup:rw` (repli documenté : `--privileged`, conteneur jetable local seulement).
  - `lancer.sh` (appelé par `make infra-test`, precédent : `scripts/secrets/definir-secrets.sh`) : réseau Docker
    jetable ; conteneur cible ; **paire de clés éphémère** générée dans `infra/ansible/.travail/` (ignoré par git,
    supprimée en fin d'exécution par `trap`) ; création d'un compte factice `ancien` (uid 1500) pour prouver la
    suppression ; **passage 1** en `root` (crée l'administrateur `testadmin`, coupe root) ; **passage 2** en `testadmin`
    (`changed=0` exigé) ; `verifier.yml` ; nettoyage du conteneur et du réseau même en échec.
  - `verifier.yml` (sur la cible, par `command`/`assert`) : `sshd -T` donne `passwordauthentication no`,
    `permitrootlogin no`, `maxauthtries 3`, `kbdinteractiveauthentication no` ; `ufw status verbose` : `Status:
    active`, défaut `deny (incoming)`, 22/80/443 `ALLOW`, 6443/10250/51820 limités aux IP des nœuds, rien d'autre ;
    `/etc/sudoers.d/` validé ; `ancien` absent de `getent passwd` ; `testadmin` dans `sudo` ; utilisateur `deploy`
    existant, mot de passe verrouillé (`passwd -S deploy` → `L`), `~deploy/.ssh/authorized_keys` en `0600` propriétaire
    `deploy`, **exactement deux lignes** (preprod, prod) de la forme
    `command="/usr/local/bin/urbankiff-deploy <env>",restrict ssh-ed25519 …` (voir point de revue 1) ; fichiers
    `/etc/urbankiff/deploy.env` et `deploy.<env>.env` avec `URBANKIFF_ENV`, `GHCR_OWNER`, `NAMESPACE` ;
    `/usr/local/bin/urbankiff-deploy` en `0755` root quand le script source existe.
- [ ] **Étape 2** : implémenter le harnais (tout sauf les rôles) ; `make infra-test` doit **échouer** sur les
  vérifications (rôles vides), preuve que le test détecte.
- [ ] **Étape 3** : `make infra-lint` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 4 : rôle `base`

**Fichiers :**
- Créer : `infra/ansible/roles/base/{tasks,handlers,defaults,templates}/main.yml` (+ gabarits `sshd.conf.j2`,
  `sudoers.j2`)
- Test : `make infra-test` (vérifications de la tâche 3 relatives à `base`)

**Interfaces :**
- Consomme : `admin_users`, `groups['noeuds']`, `hostvars[*].ansible_host`, `ports_cluster`, `reseaux_internes_k3s`.
- Produit : comptes administrateurs à clé ; `/etc/sudoers.d/urbankiff-admins` (validé par `visudo -cf`, sudo sans mot
  de passe car comptes sans mot de passe) ; `/etc/ssh/sshd_config.d/10-urbankiff.conf` (`PasswordAuthentication no`,
  `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `X11Forwarding no`, `MaxAuthTries 3`, validé par `sshd -t`,
  le `10-` l'emporte sur `50-cloud-init.conf` de Contabo) ; ufw ; fail2ban ; mises à jour automatiques.

- [ ] **Étape 1** : les vérifications `base` de `verifier.yml` existent déjà (rouges) ; ajouter un contrôle qui prouve
  qu'**un compte absent de la liste est supprimé** (`ancien`, home compris) et que `testadmin` survit.
- [ ] **Étape 2** : implémenter.
  - Paquets : `ufw`, `fail2ban`, `unattended-upgrades`, `ca-certificates`, `curl` ; `20auto-upgrades`.
  - Comptes : création et clés (`ansible.posix.authorized_key`, `exclusive: true`) ; **suppression** des comptes
    humains absents : `getent passwd` filtré uid 1000-59999, hors `admin_users`, hors `deploy`, hors `nobody` ;
    `user: state=absent remove=yes force=yes` ; garde-fou : jamais l'`ansible_user` courant (déjà garanti par l'assert).
  - sshd : gabarit + handler `Redémarrer ssh` (service `ssh` sur Ubuntu 24.04, pas `sshd`) ; vérifier `ssh.socket`.
  - ufw : politique entrante `deny`, sortante `allow` ; 22/80/443 tcp ouverts à tous ; pour chaque IP de nœud :
    6443/tcp, 10250/tcp, 51820/udp (`from_ip`) ; `reseaux_internes_k3s` en entrée ; ufw activé **après** les règles
    SSH (pas de coupure) ; fail2ban actif.
  - Variable `base_gerer_ufw` (par défaut vrai) pour le seul cas où le conteneur de test ne supporte pas
    `iptables` : si c'est le cas, **le dire** dans la tâche et faire vérifier les règles par `ufw show added`.
- [ ] **Étape 3** : `make infra-test` : passage 1 changements, passage 2 `changed=0`, vérifications `base` vertes ;
  `make infra-lint` vert ; cocher l'Avancement ; commit d'une ligne.

---

### Tâche 5 : rôle `k3s`

**Fichiers :**
- Créer : `infra/ansible/roles/k3s/{tasks,handlers,defaults,templates}/…` (`config-serveur.yaml.j2`,
  `config-agent.yaml.j2`)
- Modifier : `infra/ansible/site.yml` (aucun changement attendu si les rôles sont déjà branchés)
- Test : `make infra-lint` ; **non exécutable localement** (pas de k3s réel) : le dire dans le rapport

**Interfaces :**
- Consomme : `k3s_version`, `k3s_install_sha256`, `helm_version`, groupes `serveur` / `agents`, `ansible_host`.
- Produit : `/etc/rancher/k3s/config.yaml` ; service `k3s` (serveur) ou `k3s-agent` (agent) ; `/usr/local/bin/helm`
  épinglé ; kubeconfig du serveur `/etc/rancher/k3s/k3s.yaml` en `0600` root (jamais copié ailleurs) ; jeton lu sur
  `/var/lib/rancher/k3s/server/node-token` du serveur (jamais écrit dans le dépôt ni affiché).

- [ ] **Étape 1** : test d'abord : ajouter à `infra-lint` un contrôle de présence des options obligatoires
  (`grep` en conteneur sur `config-serveur.yaml.j2` : `secrets-encryption: true`, `flannel-backend:
  wireguard-native`, `write-kubeconfig-mode: "0600"`) ; le voir échouer avant le gabarit.
- [ ] **Étape 2** : implémenter.
  - Installation : script `install.sh` de la version épinglée téléchargé avec `get_url` + `checksum:
    sha256:{{ k3s_install_sha256 }}`, lancé avec `INSTALL_K3S_VERSION` et `INSTALL_K3S_EXEC` depuis le `config.yaml`
    (plus d'options en ligne de commande) ; saute l'installation si `k3s --version` correspond.
  - Serveur : `config.yaml` avec `write-kubeconfig-mode: "0600"`, `secrets-encryption: true`, `flannel-backend:
    wireguard-native`, `node-external-ip: <ansible_host>` ; attente `kubectl wait node --for=condition=Ready`.
    Commentaire du **pourquoi** : le backend Flannel ne se change plus sans réinstaller.
  - Agent : lit le jeton **sur le serveur** (`slurp` délégué, `no_log: true`), écrit `config.yaml` agent (`server:
    https://<ip serveur>:6443`, `token`) en `0600`, service `k3s-agent` ; handler de redémarrage.
  - Helm : `get_url` de l'archive de la version épinglée avec checksum `sha256:` du fichier `.sha256sum` officiel,
    puis extraction du binaire ; idempotent par comparaison de version.
- [ ] **Étape 3** : `make infra-lint` vert (ansible-lint profil production, `--syntax-check`) ; relire à haute voix les
  tâches `command`/`shell` (`changed_when`) ; cocher l'Avancement ; commit d'une ligne. Rapport : « k3s non testé
  sur un nœud réel ».

---

### Tâche 6 : manifestes vendus et rôle `plateforme`

**Fichiers :**
- Créer : `infra/ansible/scripts/vendre-manifestes.sh`, `infra/ansible/roles/plateforme/{tasks,templates,defaults}/…`,
  `infra/ansible/roles/plateforme/files/cert-manager-<version>.yaml`,
  `files/cloudnative-pg-<version>.yaml`, `files/plugin-barman-cloud-<version>.yaml`, `files/SHA256SUMS`,
  `templates/clusterissuer.yaml.j2`
- Modifier : `make/infra.mk` (`infra-vendre`, contrôle SHA-256 dans `infra-lint`)

**Interfaces :**
- Consomme : versions de `group_vars/all.yml`, `letsencrypt_email` (inventaire), k3s (tâche 5).
- Produit : manifestes versionnés ; namespaces `cert-manager` et `cnpg-system` créés par les manifestes ;
  `ClusterIssuer` `letsencrypt` (HTTP-01, `ingressClassName: traefik`) ; objet attendu par les charts :
  `cert-manager.io/v1 ClusterIssuer/letsencrypt`.
  Remarque : le namespace `plateforme` de la spec 5.1 est créé ici s'il n'existe pas (réservé aux ressources propres
  à la plateforme ; les opérateurs gardent les namespaces de leurs manifestes officiels).

- [ ] **Étape 1** : test d'abord : `infra-lint` vérifie `sha256sum -c files/SHA256SUMS` et que les versions des noms
  de fichiers correspondent à `group_vars/all.yml` ; rouge tant que les fichiers manquent.
- [ ] **Étape 2** : implémenter.
  - `infra-vendre` : conteneur `alpine`/`curl` épinglé, télécharge les trois manifestes **officiels** aux versions de
    `group_vars/all.yml`, écrit `files/` et `SHA256SUMS` ; c'est le seul endroit qui connaît des URL distantes ;
    exécuté dans cette tâche, résultat commité (relecture du diff : pas de `latest`, pas d'image non épinglée
    inattendue).
  - Rôle : copie des manifestes dans `/var/lib/urbankiff/manifests/` (0600 root) ; pour chacun
    `k3s kubectl diff --server-side -f` (rc 0 = inchangé, rc 1 = à appliquer, autre = échec) puis
    `k3s kubectl apply --server-side -f` seulement si différent (`changed_when` réel, pas de `changed_when: false`
    masquant) ; attentes `Available` sur cert-manager, `cnpg-controller-manager`, `barman-cloud` ; ordre : cert-manager,
    CloudNativePG, plugin Barman Cloud (qui dépend de cert-manager), ClusterIssuer (gabarit, `apply`).
- [ ] **Étape 3** : `make infra-lint` vert (SHA-256 inclus) ; documenter (tâche 8) la montée de version :
  changer `group_vars`, `make infra-vendre`, relire le diff, rejouer. Cocher l'Avancement ; commit d'une ligne.
  Rapport : « plateforme non testée sur un cluster réel ».

---

### Tâche 7 : rôle `deploiement`

**Fichiers :**
- Créer : `infra/ansible/roles/deploiement/{tasks,defaults,templates}/…` (`main.yml`, `utilisateur.yml`,
  `kubernetes.yml`, gabarits `deploy.env.j2`, `authorized_keys.j2`, `rbac.yaml.j2`, `kubeconfig.j2`)
- Test : `infra/ansible/tests/verifier.yml` (volet utilisateur), `make infra-test`

**Interfaces :**
- Consomme : `deploy_keys` (par environnement), `ghcr_owner`, `deploiement_envs`, `infra/deploiement/urbankiff-deploy.sh`
  (lecture seule, lot `deploiement`), k3s et `kubectl` du serveur (tâches 5 et 6).
- Produit (contrat « Serveur », 8.3) : utilisateur `deploy` (mot de passe verrouillé, shell restreint par la commande
  forcée) ; ServiceAccount `deploy` dans `prod` et dans `preprod` avec un `Role` + `RoleBinding` limités à leur
  namespace ; kubeconfig `/home/deploy/.kube/<env>` en `0600` (`deploy:deploy`) ; `/etc/urbankiff/deploy.env`
  (`URBANKIFF_ENV`, `GHCR_OWNER`, `NAMESPACE`) et `/etc/urbankiff/deploy.<env>.env` (point de revue 1) ;
  `/usr/local/bin/urbankiff-deploy` copié de `infra/deploiement/urbankiff-deploy.sh` ; `authorized_keys` :
  `command="/usr/local/bin/urbankiff-deploy <env>",restrict <clé de l'environnement>`, une ligne par environnement ;
  variables du rôle `deploiement_k8s` (vrai par défaut), `deploiement_script_requis` (vrai par défaut),
  `deploiement_role_regles` (liste des règles du Role).

- [ ] **Étape 1** : les vérifications du volet utilisateur existent (tâche 3) ; ajouter : le test passe sans script
  source (`deploiement_script_requis: false` : la tâche d'installation est sautée avec message, vérification
  correspondante conditionnelle), et **échoue franchement** quand `deploiement_script_requis` est vrai et que le
  fichier manque (cas production : `assert` sur `stat` du script côté contrôleur, message « lot deploiement non
  fusionné »). Rouge d'abord.
- [ ] **Étape 2** : implémenter.
  - `utilisateur.yml` : compte `deploy` (`password: "!"`, `password_lock: true`), `/home/deploy/.ssh` et
    `/home/deploy/.kube` en `0700`, `/etc/urbankiff` en `0755`, fichiers `.env`, copie du script (`0755`,
    root:root), `authorized_keys` exclusif en `0600` (aucune autre clé possible sur ce compte).
  - `kubernetes.yml` (inclus si `deploiement_k8s`) : namespaces `prod`, `preprod` ; `ResourceQuota` `preprod`
    (`limits.memory: {{ preprod_quota_memoire_limites }}`) ; par namespace : `ServiceAccount deploy`, `Role`
    (règles de `deploiement_role_regles` : Secrets, ConfigMaps, Services, ServiceAccounts, PVC, Pods et journaux en
    lecture, Deployments, StatefulSets, Jobs, CronJobs, Ingress, NetworkPolicies, Roles et RoleBindings du namespace,
    `postgresql.cnpg.io` (clusters, backups, scheduledbackups), `barmancloud.cnpg.io` (objectstores), certificats
    en lecture ; **aucun** `resourcequotas`, `namespaces`, ClusterRole), `RoleBinding`, Secret
    `kubernetes.io/service-account-token` (jeton longue durée du ServiceAccount) ; kubeconfig généré avec l'adresse
    `https://127.0.0.1:6443`, l'autorité de certification du serveur et le jeton lu avec `no_log: true`, écrit en
    `0600` ; **jamais** `/etc/rancher/k3s/k3s.yaml`. Application de `rbac.yaml.j2` par `kubectl apply -f -`, avec
    `changed_when` fondé sur la sortie (`created`/`configured`).
  - Test d'autorisation (à écrire dans la documentation, tâche 8, car non exécutable ici) : `kubectl auth can-i
    --list --kubeconfig /home/deploy/.kube/<env>` ne montre que le namespace, et `auth can-i create clusterroles` →
    `no`.
- [ ] **Étape 3** : `make infra-test` vert (volet utilisateur, deux passages) ; `make infra-lint` vert ; cocher
  l'Avancement ; commit d'une ligne. Rapport : « volet Kubernetes non testé sur un cluster réel ».

---

### Tâche 8 : documentation `docs/v1/infra/serveur.md`

**Fichiers :**
- Créer : `docs/v1/infra/serveur.md`

**Interfaces :**
- Consomme : tout ce qui précède ; `make ports-scan`, `make secrets-definir` (lecture seule).
- Produit : procédure de mise en place, en français avec accents.

- [ ] **Étape 1** : test d'abord : lister dans l'en-tête de la tâche les commandes citées par la doc ; vérifier à la
  fin que chacune existe (`make help`) et que chaque variable citée existe dans `group_vars/all.yml` ou
  `inventory.example.yml`.
- [ ] **Étape 2** : rédiger. Sections : vue d'ensemble (rôles, ce qui est testé localement et ce qui ne l'est pas) ;
  prérequis (Docker, agent SSH chargé : `ssh-add -l`, `known_hosts`) ; **réinstallation de A chez Contabo** (console,
  Ubuntu 24.04, injection de la clé publique, **tout est effacé**, même IP, empreinte SSH relevée dans la console et
  comparée au premier `ssh`) ; création de l'inventaire (`cp inventory.example.yml inventory.yml`, `admin_users`,
  `letsencrypt_email`) ; génération des **deux** clés de déploiement (`ssh-keygen -t ed25519`, une par environnement,
  clés publiques dans l'inventaire, clés privées dans `DEPLOY_SSH_KEY` de chaque environnement GitHub via
  `make secrets-definir`, `DEPLOY_HOST` et `DEPLOY_KNOWN_HOSTS`) ; **premier passage** en `root` puis bascule de
  `ansible_user` sur le compte administrateur ; `make infra-ansible LIMITE=noeuds` ; vérifications (`make ports-scan
  HOTE=<A>` → 22, 80, 443 ; `ssh -o PreferredAuthentications=password` refusé ; `sudo k3s kubectl get nodes` ;
  `auth can-i` du compte `deploy` ; `deploy` sans commande refusé) ; **ajout du nœud B** (réinstaller B en 24.04 :
  ses données sont effacées, l'ajouter au groupe `agents`, rejouer **`LIMITE=noeuds`** pour mettre à jour ufw sur A,
  `kubectl get nodes`, préciser que le plan de contrôle reste unique) ; retrait d'un administrateur (retirer de
  `admin_users`, rejouer : compte supprimé) ; rotation d'une clé de déploiement ; montée de version (`group_vars`,
  `make infra-vendre`, rejouer) ; dépannage (SSH coupé : console Contabo ; `--check --diff` via `ARGS`) ; limites
  connues (un seul nœud de contrôle, `flannel-backend` fixé à l'installation, k3s non testé en conteneur).
- [ ] **Étape 3** : relire, vérifier la liste de l'étape 1 ; `make secrets-scan` à zéro ; cocher l'Avancement ;
  commit d'une ligne.

---

### Tâche 9 : vérification du lot

**Fichiers :** aucun nouveau (corrections éventuelles dans les fichiers du lot).

- [ ] `make infra-lint` vert (ansible-lint, `--syntax-check`, SHA-256 des manifestes, options k3s obligatoires).
- [ ] `make infra-test-assert` et `make infra-test` verts (assert d'échec ; `base` et volet utilisateur de
  `deploiement` sur Ubuntu 24.04 jetable : deux passages, second à `changed=0`, vérifications sshd, ufw, `deploy`,
  `authorized_keys`, suppression du compte absent) ; pas de conteneur ni de réseau restants (`docker ps -a`,
  `docker network ls`).
- [ ] Rien d'appliqué par URL distante : `grep` en conteneur des `http(s)://` dans `roles/` hors `get_url` de k3s
  et de Helm (tous deux avec somme SHA-256) ; aucune clé privée, aucun e-mail dans les fichiers versionnés ;
  `make secrets-scan` à zéro.
- [ ] `git check-ignore infra/ansible/inventory.yml` répond ; `git status` ne montre ni `inventory.yml` ni
  `.travail/`.
- [ ] Tests ciblés / `lint` / `typecheck` / `coverage-diff` / `migrations-check` / e2e du projet : **sans objet**
  (aucun code applicatif touché) ; la couverture est celle de `infra-test` (voir Contraintes globales).
- [ ] Périmètre : `make devteam-perimetre LOT=ansible PLAN=docs/v1/plans/k3s-ansible/5-ansible.md
  BASE=origin/feature/k3s-ansible` ; attendu : « Périmètre OK » (une ligne `HORS PÉRIMÈTRE` est corrigée ou
  signalée, jamais le plan modifié pour la faire disparaître).
- [ ] Rapport final : `Statut: DONE|PARTIAL|BLOCKED`, tâches, commits, commandes et résultats ; **dire** que k3s, la
  plateforme et le volet Kubernetes de `deploiement` ne sont pas testés localement ; remonter le point de revue 1
  (commande forcée par environnement) et le point 3 (ResourceQuota).
