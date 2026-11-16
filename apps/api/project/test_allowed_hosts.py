import os
import subprocess
import sys

from django.conf import settings
from django.test import SimpleTestCase


def settings_in_env(**overrides):
    env = {key: value for key, value in os.environ.items() if key not in ('ALLOWED_HOSTS', 'DATABASE_URL')}
    env.update(overrides)
    code = 'import project.settings as s; print(",".join(s.ALLOWED_HOSTS))'
    return subprocess.run(
        [sys.executable, '-c', code], cwd=settings.BASE_DIR, env=env, capture_output=True, text=True
    )


class AllowedHostsProductionTests(SimpleTestCase):
    def test_production_keeps_allowed_hosts_from_environment(self):
        result = settings_in_env(DJANGO_ENV='production', ALLOWED_HOSTS='api.example.test,panel.example.test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'api.example.test,panel.example.test')

    def test_staging_keeps_allowed_hosts_from_environment(self):
        result = settings_in_env(DJANGO_ENV='staging', ALLOWED_HOSTS='preprod.api.example.test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'preprod.api.example.test')

    def test_production_refuses_missing_allowed_hosts(self):
        result = settings_in_env(DJANGO_ENV='production')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ALLOWED_HOSTS', result.stderr)

    def test_production_refuses_wildcard(self):
        result = settings_in_env(DJANGO_ENV='production', ALLOWED_HOSTS='api.example.test,*')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ALLOWED_HOSTS', result.stderr)

    def test_dev_still_defaults_to_wildcard(self):
        result = settings_in_env(DJANGO_ENV='dev')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '*')
