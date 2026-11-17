import json
import os

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

REGLES_PAR_DEFAUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'regles_urls.json')

PREFIXE = 'prefixe'
CONTENU = 'contenu'

# (modele, champ, mode) ; seul endroit a modifier pour ajouter une colonne.
COLONNES = (
    ('file.File', 'url', PREFIXE),
    ('post.Post', 'image', PREFIXE),
    ('post.Post', 'audio', PREFIXE),
    ('post.Post', 'video', PREFIXE),
    ('banner.Media', 'file', PREFIXE),
    ('scrapper.Scrapper', 'image', PREFIXE),
    ('user.User', 'id_img', PREFIXE),
    ('post.Post', 'content', CONTENU),
    ('post.Post', 'intro', CONTENU),
    ('page.Page', 'content', CONTENU),
    ('scrapper.Scrapper', 'content', CONTENU),
)


def charger_regles(chemin):
    try:
        with open(chemin) as f:
            regles = json.load(f)
    except OSError as e:
        raise CommandError('Fichier de regles illisible : %s (%s)' % (chemin, e))
    except ValueError as e:
        raise CommandError('Fichier de regles invalide (JSON) : %s (%s)' % (chemin, e))
    if not isinstance(regles, list):
        raise CommandError('Fichier de regles invalide : la racine doit etre une liste')
    sources = []
    for regle in regles:
        source = regle.get('source') if isinstance(regle, dict) else None
        if not isinstance(source, str):
            raise CommandError(
                'Fichier de regles invalide : chaque regle doit avoir une "source" texte')
        source = source.strip().rstrip('/')
        if not source:
            raise CommandError('Fichier de regles invalide : "source" vide')
        sources.append(source)
    return sources


def lire_cible():
    cible = (getattr(settings, 'FILES_CDN_ENDPOINT', None) or '').strip().rstrip('/')
    if not cible:
        raise CommandError('FILES_CDN_ENDPOINT est absent ou vide : rien a reecrire')
    return cible


class Command(BaseCommand):
    help = 'Remplace dans la base les prefixes d\'URL de fichiers par FILES_CDN_ENDPOINT.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--regles', default=REGLES_PAR_DEFAUT,
            help='Fichier de regles JSON (defaut : apps/file/regles_urls.json)')

    def handle(self, *args, **options):
        cible = lire_cible()
        sources = charger_regles(options['regles'])
        return self.reecrire(sources, cible)

    def reecrire(self, sources, cible):
        pass
