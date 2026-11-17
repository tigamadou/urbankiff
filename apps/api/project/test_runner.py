import os

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.test.runner import DiscoverRunner


class AgentLotTestRunner(DiscoverRunner):
    """Refuse de tester hors de la base du lot quand AGENT_LOT est défini."""

    def check_agent_lot_database(self):
        lot = os.environ.get('AGENT_LOT')
        if not lot:
            return
        # Même règle que scripts/devteam-adaptateurs/postgres.sh : tiret du lot -> _ dans le nom de base.
        expected = f"urbankiff_{lot.replace('-', '_')}"
        found = settings.DATABASES['default']['NAME']
        if found != expected:
            raise ImproperlyConfigured(
                f"AGENT_LOT={lot} : base attendue '{expected}', base trouvée '{found}'. "
                'Tests refusés avant toute création de base.'
            )

    def run_tests(self, test_labels, **kwargs):
        self.check_agent_lot_database()
        return super().run_tests(test_labels, **kwargs)
