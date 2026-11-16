from django.core.management.base import BaseCommand
from apps.page.models import Page
import json


class Command(BaseCommand):
    help = 'This function create page for condition of service'

    def add_arguments(self, parser):
        parser.add_argument('title', type=str, help='The title of the page to create')
        parser.add_argument('file_path', type=str, help='The path to the JSON file')

    def handle(self, *args, **kwargs):
        file_path = kwargs['file_path']
        page_title = kwargs['title']
        try:

            if Page.objects.filter(title=page_title).exists():
                self.stdout.write(self.style.ERROR(f'Page {page_title} already exist !'))

            else:
                with open(file_path, "r") as file:
                    data = json.load(file)
                    for value in data:
                        title = value["title"]
                        content = value["content"]
                        published = value["published"]
                        language = value["language"]
                        page = Page.objects.create(title=title, content=content, published=published, language=language)
                        page.save()

                self.stdout.write(self.style.SUCCESS(f'Page {page_title} created !'))
        except FileNotFoundError:
            self.stdout.write(self.style.ERROR('File not found'))
        except json.JSONDecodeError:
            self.stdout.write(self.style.ERROR('Error decoding JSON'))
