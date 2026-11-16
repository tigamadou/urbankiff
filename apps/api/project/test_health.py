import importlib
import os
from unittest.mock import patch

from django.db import connection
from django.test import SimpleTestCase, TestCase, TransactionTestCase


class HealthTests(TestCase):
    def test_health_is_public_and_ok(self):
        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {'status': 'ok'})

    def test_health_rejects_post(self):
        response = self.client.post('/api/health/')
        self.assertEqual(response.status_code, 405)


class HealthDatabaseDownTests(TransactionTestCase):
    def test_health_returns_503_when_database_refuses_connection(self):
        settings_dict = connection.settings_dict
        original = (settings_dict['HOST'], settings_dict['PORT'])
        connection.close()
        settings_dict['HOST'], settings_dict['PORT'] = '127.0.0.1', '1'
        try:
            with self.assertLogs('project.views', level='WARNING'):
                response = self.client.get('/api/health/')
        finally:
            settings_dict['HOST'], settings_dict['PORT'] = original
            connection.close()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {'status': 'error'})
        self.assertNotIn('127.0.0.1', response.content.decode())
        self.assertNotIn('refused', response.content.decode().lower())

        recovered = self.client.get('/api/health/')
        self.assertEqual(recovered.status_code, 200)


class GunicornConfigTests(SimpleTestCase):
    def load(self):
        import project.gunicorn as config
        return importlib.reload(config)

    def test_defaults(self):
        with patch.dict(os.environ):
            os.environ.pop('WEB_CONCURRENCY', None)
            config = self.load()
        self.assertEqual(config.bind, '0.0.0.0:8000')
        self.assertEqual(config.workers, 2)
        self.assertEqual(config.worker_tmp_dir, '/tmp')
        self.assertEqual(config.accesslog, '-')
        self.assertEqual(config.errorlog, '-')
        self.assertGreaterEqual(config.timeout, 30)
        self.assertLessEqual(config.graceful_timeout, 30)

    def test_workers_from_environment(self):
        with patch.dict(os.environ, {'WEB_CONCURRENCY': '3'}):
            config = self.load()
        self.assertEqual(config.workers, 3)
