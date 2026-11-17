import json
import os
import tempfile
from io import StringIO

from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import DataError
from django.test import TestCase, override_settings

from apps.banner.models import Campaign, Media
from apps.category.models import Category
from apps.file.management.commands.reecrire_urls import COLONNES
from apps.file.models import File
from apps.menu.models import Menu
from apps.page.models import Page
from apps.post.models import Post
from apps.scrapper.models import Scrapper
from apps.user.factories import UserFactory

SOURCE = 'https://api.urbankiff.com/file'
CIBLE = 'https://preprod.api.urbankiff.com/file'


class ReglesTestCase(TestCase):
    def ecrire_regles(self, contenu):
        dossier = tempfile.TemporaryDirectory()
        self.addCleanup(dossier.cleanup)
        chemin = os.path.join(dossier.name, 'regles.json')
        with open(chemin, 'w') as f:
            f.write(contenu if isinstance(contenu, str) else json.dumps(contenu))
        return chemin

    def lancer(self, regles=None):
        sortie, erreur = StringIO(), StringIO()
        args = ['--regles', regles] if regles else []
        call_command('reecrire_urls', *args, stdout=sortie, stderr=erreur)
        return sortie.getvalue(), erreur.getvalue()


class ChargementReglesTests(ReglesTestCase):
    def test_fichier_livre_valide(self):
        from apps.file.management.commands import reecrire_urls
        with open(reecrire_urls.REGLES_PAR_DEFAUT) as f:
            regles = json.load(f)
        self.assertIsInstance(regles, list)
        self.assertIn(SOURCE, [r['source'] for r in regles])

    @override_settings(FILES_CDN_ENDPOINT=CIBLE)
    def test_fichier_livre_sans_option(self):
        self.lancer()

    def test_cible_absente(self):
        user = UserFactory(email='a@example.org')
        cat = Category.objects.create(name='c', color='red')
        post = Post.objects.create(
            title='t', intro='i', content='c', url='u', image=SOURCE + '/x.jpg',
            author=user, category=cat)
        for valeur in (None, ''):
            with override_settings(FILES_CDN_ENDPOINT=valeur):
                with self.assertRaisesMessage(CommandError, 'FILES_CDN_ENDPOINT'):
                    self.lancer()
        post.refresh_from_db()
        self.assertEqual(post.image, SOURCE + '/x.jpg')

    @override_settings(FILES_CDN_ENDPOINT=CIBLE)
    def test_regles_invalides(self):
        cas = [
            '{cassé',
            '{"source": "x"}',
            '[1]',
            '[{}]',
            '[{"source": ""}]',
            '[{"source": "  /  "}]',
            '[{"source": 3}]',
        ]
        for contenu in cas:
            with self.subTest(contenu=contenu):
                with self.assertRaises(CommandError):
                    self.lancer(self.ecrire_regles(contenu))

    @override_settings(FILES_CDN_ENDPOINT=CIBLE)
    def test_fichier_inexistant(self):
        with self.assertRaises(CommandError):
            self.lancer('/inexistant/regles.json')

    @override_settings(FILES_CDN_ENDPOINT=CIBLE)
    def test_liste_vide(self):
        sortie, erreur = self.lancer(self.ecrire_regles([]))
        self.assertEqual(erreur, '')


def ligne(colonne, n):
    return 'reecrire_urls : %s : %d ligne(s)' % (colonne, n)


class DonneesTestCase(ReglesTestCase):
    def setUp(self):
        self.user = UserFactory(email='u@example.org')
        self.categorie = Category.objects.create(name='c', color='red')
        self.campagne = Campaign.objects.create(uuid='camp')

    def post(self, **kw):
        valeurs = dict(title='t', intro='i', content='c', url='u', image='',
                       author=self.user, category=self.categorie)
        valeurs.update(kw)
        return Post.objects.create(**valeurs)

    def scrapper(self, **kw):
        valeurs = dict(title='t%d' % Scrapper.objects.count(), date='2024-01-01',
                       content='c', image='', website='w', link='l', language='en')
        valeurs.update(kw)
        return Scrapper.objects.create(**valeurs)

    def media(self, **kw):
        valeurs = dict(campaign=self.campagne, type='picture', file='', device='desktop')
        valeurs.update(kw)
        return Media.objects.create(**valeurs)

    def fichier(self, **kw):
        valeurs = dict(owner=self.user, name='n', mime_type='image/png')
        valeurs.update(kw)
        return File.objects.create(**valeurs)


@override_settings(FILES_CDN_ENDPOINT=CIBLE)
class ModePrefixeTests(DonneesTestCase):
    def verifier(self, objet, champ):
        setattr(objet, champ, SOURCE + '/x.jpg')
        objet.save()
        self.lancer()
        objet.refresh_from_db()
        self.assertEqual(getattr(objet, champ), CIBLE + '/x.jpg')

    def test_file_url(self):
        self.verifier(self.fichier(), 'url')

    def test_post_image(self):
        self.verifier(self.post(), 'image')

    def test_post_audio(self):
        self.verifier(self.post(), 'audio')

    def test_post_video(self):
        self.verifier(self.post(), 'video')

    def test_media_file(self):
        self.verifier(self.media(), 'file')

    def test_scrapper_image(self):
        self.verifier(self.scrapper(), 'image')

    def test_user_id_img(self):
        self.verifier(self.user, 'id_img')

    def test_journal_et_decomptes(self):
        self.post(image=SOURCE + '/a.jpg')
        self.post(image=SOURCE + '/b.jpg')
        self.fichier(url=SOURCE + '/c.jpg')
        sortie, _ = self.lancer()
        lignes = sortie.splitlines()
        attendues = {'post_post.image': 2, 'file_file.url': 1}
        for table_colonne in (
                'file_file.url', 'post_post.image', 'post_post.audio', 'post_post.video',
                'banner_media.file', 'scrapper_scrapper.image', 'user_user.id_img',
                'post_post.content', 'post_post.intro', 'page_page.content',
                'scrapper_scrapper.content'):
            self.assertIn(ligne(table_colonne, attendues.get(table_colonne, 0)), lignes)
        self.assertEqual(len(lignes), len(COLONNES))

    def test_idempotence(self):
        post = self.post(image=SOURCE + '/a.jpg')
        self.lancer()
        sortie, _ = self.lancer()
        post.refresh_from_db()
        self.assertEqual(post.image, CIBLE + '/a.jpg')
        self.assertIn(ligne('post_post.image', 0), sortie)
        self.assertNotRegex(sortie, r': [1-9]\d* ligne')

    def test_cible_egale_source(self):
        post = self.post(image=SOURCE + '/a.jpg')
        with override_settings(FILES_CDN_ENDPOINT=SOURCE):
            sortie, _ = self.lancer()
        post.refresh_from_db()
        self.assertEqual(post.image, SOURCE + '/a.jpg')
        self.assertNotRegex(sortie, r': [1-9]\d* ligne')

    def test_valeurs_intactes(self):
        externe = self.post(image='https://exemple.org/x.jpg')
        vide = self.post(image='')
        nul = self.post(image='x', audio=None, video=None)
        deja = self.post(image=CIBLE + '/x.jpg')
        exclues = self.post(url=SOURCE + '/p', image='x')
        media = self.media(file='x', url=SOURCE + '/clic')
        scrapper = self.scrapper(link=SOURCE + '/l', website=SOURCE + '/w', image='x')
        menu = Menu.objects.create(name='m', url=SOURCE + '/m')
        self.user.id_img = None
        self.user.save()
        self.lancer()
        for objet, champ, valeur in (
                (externe, 'image', 'https://exemple.org/x.jpg'), (vide, 'image', ''),
                (nul, 'audio', None), (nul, 'video', None), (deja, 'image', CIBLE + '/x.jpg'),
                (exclues, 'url', SOURCE + '/p'), (media, 'url', SOURCE + '/clic'),
                (scrapper, 'link', SOURCE + '/l'), (scrapper, 'website', SOURCE + '/w'),
                (menu, 'url', SOURCE + '/m'), (self.user, 'id_img', None)):
            objet.refresh_from_db()
            self.assertEqual(getattr(objet, champ), valeur)

    def test_updated_at_conserve(self):
        post = self.post(image=SOURCE + '/a.jpg')
        avant = Post.objects.get(pk=post.pk).updated_at
        self.lancer()
        self.assertEqual(Post.objects.get(pk=post.pk).updated_at, avant)

    def test_deux_regles(self):
        un = self.post(image=SOURCE + '/a.jpg')
        deux = self.post(image='https://ancien.example/file/b.jpg')
        regles = self.ecrire_regles([{'source': SOURCE}, {'source': 'https://ancien.example/file/'}])
        sortie, _ = self.lancer(regles)
        un.refresh_from_db()
        deux.refresh_from_db()
        self.assertEqual(un.image, CIBLE + '/a.jpg')
        self.assertEqual(deux.image, CIBLE + '/b.jpg')
        self.assertIn(ligne('post_post.image', 2), sortie)


@override_settings(FILES_CDN_ENDPOINT=CIBLE)
class ModeContenuTests(DonneesTestCase):
    HTML = '<p><img src="%s/a.png"> et <img src="%s/b.png"></p>'

    def test_contenu_html_toutes_occurrences(self):
        entree = self.HTML % (SOURCE, SOURCE)
        attendu = self.HTML % (CIBLE, CIBLE)
        post = self.post(content=entree, intro=entree)
        page = Page.objects.create(title='t', language='fr', content=entree)
        scrapper = self.scrapper(content=entree)
        sortie, _ = self.lancer()
        for objet, champ in ((post, 'content'), (post, 'intro'), (page, 'content'),
                             (scrapper, 'content')):
            objet.refresh_from_db()
            self.assertEqual(getattr(objet, champ), attendu)
        self.assertIn(ligne('post_post.content', 1), sortie)
        self.assertIn(ligne('post_post.intro', 1), sortie)
        self.assertIn(ligne('page_page.content', 1), sortie)
        self.assertIn(ligne('scrapper_scrapper.content', 1), sortie)

    def test_regle_chemin_de_bucket(self):
        source = 'https://s3.exemple.org/urbankiff'
        post = self.post(image=source + '/x.png', content='<img src="%s/x.png">' % source)
        self.lancer(self.ecrire_regles([{'source': source}]))
        post.refresh_from_db()
        self.assertEqual(post.image, CIBLE + '/x.png')
        self.assertEqual(post.content, '<img src="%s/x.png">' % CIBLE)

    def test_frontiere_de_prefixe(self):
        valeurs = [SOURCE.replace('/file', '/files-x') + '/y.png', SOURCE + 'x']
        post = self.post(image=valeurs[0], content=valeurs[0], intro=valeurs[1])
        self.lancer()
        post.refresh_from_db()
        self.assertEqual((post.image, post.content, post.intro),
                         (valeurs[0], valeurs[0], valeurs[1]))

    def test_slash_final_indifferent(self):
        resultats = []
        for source, cible in ((SOURCE, CIBLE), (SOURCE + '/', CIBLE + '/')):
            Post.objects.all().delete()
            post = self.post(image=SOURCE + '/x.png', content='<img src="%s/x.png">' % SOURCE)
            with override_settings(FILES_CDN_ENDPOINT=cible):
                self.lancer(self.ecrire_regles([{'source': source}]))
            post.refresh_from_db()
            resultats.append((post.image, post.content))
        self.assertEqual(resultats[0], resultats[1])
        self.assertEqual(resultats[0][0], CIBLE + '/x.png')

    def test_cible_prefixee_par_la_source(self):
        source, cible = 'https://h.example/file', 'https://h.example/file/v2'
        post = self.post(image=source + '/x.png', content='<img src="%s/x.png">' % source)
        regles = self.ecrire_regles([{'source': source}])
        with override_settings(FILES_CDN_ENDPOINT=cible):
            _, erreur = self.lancer(regles)
            post.refresh_from_db()
            premier = (post.image, post.content)
            self.lancer(regles)
        post.refresh_from_db()
        self.assertEqual((post.image, post.content), premier)
        self.assertEqual(post.image, cible + '/x.png')
        self.assertNotIn('v2/v2', post.image + post.content)
        self.assertIn('ignoree', erreur)

    def test_atomicite(self):
        post = self.post(image=SOURCE + '/a.png')
        self.user.id_img = SOURCE + '/' + 'a' * (1000 - len(SOURCE) - 1)
        self.user.save()
        self.assertEqual(len(self.user.id_img), 1000)
        with self.assertRaises(DataError):
            self.lancer()
        post.refresh_from_db()
        self.user.refresh_from_db()
        self.assertEqual(post.image, SOURCE + '/a.png')
        self.assertTrue(self.user.id_img.startswith(SOURCE))
