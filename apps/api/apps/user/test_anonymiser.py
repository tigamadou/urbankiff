import json
import os
import tempfile
from io import StringIO
from unittest import mock

from django.contrib.sessions.models import Session
from datetime import date, timedelta

from django.apps import apps as registre_apps
from django.contrib.admin.models import ADDITION, LogEntry
from django.contrib.contenttypes.models import ContentType
from django.utils import timezone
from oauth2_provider.models import AccessToken, Application, RefreshToken
from push_notifications.models import GCMDevice
from rest_framework.authtoken.models import Token
from rest_framework_tracking.models import APIRequestLog
from rolepermissions.roles import assign_role
from social_django.models import UserSocialAuth

from apps.category.models import Category
from apps.comment.models import Comment, Report
from apps.error.models import Error
from apps.file.models import File
from apps.mail.models import OTP, Mail
from apps.post.models import Post, PostView
from apps.user.models import Device, PasswordResetToken
from apps.workers.models import Task
from django.core.management import call_command
from django.db import connection
from django.core.management.base import CommandError, OutputWrapper
from django.test import SimpleTestCase, TestCase

from apps.user.factories import UserFactory
from apps.user.management.commands.anonymiser import (
    REGLES_PAR_DEFAUT, appliquer, charger_regles, est_suspecte, lire_schema, verifier_classement)
from apps.user.models import Invitation, User

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


MOTIFS = ["email", "contact", "name", "ip", "addr", "token", "password"]


def regles_de_test(vider=(), classees=None):
    schema = lire_schema(connection)
    classees = classees or {}
    regles = dict(REGLES_VIDES, motifs_suspects=MOTIFS, tables_a_vider=list(vider), tables_classees={})
    for table, contenu in classees.items():
        colonnes = {c: dict(contenu.get(c, {"action": "garder"})) for c in schema[table]}
        for regle in colonnes.values():
            if regle["action"] == "garder":
                regle["justification"] = "test"
        regles["tables_classees"][table] = {"cle": "id", "colonnes": colonnes}
    regles["sans_donnees_personnelles"] = {
        table: {c: "test" for c in colonnes if est_suspecte(c, MOTIFS)}
        for table, colonnes in schema.items() if table not in vider and table not in classees}
    return regles


def environnement(**valeurs):
    base = {k: v for k, v in os.environ.items() if k not in ("ANONYMISATION_AUTORISEE", "POSTGRES_HOST")}
    base.update(valeurs)
    return mock.patch.dict(os.environ, base, clear=True)


class GardeFouEnvironnementTests(TestCase):
    def setUp(self):
        self.utilisateur = UserFactory(email="origine@exemple.org")
        self.regles = ecrire_regles(self, regles_de_test())

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


def regles_moteur(vider=(), classees=None):
    regles = dict(REGLES_VIDES)
    regles["tables_a_vider"] = list(vider)
    regles["tables_classees"] = classees or {}
    return regles


def table_user(**colonnes):
    return {"user_user": {"cle": "id", "colonnes": {
        nom: (regle if isinstance(regle, dict) else {"action": "garder"}) for nom, regle in colonnes.items()}}}


def anonymiser_colonne(traitement, **parametres):
    return dict({"action": "anonymiser", "traitement": traitement}, **parametres)


def appliquer_regles(regles):
    sortie = StringIO()
    appliquer(charger_regles_dict(regles), OutputWrapper(sortie))
    return sortie.getvalue()


def charger_regles_dict(regles):
    fichier = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
    with fichier:
        json.dump(regles, fichier)
    try:
        return charger_regles(fichier.name)
    finally:
        os.unlink(fichier.name)


class MoteurTests(TestCase):
    def setUp(self):
        self.a = UserFactory(email="a@vrai.org", username="ua", firstname="Alice", contact=221, birthday="1990-05-17")
        self.b = UserFactory(email="b@vrai.org", username="ub", firstname="Bob", contact=222)
        for utilisateur in (self.a, self.b):
            utilisateur.set_password("secret-%s" % utilisateur.username)
            utilisateur.save()

    def test_texte_par_id_unicite_respectee(self):
        regles = regles_moteur(classees=table_user(
            id=1,
            email=anonymiser_colonne("texte_par_id", modele="user-{id}@exemple.invalid"),
            firstname=anonymiser_colonne("texte_par_id", modele="Prenom{id}"),
            username=anonymiser_colonne("texte_par_id", modele="u-{id}-{id}")))
        appliquer_regles(regles)
        self.a.refresh_from_db()
        self.b.refresh_from_db()
        self.assertEqual(self.a.email, "user-%d@exemple.invalid" % self.a.id)
        self.assertEqual(self.b.firstname, "Prenom%d" % self.b.id)
        self.assertEqual(self.a.username, "u-%d-%d" % (self.a.id, self.a.id))
        self.assertNotEqual(self.a.email, self.b.email)

    def test_nombre_par_id(self):
        appliquer_regles(regles_moteur(classees=table_user(
            id=1, contact=anonymiser_colonne("nombre_par_id", base=99000000000))))
        self.a.refresh_from_db()
        self.assertEqual(self.a.contact, 99000000000 + self.a.id)

    def test_aleatoire_mot_de_passe_inutilisable(self):
        appliquer_regles(regles_moteur(classees=table_user(
            id=1, password=anonymiser_colonne("aleatoire", prefixe="!"))))
        self.a.refresh_from_db()
        self.b.refresh_from_db()
        self.assertTrue(self.a.password.startswith("!"))
        self.assertNotEqual(self.a.password, self.b.password)
        self.assertFalse(self.a.has_usable_password())
        self.assertFalse(self.a.check_password("secret-ua"))

    def test_valeur_fixe_null_chaine_et_json(self):
        appliquer_regles(regles_moteur(classees=table_user(
            id=1,
            birthday=anonymiser_colonne("valeur_fixe", valeur=None),
            bio=anonymiser_colonne("valeur_fixe", valeur=""),
            address=anonymiser_colonne("valeur_fixe", valeur={"a": 1}),
            nationality=anonymiser_colonne("valeur_fixe", valeur="192.0.2.1"))))
        self.a.refresh_from_db()
        self.assertIsNone(self.a.birthday)
        self.assertEqual(self.a.bio, "")
        self.assertEqual(self.a.address, '{"a": 1}')
        self.assertEqual(self.a.nationality, "192.0.2.1")

    def test_colonne_gardee_et_lignes_inchangees(self):
        appliquer_regles(regles_moteur(classees=table_user(
            id=1, firstname=1, contact=anonymiser_colonne("valeur_fixe", valeur=None))))
        self.a.refresh_from_db()
        self.assertEqual(self.a.firstname, "Alice")
        self.assertEqual(User.objects.count(), 2)

    def test_table_videe_et_cles_etrangeres_intactes(self):
        Session.objects.create(session_key="k", session_data="d", expire_date="2099-01-01T00:00:00Z")
        invitation = Invitation.objects.create(inviter=self.a, invitee_email="x@vrai.org")
        appliquer_regles(regles_moteur(vider=["django_session"], classees=table_user(
            id=1, email=anonymiser_colonne("texte_par_id", modele="user-{id}@exemple.invalid"))))
        self.assertEqual(Session.objects.count(), 0)
        invitation.refresh_from_db()
        self.assertEqual(invitation.inviter, self.a)

    def test_journal_sans_valeur_d_origine(self):
        Session.objects.create(session_key="k", session_data="d", expire_date="2099-01-01T00:00:00Z")
        journal = appliquer_regles(regles_moteur(vider=["django_session"], classees=table_user(
            id=1, email=anonymiser_colonne("texte_par_id", modele="user-{id}@exemple.invalid"))))
        self.assertEqual(journal.splitlines(), [
            "anonymiser : django_session : 1 ligne(s) supprimée(s)",
            "anonymiser : user_user.email : 2 ligne(s)",
            "anonymisation terminée",
        ])
        self.assertNotIn("vrai.org", journal)

    def test_idempotence_des_valeurs_par_identifiant(self):
        regles = regles_moteur(classees=table_user(
            id=1, email=anonymiser_colonne("texte_par_id", modele="user-{id}@exemple.invalid"),
            contact=anonymiser_colonne("nombre_par_id", base=7)))
        appliquer_regles(regles)
        premier = list(User.objects.order_by("id").values_list("email", "contact"))
        appliquer_regles(regles)
        self.assertEqual(list(User.objects.order_by("id").values_list("email", "contact")), premier)

    def test_violation_d_integrite_annule_tout(self):
        Invitation.objects.create(inviter=self.a, invitee_email="x@vrai.org")
        regles = regles_moteur(vider=["user_user"], classees={"post_tag": {"colonnes": {"id": {"action": "garder"}}}})
        with self.assertRaises(CommandError) as ctx:
            appliquer_regles(regles)
        self.assertEqual(ctx.exception.returncode, 1)
        self.assertTrue(User.objects.filter(email="a@vrai.org").exists())


def schema_synthetique():
    return {"t": ["id", "email", "titre"], "autre": ["id", "titre"]}


def regles_synthetiques(**modifs):
    regles = dict(REGLES_VIDES, motifs_suspects=["email", "phone", "ip", "addr", "contact", "name"])
    regles["tables_classees"] = {"t": {"cle": "id", "colonnes": {
        "id": {"action": "garder"},
        "email": {"action": "anonymiser", "traitement": "valeur_fixe", "valeur": None},
        "titre": {"action": "garder"}}}}
    regles["sans_donnees_personnelles"] = {"autre": {}}
    regles.update(modifs)
    return regles


class VerifierClassementTests(SimpleTestCase):
    def test_schema_complet(self):
        self.assertEqual(verifier_classement(regles_synthetiques(), schema_synthetique()), [])

    def test_colonne_non_classee(self):
        schema = schema_synthetique()
        schema["t"].append("phone")
        self.assertEqual(verifier_classement(regles_synthetiques(), schema), ["colonne non classée : t.phone"])

    def test_table_nouvelle_non_classee(self):
        schema = dict(schema_synthetique(), nouvelle_table=["id", "email"])
        self.assertEqual(verifier_classement(regles_synthetiques(), schema), ["table non classée : nouvelle_table"])
        schema["nouvelle_table"] = ["id", "titre"]
        self.assertEqual(verifier_classement(regles_synthetiques(), schema), ["table non classée : nouvelle_table"])

    def test_colonne_suspecte_sans_donnees_personnelles(self):
        schema = dict(schema_synthetique(), autre=["id", "contact_name"])
        self.assertEqual(verifier_classement(regles_synthetiques(), schema),
                         ["colonne suspecte sans justification : autre.contact_name"])
        regles = regles_synthetiques(sans_donnees_personnelles={"autre": {"contact_name": "nom de rubrique"}})
        self.assertEqual(verifier_classement(regles, schema), [])
        regles = regles_synthetiques(sans_donnees_personnelles={"autre": {"contact_name": "  "}})
        self.assertEqual(len(verifier_classement(regles, schema)), 1)

    def test_colonne_suspecte_gardee_sans_justification(self):
        schema = schema_synthetique()
        schema["t"].append("ip_address")
        regles = regles_synthetiques()
        regles["tables_classees"]["t"]["colonnes"]["ip_address"] = {"action": "garder"}
        self.assertEqual(verifier_classement(regles, schema),
                         ["colonne suspecte gardée sans justification : t.ip_address"])
        regles["tables_classees"]["t"]["colonnes"]["ip_address"]["justification"] = "adresse du serveur"
        self.assertEqual(verifier_classement(regles, schema), [])

    def test_regles_perimees(self):
        regles = regles_synthetiques(tables_a_vider=["disparue"])
        regles["tables_classees"]["t"]["colonnes"]["phone"] = {"action": "garder"}
        self.assertEqual(verifier_classement(regles, schema_synthetique()), [
            "règle périmée, la table n'existe plus : disparue",
            "règle périmée, la colonne n'existe plus : t.phone",
        ])

    def test_detection_par_mot(self):
        motifs = ["ip", "addr"]
        self.assertFalse(est_suspecte("description", motifs))
        self.assertTrue(est_suspecte("ip_address", motifs))
        self.assertTrue(est_suspecte("remote_addr", motifs))


class ClassementReelTests(TestCase):
    def test_table_non_classee_signalee_et_commande_en_echec(self):
        utilisateur = UserFactory(email="origine@exemple.org")
        with connection.cursor() as curseur:
            curseur.execute("CREATE TABLE zz_nouvelle (id serial, email varchar(50))")
        regles = regles_de_test()
        del regles["sans_donnees_personnelles"]["zz_nouvelle"]
        self.assertEqual([p for p in verifier_classement(regles, lire_schema(connection)) if "zz_" in p],
                         ["table non classée : zz_nouvelle"])
        chemin = ecrire_regles(self, regles)
        with environnement(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST="localhost"):
            with self.assertRaises(CommandError) as ctx:
                call_command("anonymiser", regles=chemin, stdout=StringIO())
        self.assertEqual(ctx.exception.returncode, 1)
        self.assertIn("zz_nouvelle", str(ctx.exception))
        utilisateur.refresh_from_db()
        self.assertEqual(utilisateur.email, "origine@exemple.org")


class ReglesLivreesTests(TestCase):
    def test_le_vrai_schema_est_entierement_classe(self):
        regles = charger_regles(REGLES_PAR_DEFAUT)
        self.assertEqual(verifier_classement(regles, lire_schema(connection)), [])

    def test_tables_des_applications_locales_classees(self):
        regles = charger_regles(REGLES_PAR_DEFAUT)
        classees = set(regles["tables_a_vider"]) | set(regles["tables_classees"]) | set(
            regles["sans_donnees_personnelles"])
        locales = {modele._meta.db_table for modele in registre_apps.get_models(include_auto_created=True)
                   if modele._meta.app_label in {"file", "mail", "user", "workers", "category", "menu", "post",
                                                 "page", "error", "comment", "twilio", "like", "scrapper", "banner"}}
        self.assertEqual(locales - classees, set())
        schema = lire_schema(connection)
        for table in set(regles["tables_a_vider"]) | set(regles["tables_classees"]):
            self.assertIn(table, schema)


VALEURS_INTERDITES = ["sentinelle", "vrai-domaine", "22998877665", "203.0.113.7", "1990-05-17"]
MOT_DE_PASSE = "sentinelle-mot-de-passe"


def creer_jeu_de_sentinelles():
    maintenant = timezone.now()
    jeu = {}
    jeu["utilisateur"] = utilisateur = UserFactory(
        email="sentinelle.1@vrai-domaine.org", contact=22998877665, firstname="sentinelle-prenom",
        lastname="sentinelle-nom", username="sentinelle-login", bio="sentinelle bio", address="sentinelle adresse",
        birthday=date(1990, 5, 17), id_img="uploads/sentinelle-piece.jpg", nationality="sentinelle",
        residence_country="sentinelle", avatar="uploads/sentinelle-avatar.jpg", status="active")
    utilisateur.set_password(MOT_DE_PASSE)
    utilisateur.save()
    jeu["admin"] = admin = UserFactory(
        email="urbankiff@admin.com", username="sentinelle-admin", is_superuser=True, is_staff=True)
    admin.set_password(MOT_DE_PASSE)
    admin.save()
    assign_role(admin, "administrator")
    utilisateur.devices.add(Device.objects.create(registration_id="sentinelle-appareil"))
    PasswordResetToken.objects.create(user=utilisateur, token="sentinelle-reinit")
    Invitation.objects.create(inviter=admin, invitee_email="sentinelle.invite@vrai-domaine.org",
                              token="sentinelle-invitation", message="sentinelle message")
    OTP.objects.create(email="sentinelle.otp@vrai-domaine.org", otp="123456")
    Mail.objects.create(data={"email": "sentinelle.mail@vrai-domaine.org", "nom": "sentinelle"}, name="x",
                        to_email="sentinelle.mail@vrai-domaine.org", body="sentinelle", subject="sentinelle",
                        api_response_text="sentinelle", user=utilisateur)
    Error.objects.create(message={"e": "sentinelle"}, ip="203.0.113.77", platform="sentinelle", browser="sentinelle")
    Token.objects.create(user=utilisateur)
    Session.objects.create(session_key="sentinelle-session", session_data="sentinelle", expire_date=maintenant)
    application = Application.objects.create(
        user=admin, name="Appli", client_id="identifiant-public-appli", client_secret="sentinelle-secret",
        client_type="confidential", authorization_grant_type="password")
    acces = AccessToken.objects.create(
        user=utilisateur, token="sentinelle-acces", application=application, expires=maintenant + timedelta(days=1),
        scope="read")
    RefreshToken.objects.create(user=utilisateur, token="sentinelle-rafraichissement", application=application,
                                access_token=acces)
    UserSocialAuth.objects.create(user=utilisateur, provider="google-oauth2", uid="sentinelle-uid",
                                  extra_data={"email": "sentinelle.google@vrai-domaine.org"})
    GCMDevice.objects.create(user=utilisateur, registration_id="sentinelle-gcm", device_id="0x1234")
    APIRequestLog.objects.create(remote_addr="203.0.113.77", path="/sentinelle", host="vrai-domaine.org",
                                 method="GET", requested_at=maintenant, query_params="email=sentinelle", username_persistent="sentinelle")
    LogEntry.objects.create(user=admin, content_type=ContentType.objects.get_for_model(User), object_id="1",
                            object_repr="sentinelle.admin@vrai-domaine.org", action_flag=ADDITION,
                            change_message="sentinelle")
    categorie = Category.objects.create(name="Rubrique", color="red")
    article = Post.objects.create(title="Titre public", intro="intro", content="contenu", url="u", image="i.jpg",
                                  author=utilisateur, category=categorie)
    commentaire = Comment.objects.create(content="Commentaire public")
    Report.objects.create(reason="Spam", ip="203.0.113.77", browser="sentinelle-navigateur", post=article,
                          comment=commentaire, reporter=utilisateur)
    PostView.objects.create(post=article, ip_address="203.0.113.78", user_agent="sentinelle-agent")
    Task.objects.create(handler="h", args='["sentinelle.task@vrai-domaine.org"]', kwargs='{"a": "sentinelle"}',
                        error="sentinelle", run_at=maintenant)
    File.objects.create(owner=utilisateur, name="fichier.jpg", mime_type="image/jpeg")
    return jeu


def lire_tout(tables):
    contenu = {}
    with connection.cursor() as curseur:
        for table, colonnes in tables.items():
            selection = ", ".join('"%s"::text' % c for c in colonnes)
            curseur.execute('SELECT %s FROM "%s"' % (selection, table))
            contenu[table] = curseur.fetchall()
    return contenu


def photographier_colonnes_anonymisees(regles):
    photo = {}
    with connection.cursor() as curseur:
        for table, contenu in regles["tables_classees"].items():
            for colonne, regle in contenu["colonnes"].items():
                if regle["action"] == "anonymiser":
                    curseur.execute('SELECT "%s", "%s"::text FROM "%s"' % (contenu["cle"], colonne, table))
                    photo[(table, colonne)] = dict(curseur.fetchall())
    return photo


class AucuneValeurOrigineTests(TestCase):
    def setUp(self):
        self.jeu = creer_jeu_de_sentinelles()
        self.regles = charger_regles(REGLES_PAR_DEFAUT)
        self.avant = photographier_colonnes_anonymisees(self.regles)
        self.comptes = {t: User.objects.count() for t in ("user_user",)}
        with connection.cursor() as curseur:
            self.lignes_classees = {}
            for table in self.regles["tables_classees"]:
                curseur.execute('SELECT count(*) FROM "%s"' % table)
                self.lignes_classees[table] = curseur.fetchone()[0]

    def lancer(self):
        with environnement(ANONYMISATION_AUTORISEE="1", POSTGRES_HOST="127.0.0.1"):
            call_command("anonymiser", stdout=StringIO())

    def compter(self, table):
        with connection.cursor() as curseur:
            curseur.execute('SELECT count(*) FROM "%s"' % table)
            return curseur.fetchone()[0]

    def test_balayage_global_aucune_valeur_d_origine(self):
        self.lancer()
        schema = lire_schema(connection)
        for table, lignes in lire_tout(schema).items():
            for ligne in lignes:
                for valeur in ligne:
                    for interdite in VALEURS_INTERDITES:
                        self.assertNotIn(interdite, valeur or "", "valeur d'origine dans %s" % table)

    def test_tables_videes(self):
        self.lancer()
        for table in self.regles["tables_a_vider"]:
            self.assertEqual(self.compter(table), 0, table)

    def test_colonnes_anonymisees_changees_et_colonnes_gardees_intactes(self):
        self.lancer()
        apres = photographier_colonnes_anonymisees(self.regles)
        for cle, valeurs in self.avant.items():
            for identifiant, origine in valeurs.items():
                if origine not in (None, ""):
                    self.assertNotEqual(apres[cle][identifiant], origine, cle)
        for table, nombre in self.lignes_classees.items():
            self.assertEqual(self.compter(table), nombre, table)
        article = Post.objects.get()
        self.assertEqual((article.title, article.author_id), ("Titre public", self.jeu["utilisateur"].id))
        self.assertEqual(Category.objects.get().name, "Rubrique")
        self.assertEqual(File.objects.get().name, "fichier.jpg")
        self.assertEqual(Comment.objects.get().content, "Commentaire public")
        self.assertEqual(Report.objects.get().reason, "Spam")

    def test_mots_de_passe_inutilisables_et_emails_introuvables(self):
        self.lancer()
        for utilisateur in User.objects.all():
            self.assertFalse(utilisateur.has_usable_password())
            self.assertFalse(utilisateur.check_password(MOT_DE_PASSE))
        self.assertFalse(User.objects.filter(email="sentinelle.1@vrai-domaine.org").exists())
        utilisateur = User.objects.get(id=self.jeu["utilisateur"].id)
        self.assertEqual(utilisateur.email, "user-%d@exemple.invalid" % utilisateur.id)
        self.assertEqual(utilisateur.avatar, "images/fck2c7a8-gc4v-4q3s-behi-5fhnqti9mak4.jpg")
        self.assertIsNone(utilisateur.id_img)

    def test_second_passage_idempotent(self):
        self.lancer()
        aleatoires = {("user_user", "password"), ("oauth2_provider_application", "client_secret")}
        colonnes = {t: [c for c in cs if (t, c) not in aleatoires]
                    for t, cs in lire_schema(connection).items() if t in self.regles["tables_classees"]}
        premier = lire_tout(colonnes)
        self.lancer()
        self.assertEqual(lire_tout(colonnes), premier)

    def test_compatibilite_prodseed(self):
        ancien_id = self.jeu["admin"].id
        self.lancer()
        with environnement(DJANGO_SUPERUSER_PASSWORD="Mot-De-Passe-Preprod-42"):
            call_command("prodseed", stdout=StringIO())
        nouveau = User.objects.get(email="urbankiff@admin.com")
        self.assertTrue(nouveau.check_password("Mot-De-Passe-Preprod-42"))
        ancien = User.objects.get(id=ancien_id)
        self.assertEqual(ancien.email, "user-%d@exemple.invalid" % ancien_id)
        self.assertFalse(ancien.has_usable_password())
