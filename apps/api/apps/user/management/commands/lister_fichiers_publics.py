import re

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.banner.models import Media
from apps.file.models import File
from apps.page.models import Page
from apps.post.models import Post
from apps.scrapper.models import Scrapper
from apps.user.management.commands.anonymiser import verifier_environnement

FIN_D_URL = r"""([^\s"'<>()\[\]?#]+)"""


class Command(BaseCommand):
    help = "Liste, une par ligne, les clés du bucket citées par le contenu public de la base anonymisée"

    def handle(self, *args, **options):
        verifier_environnement()
        point_d_entree = (settings.FILES_CDN_ENDPOINT or "").rstrip("/")
        if not point_d_entree:
            raise CommandError("FILES_CDN_ENDPOINT est absent : impossible de reconnaître les URL de fichiers",
                               returncode=1)
        motif = re.compile(re.escape(point_d_entree) + "/" + FIN_D_URL)

        def depuis_colonne(valeur):
            valeur = (valeur or "").strip()
            if valeur.startswith(point_d_entree + "/"):
                valeur = valeur[len(point_d_entree) + 1:]
            elif "://" in valeur:
                return []
            valeur = valeur.split("?")[0].split("#")[0].lstrip("/")
            return [valeur] if valeur else []

        def depuis_texte(texte):
            return [cle.rstrip(".,;:!") for cle in motif.findall(texte or "")]

        cites = set()
        for image, audio, video, contenu, intro in Post.objects.values_list(
                "image", "audio", "video", "content", "intro"):
            for colonne in (image, audio, video):
                cites.update(depuis_colonne(colonne))
            cites.update(depuis_texte(contenu))
            cites.update(depuis_texte(intro))
        for contenu in Page.objects.values_list("content", flat=True):
            cites.update(depuis_texte(contenu))
        for fichier in Media.objects.values_list("file", flat=True):
            cites.update(depuis_colonne(fichier))
        for image, contenu in Scrapper.objects.values_list("image", "content"):
            cites.update(depuis_colonne(image))
            cites.update(depuis_texte(contenu))

        cles = set(cites)
        for nom, chemin, url in File.objects.values_list("name", "path", "url"):
            if nom in cites or set(depuis_colonne(url)) & cites:
                cles.add("%s/%s" % (chemin.strip("/"), nom) if chemin else nom)
        for cle in sorted(cles):
            self.stdout.write(cle)
