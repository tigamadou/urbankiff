import json
import os
import tempfile
from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase, TestCase

from apps.user.factories import UserFactory
from apps.user.management.commands.anonymiser import REGLES_PAR_DEFAUT, charger_regles
from apps.user.models import User

REGLES_VIDES = {
    "version": 1,
    "motifs_suspects": [],
    "tables_a_vider": [],
    "tables_classees": {},
    "sans_donnees_personnelles": {},
}


def ecrire_regles(testcase, contenu):
    fichier = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
    testcase.addCleanup(os.unlink, fichier.name)
    with fichier:
        fichier.write(contenu if isinstance(contenu, str) else json.dumps(contenu))
    return fichier.name


def environnement(**valeurs):
    base = {k: v for k, v in os.environ.items() if k not in ("ANONYMISATION_AUTORISEE", "POSTGRES_HOST")}
    base.update(valeurs)
    return mock.patch.dict(os.environ, base, clear=True)


class GardeFouEnvironnementTests(TestCase):
    def setUp(self):
        self.utilisateur = UserFactory(email="origine@exemple.org")
        self.regles = ecrire_regles(self, REGLES_VIDES)

    def lancer(self):
        call_command("anonymiser", regles=self.regles, stdout=StringIO())

    def assert_refus(self, **valeurs):
        with environnement(**valeurs):
            with self.assertRaises(CommandError) as ctx:
                self.lancer()
        self.assertEqual(ctx.exception.returncode, 2)
        self.utilisateur.refresh_from_db()
        self.assertEqual(self.utilisateur.email, "origine@exemple.org")

    def test_variable_absente(self):
        self.assert_refus(POSTGRES_HOST="127.0.0.1")

    def test_valeur_zero(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="0", POSTGRES_HOST="127.0.0.1")

    def test_valeur_true(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="true", POSTGRES_HOST="127.0.0.1")

    def test_hote_compose(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST="postgresDB")

    def test_hote_distant(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST="db.prod.example")

    def test_hote_absent(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="1")

    def test_hote_avec_prefixe_trompeur(self):
        self.assert_refus(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST="127.0.0.1.evil.example")

    def test_refus_avant_chargement_des_regles(self):
        with environnement(POSTGRES_HOST="postgresDB"):
            with self.assertRaises(CommandError) as ctx:
                call_command("anonymiser", regles="/inexistant/regles.json", stdout=StringIO())
        self.assertEqual(ctx.exception.returncode, 2)

    def test_adresses_locales_acceptees(self):
        for hote in ("127.0.0.1", "localhost"):
            with environnement(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST=hote):
                self.lancer()


class ChargementReglesTests(SimpleTestCase):
    def regles(self, **modifs):
        contenu = dict(REGLES_VIDES)
        contenu.update(modifs)
        return ecrire_regles(self, contenu)

    def assert_invalide(self, chemin):
        with self.assertRaises(CommandError) as ctx:
            charger_regles(chemin)
        self.assertEqual(ctx.exception.returncode, 1)

    def test_fichier_livre_valide(self):
        self.assertEqual(charger_regles(REGLES_PAR_DEFAUT)["version"], 1)

    def test_fichier_introuvable(self):
        self.assert_invalide("/inexistant/regles.json")

    def test_json_illisible(self):
        self.assert_invalide(ecrire_regles(self, "{pas du json"))

    def test_racine_pas_un_objet(self):
        self.assert_invalide(ecrire_regles(self, "[]"))

    def test_cle_obligatoire_absente(self):
        contenu = dict(REGLES_VIDES)
        del contenu["tables_a_vider"]
        self.assert_invalide(ecrire_regles(self, contenu))

    def test_version_inconnue(self):
        self.assert_invalide(self.regles(version=2))

    def test_traitement_inconnu(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "magie"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_action_inconnue(self):
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": {"x": {"action": "jeter"}}}}))

    def test_texte_par_id_sans_motif(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "texte_par_id", "modele": "fixe"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_nombre_par_id_sans_base(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "nombre_par_id"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_nombre_par_id_base_non_entiere(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "nombre_par_id", "base": "a"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_aleatoire_sans_prefixe(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "aleatoire"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_valeur_fixe_sans_valeur(self):
        colonnes = {"x": {"action": "anonymiser", "traitement": "valeur_fixe"}}
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": colonnes}}))

    def test_anonymiser_sans_traitement(self):
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": {"x": {"action": "anonymiser"}}}}))

    def test_table_classee_sans_colonnes(self):
        self.assert_invalide(self.regles(tables_classees={"t": {}}))

    def test_table_dans_deux_sections(self):
        self.assert_invalide(self.regles(
            tables_a_vider=["t"], tables_classees={"t": {"colonnes": {"id": {"action": "garder"}}}}))
        self.assert_invalide(self.regles(tables_a_vider=["t"], sans_donnees_personnelles={"t": {}}))
        self.assert_invalide(self.regles(
            tables_classees={"t": {"colonnes": {"id": {"action": "garder"}}}}, sans_donnees_personnelles={"t": {}}))

    def test_sections_mal_typees(self):
        self.assert_invalide(self.regles(tables_a_vider="t"))
        self.assert_invalide(self.regles(motifs_suspects="email"))
        self.assert_invalide(self.regles(sans_donnees_personnelles={"t": []}))
        self.assert_invalide(self.regles(tables_classees={"t": []}))
        self.assert_invalide(self.regles(tables_classees={"t": {"colonnes": {"x": []}}}))

    def test_regles_valides_de_chaque_traitement(self):
        colonnes = {
            "id": {"action": "garder"},
            "a": {"action": "anonymiser", "traitement": "texte_par_id", "modele": "u-{id}"},
            "b": {"action": "anonymiser", "traitement": "nombre_par_id", "base": 5},
            "c": {"action": "anonymiser", "traitement": "aleatoire", "prefixe": "!"},
            "d": {"action": "anonymiser", "traitement": "valeur_fixe", "valeur": None},
        }
        regles = charger_regles(self.regles(tables_classees={"t": {"colonnes": colonnes}}))
        self.assertEqual(regles["tables_classees"]["t"]["cle"], "id")
