import json
import os
import tempfile
from io import StringIO

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings

from apps.category.models import Category
from apps.post.models import Post
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
