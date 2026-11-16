from .websites.main import main_scrapper
from .websites.vulture import VULTURE_ELEMENTS
from .websites.booskap import BOOSKA_ELEMENTS
from apps.workers import task
from django.conf import settings

SCHEDULE = getattr(settings, 'WORKERS_DELAY')


@task(schedule=SCHEDULE)
def vulture_scrapper():
    main_scrapper(
        url=VULTURE_ELEMENTS.get('url'),
        article_list_tag=VULTURE_ELEMENTS.get('article_list_tag'),
        article_list_class=VULTURE_ELEMENTS.get('article_list_class'),
        link_tag=VULTURE_ELEMENTS.get('link_tag'),
        link_class=VULTURE_ELEMENTS.get('link_class'),
        title_tag=VULTURE_ELEMENTS.get('title_tag'),
        title_class=VULTURE_ELEMENTS.get('title_class'),
        intro_class=VULTURE_ELEMENTS.get('intro_class'),
        intro_tag=VULTURE_ELEMENTS.get('intro_tag'),
        content_tag=VULTURE_ELEMENTS.get('content_tag'),
        content_class=VULTURE_ELEMENTS.get('content_class'),
        image_attribute=VULTURE_ELEMENTS.get('image_attribute'),
        website=VULTURE_ELEMENTS.get('website'),
        language=VULTURE_ELEMENTS.get('language')
    )


@task(schedule=SCHEDULE)
def booska_p_scrapper():
    main_scrapper(
        url=BOOSKA_ELEMENTS.get('url'),
        article_list_tag=BOOSKA_ELEMENTS.get('article_list_tag'),
        article_list_class=BOOSKA_ELEMENTS.get('article_list_class'),
        link_tag=BOOSKA_ELEMENTS.get('link_tag'),
        link_class=BOOSKA_ELEMENTS.get('link_class'),
        title_tag=BOOSKA_ELEMENTS.get('title_tag'),
        title_class=BOOSKA_ELEMENTS.get('title_class'),
        intro_class=BOOSKA_ELEMENTS.get('intro_class'),
        intro_tag=BOOSKA_ELEMENTS.get('intro_tag'),
        content_tag=BOOSKA_ELEMENTS.get('content_tag'),
        content_class=BOOSKA_ELEMENTS.get('content_class'),
        image_attribute=BOOSKA_ELEMENTS.get('image_attribute'),
        website=BOOSKA_ELEMENTS.get('website'),
        language=BOOSKA_ELEMENTS.get('language')
    )
