# Données entièrement fabriquées (aucune donnée réelle), lues par `python manage.py shell` sur la base de test.
from datetime import date

from django.contrib.auth import get_user_model

from apps.banner.models import Campaign, Media
from apps.category.models import Category
from apps.file.models import File
from apps.post.models import Post
from apps.scrapper.models import Scrapper

SENTINELLE = 'SENTINELLE_PERSONNELLE'
URLS = [
    'https://api.example.test/file/a.png',
    'https://api.example.test/file/b.png',
    'https://s3.example.test/bucket/c.png',
    'https://s30.example.test/bucket/d.png',
    'image-sans-schema.png',
]

user = get_user_model().objects.create(
    email=SENTINELLE + '@example.test', firstname=SENTINELLE, lastname=SENTINELLE, username=SENTINELLE)
categorie = Category.objects.create(name='categorie-test', color='bleu')
campagne = Campaign.objects.create(uuid='campagne-test')

for i, url in enumerate(URLS):
    File.objects.create(owner=user, name='f%d.png' % i, url=url, mime_type='image/png')
    Post.objects.create(
        title='titre-%d' % i, intro='intro', content='contenu', url='https://api.example.test/p/%d' % i,
        image=url, author=user, category=categorie)
    Media.objects.create(campaign=campagne, type='picture', file=url, device='desktop')
    Scrapper.objects.create(
        title='scrap-%d' % i, date=date(2026, 1, 1), content='contenu', image=url, website='site', link='https://api.example.test/l/%d' % i, language='fr')
