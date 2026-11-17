import json
import os

from django.core.management.base import BaseCommand, CommandError
from django.db import IntegrityError, connection, transaction

REGLES_PAR_DEFAUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                                 "regles_anonymisation.json")
HOTES_LOCAUX = ("127.0.0.1", "localhost")
CLES_OBLIGATOIRES = ("version", "motifs_suspects", "tables_a_vider", "tables_classees", "sans_donnees_personnelles")
TRAITEMENTS = ("texte_par_id", "nombre_par_id", "aleatoire", "valeur_fixe")


def verifier_environnement():
    if os.environ.get("ANONYMISATION_AUTORISEE") != "1" or os.environ.get("POSTGRES_HOST") not in HOTES_LOCAUX:
        raise CommandError(
            "anonymiser refuse de tourner : ANONYMISATION_AUTORISEE=1 et POSTGRES_HOST local "
            "(127.0.0.1 ou localhost) sont exigés", returncode=2)


def invalide(message):
    return CommandError("règles d'anonymisation invalides : " + message, returncode=1)


def verifier_colonne(table, colonne, regle):
    ou = "%s.%s" % (table, colonne)
    if not isinstance(regle, dict):
        raise invalide("%s doit être un objet" % ou)
    action = regle.get("action")
    if action == "garder":
        return
    if action != "anonymiser":
        raise invalide("%s : action inconnue" % ou)
    traitement = regle.get("traitement")
    if traitement not in TRAITEMENTS:
        raise invalide("%s : traitement inconnu ou absent" % ou)
    if traitement == "texte_par_id" and "{id}" not in str(regle.get("modele", "")):
        raise invalide("%s : texte_par_id exige un modele contenant {id}" % ou)
    if traitement == "nombre_par_id" and (not isinstance(regle.get("base"), int) or isinstance(regle["base"], bool)):
        raise invalide("%s : nombre_par_id exige une base entière" % ou)
    if traitement == "aleatoire" and not isinstance(regle.get("prefixe"), str):
        raise invalide("%s : aleatoire exige un prefixe" % ou)
    if traitement == "valeur_fixe" and "valeur" not in regle:
        raise invalide("%s : valeur_fixe exige une valeur" % ou)


def charger_regles(chemin):
    try:
        with open(chemin, encoding="utf-8") as fichier:
            regles = json.load(fichier)
    except (OSError, ValueError) as erreur:
        raise invalide("fichier illisible (%s)" % erreur.__class__.__name__)
    if not isinstance(regles, dict):
        raise invalide("la racine doit être un objet")
    for cle in CLES_OBLIGATOIRES:
        if cle not in regles:
            raise invalide("clé obligatoire absente : %s" % cle)
    if regles["version"] != 1:
        raise invalide("version non gérée")
    if not isinstance(regles["motifs_suspects"], list) or not isinstance(regles["tables_a_vider"], list):
        raise invalide("motifs_suspects et tables_a_vider doivent être des listes")
    if not isinstance(regles["tables_classees"], dict) or not isinstance(regles["sans_donnees_personnelles"], dict):
        raise invalide("tables_classees et sans_donnees_personnelles doivent être des objets")
    for table, contenu in regles["sans_donnees_personnelles"].items():
        if not isinstance(contenu, dict):
            raise invalide("%s : les colonnes justifiées doivent former un objet" % table)
    for table, contenu in regles["tables_classees"].items():
        if not isinstance(contenu, dict) or not isinstance(contenu.get("colonnes"), dict):
            raise invalide("%s : colonnes obligatoires" % table)
        contenu.setdefault("cle", "id")
        for colonne, regle in contenu["colonnes"].items():
            verifier_colonne(table, colonne, regle)
    sections = [set(regles["tables_a_vider"]), set(regles["tables_classees"]),
                set(regles["sans_donnees_personnelles"])]
    if len(regles["tables_a_vider"]) != len(sections[0]) or \
            sum(len(s) for s in sections) != len(sections[0] | sections[1] | sections[2]):
        raise invalide("une table figure dans plusieurs sections")
    return regles


def expression_et_parametres(regle, cle):
    traitement = regle["traitement"]
    if traitement == "texte_par_id":
        morceaux = regle["modele"].split("{id}")
        parties = ["%s::text"]
        for _ in morceaux[1:]:
            parties += [cle + "::text", "%s::text"]
        return " || ".join(parties), morceaux
    if traitement == "nombre_par_id":
        return "%s::bigint + " + cle, [regle["base"]]
    if traitement == "aleatoire":
        return "%s::text || md5(random()::text || " + cle + "::text)", [regle["prefixe"]]
    valeur = regle["valeur"]
    if isinstance(valeur, (dict, list)):
        valeur = json.dumps(valeur)
    return "%s", [valeur]


def appliquer(regles, stdout):
    quote = connection.ops.quote_name
    try:
        with transaction.atomic():
            with connection.cursor() as curseur:
                for table in regles["tables_a_vider"]:
                    curseur.execute("DELETE FROM " + quote(table))
                    stdout.write("anonymiser : %s : %d ligne(s) supprimée(s)" % (table, curseur.rowcount))
                for table, contenu in regles["tables_classees"].items():
                    cle = quote(contenu["cle"])
                    for colonne, regle in contenu["colonnes"].items():
                        if regle["action"] != "anonymiser":
                            continue
                        expression, parametres = expression_et_parametres(regle, cle)
                        curseur.execute("UPDATE %s SET %s = %s" % (quote(table), quote(colonne), expression),
                                        parametres)
                        stdout.write("anonymiser : %s.%s : %d ligne(s)" % (table, colonne, curseur.rowcount))
                curseur.execute("SET CONSTRAINTS ALL IMMEDIATE")
    except IntegrityError:
        raise CommandError("anonymisation annulée : une contrainte d'intégrité n'est pas respectée", returncode=1)
    stdout.write("anonymisation terminée")


class Command(BaseCommand):
    help = "Remplace les données de personnes d'une base locale et jetable par des valeurs factices"

    def add_arguments(self, parser):
        parser.add_argument("--regles", default=REGLES_PAR_DEFAUT, help="fichier de règles (défaut : celui livré)")

    def handle(self, *args, **options):
        verifier_environnement()
        appliquer(charger_regles(options["regles"]), self.stdout)
