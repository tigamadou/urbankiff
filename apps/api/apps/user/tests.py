from unittest.mock import patch
from urllib.parse import urlparse

from django.core import mail
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rolepermissions.roles import assign_role
from rest_framework.test import APITestCase

from .factories import UserFactory


def stub_forgot_password_email(calls):
    def forgot_password_email(user, reset_token):
        calls.append((reset_token, user.id))
    return forgot_password_email


class UserTests(APITestCase):
    @patch('apps.user.mail.Mail.send')
    def test_register_user(self, mock_send):
        """
        Ensure we can register a new user object.
        """
        url = reverse('signup')
        data = {'email': 'test@example.org', 'password': 'yayhooray'}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('token', response.data)
        self.assertIn('userId', response.data)
        self.assertEqual(get_user_model().objects.count(), 1)
        self.assertEqual(get_user_model().objects.get().email, 'test@example.org')

    @patch('apps.user.mail.Mail.send')
    def test_register_user_icase(self, mock_send):
        """
        User emails should be stored in lowercase
        """
        url = reverse('signup')
        email = 'uppercaseLOWERCASE@lowercaseUPPERCASE.ca'
        data = {'email': email, 'password': 'yayhooray'}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('token', response.data)
        self.assertIn('userId', response.data)
        self.assertEqual(get_user_model().objects.count(), 1)
        self.assertEqual(
            get_user_model().objects.get().email,
            email.lower()
        )

    def test_login_user(self):
        user = get_user_model().objects.create_user(
            email='user@example.com',
            password='secret',)
        assign_role(user, 'contributor')
        url = reverse('login')
        data = {'email': 'user@example.com', 'password': 'secret'}
        response = self.client.post(url, data, format='json')
        self.assertIn('token', response.data)
        self.assertIn('userId', response.data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_login_user_icase(self):
        create_email = 'USER@example.com'
        login_email = 'user@EXAMPLE.com'
        user = get_user_model().objects.create_user(
            email=create_email,
            password='secret',)
        assign_role(user, 'contributor')
        url = reverse('login')
        data = {'email': login_email, 'password': 'secret'}
        response = self.client.post(url, data, format='json')
        self.assertIn('token', response.data)
        self.assertIn('userId', response.data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_user_can_reset_password(self):
        new_password = 'whatever'
        user = get_user_model().objects.create_user(
            email='user@example.com',
            password='secret',)
        response = self.client.post(
            reverse('forgot-password'), data={'email': user.email}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, [user.email])

        reset_url = next(
            word for word in mail.outbox[0].body.replace('"', ' ').split()
            if 'reset-password/' in word)
        token = urlparse(reset_url).path.split('/')[-2]

        response = self.client.post(
            reverse('reset-password'),
            data={'token': token, 'user_id': user.id, 'password': new_password},
            format='json'
        )
        user.refresh_from_db()
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(user.check_password(new_password))

    def test_user_can_reset_password_with_camel_case_payload(self):
        new_password = 'whatever'
        user = get_user_model().objects.create_user(
            email='user@example.com',
            password='secret',)
        self.client.post(
            reverse('forgot-password'), data={'email': user.email}, format='json')
        reset_url = next(
            word for word in mail.outbox[0].body.replace('"', ' ').split()
            if 'reset-password/' in word)
        token = urlparse(reset_url).path.split('/')[-2]

        response = self.client.post(
            reverse('validate-reset-token'),
            data={'token': token, 'userId': user.id},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['valid'])

        response = self.client.post(
            reverse('reset-password'),
            data={'token': token, 'userId': user.id, 'password': new_password},
            format='json'
        )
        user.refresh_from_db()
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(user.check_password(new_password))

    def test_user_can_request_password_icase(self):
        create_email = 'USER@example.com'
        reset_email = 'user@EXAMPLE.com'
        get_user_model().objects.create_user(
            email=create_email,
            password='secret',)
        response = self.client.post(
            reverse('forgot-password'), data={'email': reset_email}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 1)

    def test_get_profile(self):
        user = get_user_model().objects.create_user(
            email='user@example.com',
            password='secret',)
        self.client.force_authenticate(user=user)
        response = self.client.get(reverse('me'), format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class ExistingUserTests(APITestCase):
    def setUp(self):
        self.user = UserFactory(email='test@example.org')

    def test_register_user(self):
        url = reverse('signup')
        data = {'email': 'test@example.org', 'password': 'yayhooray'}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_user_icase(self):
        url = reverse('signup')
        data = {'email': 'TeSt@exaMple.org', 'password': 'yayhooray'}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
