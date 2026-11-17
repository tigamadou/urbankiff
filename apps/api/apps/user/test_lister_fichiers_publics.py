import os
from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings

from apps.banner.models import Campaign, Media
from apps.category.models import Category
from apps.file.models import File
from apps.page.models import Page
from apps.post.models import Post
from apps.scrapper.models import Scrapper
from apps.user.factories import UserFactory

CDN = "https://api.exemple.test/file"
ENV_OK = {"ANONYMISATION_AUTORISEE": "1", "POSTGRES_HOST": "127.0.0.1"}


def lancer(environnement=None):
    sortie = StringIO()
    base = {k: v for k, v in os.environ.items() if k not in ("ANONYMISATION_AUTORISEE", "POSTGRES_HOST")}
    base.update(ENV_OK if environnement is None else environnement)
    with mock.patch.dict(os.environ, base, clear=True):
        call_command("lister_fichiers_publics", stdout=sortie)
    return sortie.getvalue().splitlines()


@override_settings(FILES_CDN_ENDPOINT=CDN)
class GardeFouTests(TestCase):
    def test_refus_sans_environnement_sur(self):
        for environnement in ({}, {"ANONYMISATION_AUTORISEE": "1"}, {"POSTGRES_HOST": "127.0.0.1"},
                              {"ANONYMISATION_AUTORISEE": "0", "POSTGRES_HOST": "127.0.0.1"},
                              {"ANONYMISATION_AUTORISEE": "1", "POSTGRES_HOST": "postgresDB"},
                              {"ANONYMISATION_AUTORISEE": "1", "POSTGRES_HOST": "127.0.0.1.evil.example"}):
            sortie = StringIO()
            base = {k: v for k, v in os.environ.items() if k not in ("ANONYMISATION_AUTORISEE", "POSTGRES_HOST")}
            base.update(environnement)
            with mock.patch.dict(os.environ, base, clear=True):
                with self.assertRaises(CommandError) as ctx:
                    call_command("lister_fichiers_publics", stdout=sortie)
            self.assertEqual(ctx.exception.returncode, 2)
            self.assertEqual(sortie.getvalue(), "")

    def test_endpoint_absent(self):
        with override_settings(FILES_CDN_ENDPOINT=None):
            with self.assertRaises(CommandError) as ctx:
                lancer()
        self.assertEqual(ctx.exception.returncode, 1)


@override_settings(FILES_CDN_ENDPOINT=CDN + "/")
class ContenuTests(TestCase):
    def setUp(self):
        self.utilisateur = UserFactory(email="a@b.org", avatar=CDN + "/avatar-sentinelle.jpg",
                                       id_img=CDN + "/piece-sentinelle.jpg")
        self.categorie = Category.objects.create(name="Rubrique", color="red")

    def article(self, **valeurs):
        champs = dict(title="t", intro="", content="", url="u", image="", author=self.utilisateur,
                      category=self.categorie)
        champs.update(valeurs)
        return Post.objects.create(**champs)

    def test_base_vide(self):
        self.assertEqual(lancer(), [])

    def test_colonnes_publiques_et_urls_dans_les_textes(self):
        self.article(image=CDN + "/image.jpg", audio=CDN + "/son.mp3", video="relative/video.mp4",
                     content='<img src="%s/dans-contenu.png" alt="x"> et <a href="%s/doc.pdf?x=1">' % (CDN, CDN),
                     intro="intro %s/dans-intro.png." % CDN)
        Page.objects.create(title="p", language="fr", content="(%s/page.png)" % CDN)
        Media.objects.create(campaign=Campaign.objects.create(uuid="c"), type="image", file=CDN + "/banniere.jpg",
                             device="web")
        Scrapper.objects.create(title="s", date="2020-01-01", content="<img src='%s/scrap-contenu.png'>" % CDN,
                                image=CDN + "/scrap.jpg", website="w", link="l", language="fr")
        self.assertEqual(lancer(), [
            "banniere.jpg", "dans-contenu.png", "dans-intro.png", "doc.pdf", "image.jpg", "page.png",
            "relative/video.mp4", "scrap-contenu.png", "scrap.jpg", "son.mp3"])

    def test_url_et_valeur_relative_donnent_la_meme_cle_dedoublonnee(self):
        self.article(image=CDN + "/meme.jpg", audio="meme.jpg", video="/meme.jpg",
                     content=CDN + "/meme.jpg " + CDN + "/meme.jpg")
        self.assertEqual(lancer(), ["meme.jpg"])

    def test_url_externe_ignoree(self):
        self.article(image="https://autre.example/ext.jpg", content="https://autre.example/file/ext2.jpg")
        self.assertEqual(lancer(), [])

    def test_seuls_les_fichiers_cites_sortent(self):
        File.objects.create(owner=self.utilisateur, name="cite.jpg", path="uploads", url=CDN + "/cite.jpg",
                            mime_type="image/jpeg")
        File.objects.create(owner=self.utilisateur, name="oublie.jpg", path="uploads", url=CDN + "/oublie.jpg",
                            mime_type="image/jpeg")
        self.article(image=CDN + "/cite.jpg")
        self.assertEqual(lancer(), ["cite.jpg", "uploads/cite.jpg"])

    def test_aucune_donnee_de_personne(self):
        File.objects.create(owner=self.utilisateur, name="avatar-sentinelle.jpg", path="uploads",
                            url=CDN + "/avatar-sentinelle.jpg", mime_type="image/jpeg")
        self.article(image=CDN + "/image.jpg")
        sortie = lancer()
        self.assertEqual(sortie, ["image.jpg"])
        self.assertFalse([cle for cle in sortie if "sentinelle" in cle])

    def test_rien_n_est_modifie(self):
        self.article(image=CDN + "/image.jpg")
        lancer()
        self.assertEqual(Post.objects.get().image, CDN + "/image.jpg")
        self.utilisateur.refresh_from_db()
        self.assertEqual(self.utilisateur.email, "a@b.org")
