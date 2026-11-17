import os
from unittest.mock import patch

from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, override_settings
from django.test.runner import DiscoverRunner

from project.test_runner import AgentLotTestRunner


def _databases(name):
    return {'default': {'ENGINE': 'django.db.backends.postgresql', 'NAME': name}}


class AgentLotTestRunnerTests(SimpleTestCase):
    def setUp(self):
        self.runner = AgentLotTestRunner(verbosity=0)

    def test_is_a_discover_runner(self):
        self.assertIsInstance(self.runner, DiscoverRunner)

    def test_refuses_default_database_when_lot_is_set(self):
        with patch.dict(os.environ, {'AGENT_LOT': 'x'}), override_settings(DATABASES=_databases('urbankiff')):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                self.runner.check_agent_lot_database()
        self.assertIn('urbankiff_x', str(ctx.exception))
        self.assertIn("'urbankiff'", str(ctx.exception))

    def test_accepts_database_of_the_lot(self):
        with patch.dict(os.environ, {'AGENT_LOT': 'x'}), override_settings(DATABASES=_databases('urbankiff_x')):
            self.runner.check_agent_lot_database()

    def test_accepts_database_of_a_lot_with_hyphen(self):
        with patch.dict(os.environ, {'AGENT_LOT': 'outils-web'}), override_settings(
            DATABASES=_databases('urbankiff_outils_web')
        ):
            self.runner.check_agent_lot_database()

    def test_refuses_database_of_another_lot(self):
        with patch.dict(os.environ, {'AGENT_LOT': 'x'}), override_settings(DATABASES=_databases('urbankiff_y')):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                self.runner.check_agent_lot_database()
        self.assertIn('urbankiff_x', str(ctx.exception))
        self.assertIn('urbankiff_y', str(ctx.exception))

    def test_accepts_without_lot(self):
        env = {k: v for k, v in os.environ.items() if k != 'AGENT_LOT'}
        with patch.dict(os.environ, env, clear=True), override_settings(DATABASES=_databases('urbankiff')):
            self.runner.check_agent_lot_database()

    def test_accepts_with_empty_lot(self):
        with patch.dict(os.environ, {'AGENT_LOT': ''}), override_settings(DATABASES=_databases('urbankiff')):
            self.runner.check_agent_lot_database()

    def test_check_runs_before_any_database_creation(self):
        with patch.dict(os.environ, {'AGENT_LOT': 'x'}), override_settings(DATABASES=_databases('urbankiff')):
            with patch.object(DiscoverRunner, 'setup_databases') as setup_databases:
                with self.assertRaises(ImproperlyConfigured):
                    self.runner.run_tests([])
        setup_databases.assert_not_called()
