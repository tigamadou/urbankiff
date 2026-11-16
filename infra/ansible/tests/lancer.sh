#!/bin/sh
# Joue base et le volet utilisateur de deploiement sur un conteneur Ubuntu 24.04 jetable :
# passage 1 (root, changements), passage 2 (administrateur, zéro changement), puis vérifications.
# Lancé par `make infra-test` ; seul docker est requis. IMAGE_ANSIBLE : image construite par `make infra-image`.
set -eu

: "${IMAGE_ANSIBLE:?IMAGE_ANSIBLE requis}"
racine=$(cd "$(dirname "$0")/../../.." && pwd)
travail="$racine/infra/ansible/.travail"
id="infra-test-$$"
reseau="$id"
cible="$id-cible"

nettoyer() {
    docker rm -f "$cible" >/dev/null 2>&1 || true
    docker network rm "$reseau" >/dev/null 2>&1 || true
    docker run --rm -u 0 -v "$travail":/travail "$IMAGE_ANSIBLE" sh -c 'rm -rf /travail/* /travail/.[!.]*' >/dev/null 2>&1 || true
}
trap nettoyer EXIT INT TERM

mkdir -p "$travail"
docker build -q -t urbankiff-infra-cible -f "$racine/infra/ansible/tests/Dockerfile.cible" "$racine/infra/ansible/tests" >/dev/null

# Clés éphémères : administrateur de test et une clé par environnement de déploiement
docker run --rm -u 0 -v "$travail":/travail "$IMAGE_ANSIBLE" sh -c '
    for k in admin preprod prod; do ssh-keygen -q -t ed25519 -N "" -C "" -f /travail/id_$k; done
    {
        echo "admin_users:"
        echo "  - name: testadmin"
        echo "    pubkey: \"$(cut -d" " -f1,2 /travail/id_admin.pub)\""
        echo "deploy_keys:"
        echo "  preprod: \"$(cut -d" " -f1,2 /travail/id_preprod.pub)\""
        echo "  prod: \"$(cut -d" " -f1,2 /travail/id_prod.pub)\""
        echo "letsencrypt_email: test@example.invalid"
    } > /travail/vars.yml
    chmod 600 /travail/id_admin /travail/id_preprod /travail/id_prod'

docker network create "$reseau" >/dev/null
lancer_cible() {
    docker run -d --name "$cible" --network "$reseau" --hostname cible "$@" urbankiff-infra-cible
}
lancer_cible --cap-add NET_ADMIN --cap-add SYS_ADMIN --tmpfs /run --tmpfs /tmp --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw >/dev/null

# Attente de systemd puis de sshd
i=0
until docker exec "$cible" systemctl is-system-running --wait 2>/dev/null | grep -Eq 'running|degraded'; do
    i=$((i + 1))
    [ "$i" -le 30 ] || { echo "systemd ne démarre pas dans la cible" >&2; docker logs "$cible" | tail -20 >&2; exit 1; }
    sleep 1
done
docker cp "$travail/id_admin.pub" "$cible":/root/.ssh/authorized_keys
docker exec "$cible" sh -c 'chown root:root /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && useradd -m -u 1500 ancien && systemctl start ssh'
ip=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$reseau\").IPAddress}}" "$cible")

ansible() {
    docker run --rm -u 0 --network "$reseau" -v "$racine":/repo:ro -v "$travail":/travail \
        -e ANSIBLE_HOME=/tmp/ansible -e ANSIBLE_HOST_KEY_CHECKING=False \
        -e ANSIBLE_PRIVATE_KEY_FILE=/travail/id_admin "$IMAGE_ANSIBLE" \
        ansible-playbook -i tests/inventaire-test.yml -e "ansible_host=$ip" "$@"
}

echo "== Passage 1 (root, changements attendus)"
ansible -e ansible_user=root tests/site-test.yml

echo "== Passage 2 (administrateur, zéro changement attendu)"
ansible -e ansible_user=testadmin tests/site-test.yml > "$travail/passage2.log" 2>&1 || { cat "$travail/passage2.log"; exit 1; }
cat "$travail/passage2.log"
grep -Eq "changed=0 +unreachable=0 +failed=0" "$travail/passage2.log" || { echo "Le second passage a changé quelque chose" >&2; exit 1; }

echo "== Vérifications"
ansible -e ansible_user=testadmin tests/verifier.yml
echo "Tous les contrôles passent."
