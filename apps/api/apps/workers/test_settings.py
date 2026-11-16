from unittest import mock

from django.test import SimpleTestCase

from apps.workers.settings import pool_processes


class PoolProcessesTest(SimpleTestCase):
    def test_absent_laisse_le_defaut_de_multiprocessing(self):
        with mock.patch.dict('os.environ', {}, clear=True):
            self.assertIsNone(pool_processes())

    def test_valeur_lue_dans_l_environnement(self):
        with mock.patch.dict('os.environ', {'WORKERS_PROCESSES': '1'}):
            self.assertEqual(pool_processes(), 1)

    def test_zero_ou_vide_laisse_le_defaut(self):
        for valeur in ('0', ''):
            with mock.patch.dict('os.environ', {'WORKERS_PROCESSES': valeur}):
                self.assertIsNone(pool_processes())
