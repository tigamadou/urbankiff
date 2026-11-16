from django.db import connection
from django.test import TestCase, TransactionTestCase


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
