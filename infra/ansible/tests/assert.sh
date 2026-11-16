#!/bin/sh
# Prouve que site.yml s'arrête sur l'assert pour chaque inventaire invalide (seuls les assert sont joués).
# Lancé dans le conteneur Ansible par `make infra-test-assert`.
set -u
cd "$(dirname "$0")/.." || exit 1
echec=0

jouer() { # inventaire limite
    ANSIBLE_ROLES_PATH=/nonexistent ansible-playbook -i "tests/$1" site.yml --tags assertions --limit "$2" -e ansible_become=false 2>&1
}

attendre_echec() { # inventaire limite motif
    sortie=$(jouer "$1" "$2")
    if [ $? -ne 0 ] && printf '%s' "$sortie" | grep -q "$3"; then
        echo "ok   $2 : refusé ($3)"
    else
        echo "ECHEC $2 : l'assert aurait dû refuser ($3)"; printf '%s\n' "$sortie" | tail -15; echec=1
    fi
}

sortie=$(jouer inventaire-invalide.yml valide) || { echo "ECHEC témoin valide refusé"; printf '%s\n' "$sortie" | tail -15; echec=1; }
[ $echec -eq 0 ] && echo "ok   valide : accepté"

attendre_echec inventaire-invalide.yml cle_avec_email "sans adresse e-mail"
attendre_echec inventaire-invalide.yml admin_vide "admin_users"
attendre_echec inventaire-invalide.yml utilisateur_inconnu "ansible_user doit être root"
attendre_echec inventaire-invalide.yml email_absent "letsencrypt_email"
attendre_echec inventaire-invalide.yml cles_identiques "deploy_keys"
attendre_echec inventaire-deux-serveurs.yml a "Exactement un hôte"
attendre_echec inventaire-hote-orphelin.yml a "Exactement un hôte"
exit $echec
