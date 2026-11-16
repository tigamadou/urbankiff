import os
from io import StringIO
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase

EMAIL_ADMIN = "urbankiff@admin.com"


class ProdseedTests(TestCase):
    def test_sans_mot_de_passe_aucun_administrateur_cree(self):
        environnement = {k: v for k, v in os.environ.items() if k != "DJANGO_SUPERUSER_PASSWORD"}
        with mock.patch.dict(os.environ, environnement, clear=True):
            call_command("prodseed", stdout=StringIO())
        self.assertFalse(get_user_model().objects.filter(email=EMAIL_ADMIN).exists())

    def test_administrateur_cree_avec_le_mot_de_passe_fourni(self):
        with mock.patch.dict(os.environ, {"DJANGO_SUPERUSER_PASSWORD": "Mot-De-Passe-De-Test-42"}):
            call_command("prodseed", stdout=StringIO())
        admin = get_user_model().objects.get(email=EMAIL_ADMIN)
        self.assertTrue(admin.check_password("Mot-De-Passe-De-Test-42"))
        self.assertFalse(admin.check_password("password"))
