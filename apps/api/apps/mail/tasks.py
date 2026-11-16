import logging
import os
import smtplib
from smtplib import SMTPException

from django.conf import settings
from django.core.mail import send_mail as dj_send_mail


log = logging.getLogger(__name__)


def test_smtp_connection():
    """
    Test SMTP connection before sending emails.
    Returns tuple (success: bool, message: str)
    """
    # Skip SMTP test in development mode
    env = os.environ.get('DJANGO_ENV', 'dev')
    if env == 'dev':
        log.info('Skipping SMTP connection test in development mode')
        return True, 'SMTP test skipped in development mode'

    host = settings.EMAIL_HOST
    try:
        port = int(settings.EMAIL_PORT) if settings.EMAIL_PORT else 465
    except (ValueError, TypeError):
        port = 465
        log.warning(f'Invalid EMAIL_PORT value: {settings.EMAIL_PORT}, using default 465')
    username = settings.EMAIL_HOST_USER
    password = settings.EMAIL_HOST_PASSWORD
    use_tls = settings.EMAIL_USE_TLS
    use_ssl = settings.EMAIL_USE_SSL

    # Validate required settings
    if not host:
        error_msg = 'EMAIL_HOST is not configured'
        log.error(error_msg)
        return False, error_msg

    if not username or not password:
        error_msg = 'EMAIL_HOST_USER or EMAIL_HOST_PASSWORD is not configured'
        log.error(error_msg)
        log.error(f'EMAIL_HOST_USER={username}, EMAIL_HOST_PASSWORD={"***" if password else None}')
        return False, error_msg

    # Debug: Log what we're actually using (mask password partially for security)
    password_display = f"{password[:2]}***{password[-1]}" if password and len(password) > 3 else "None"
    log.info(f'Testing SMTP connection to {host}:{port}')
    log.info(f'SMTP settings: USER={username}, PASSWORD={password_display}, TLS={use_tls}, SSL={use_ssl}')
    print(f'SMTP connection test - HOST={host}, PORT={port}, USER={username}, PASSWORD={password_display}, TLS={use_tls}, SSL={use_ssl}')

    try:

        if use_ssl:
            server = smtplib.SMTP_SSL(host, port, timeout=10)
        else:
            server = smtplib.SMTP(host, port, timeout=10)
            if use_tls:
                server.starttls()

        if username and password:
            server.login(username, password)
            log.info('SMTP authentication successful')
        else:
            log.warning('SMTP credentials not provided, skipping authentication')

        server.quit()
        log.info('SMTP connection test successful')
        return True, 'SMTP connection successful'

    except smtplib.SMTPAuthenticationError as e:
        error_msg = f'SMTP authentication failed: {str(e)}'
        log.error(error_msg)
        log.error(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        print(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        return False, error_msg
    except smtplib.SMTPConnectError as e:
        error_msg = f'SMTP connection failed: {str(e)}'
        log.error(error_msg)
        log.error(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        print(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        return False, error_msg
    except smtplib.SMTPException as e:
        error_msg = f'SMTP error: {str(e)}'
        log.error(error_msg)
        log.error(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        print(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        return False, error_msg
    except Exception as e:
        error_msg = f'Unexpected error testing SMTP: {str(e)}'
        log.error(error_msg)
        log.error(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        print(f'SMTP credentials on failure - HOST={host}, PORT={port}, USER={username}, PASSWORD={password}, TLS={use_tls}, SSL={use_ssl}')
        return False, error_msg


def _smtp_send(mail):
    """
    Uses SMTP settings to send an email.
    Do not call this function directly.
    """
    from apps.mail.models import Mail

    to_email = getattr(mail.user, mail.user.get_email_field_name())

    try:
        sent = dj_send_mail(
            mail.subject,
            mail.body,
            settings.DEFAULT_FROM_EMAIL,
            [to_email],
            html_message=mail.body,
            fail_silently=False,
        )
        mail.status = Mail.SENT
        mail.save()
    except SMTPException as e:
        mail.status = Mail.ERROR
        mail.save()
        raise e

    return sent


# Should send emails inline by default.
# ONLY enable workers if we're sending many emails and want to avoid server load
#
#  @task()
def send_email(mail_id):
    """
    Do not call this task directly. Instead use a subclass of MailBase.

    """
    from apps.mail.models import Mail
    mail = Mail.objects.get(pk=mail_id)

    if not settings.SEND_MAIL:
        log.info('SEND_MAIL is not True! {}'.format(mail))
        mail.status = Mail.TEST
        mail.save()
        return

    # Test SMTP connection before sending
    success, message = test_smtp_connection()
    log.info(f'SMTP connection test result: {message}')

    if not success:
        log.error(f'Cannot send email {mail_id}: {message}')
        mail.status = Mail.ERROR
        mail.api_response_text = message
        mail.save()
        return None

    return _smtp_send(mail)


def _smtp_send_verification(mail):
    """
    Uses SMTP settings to send an email.
    Do not call this function directly.
    """
    from apps.mail.models import Mail

    to_email = mail.to_email

    try:
        sent = dj_send_mail(
            mail.subject,
            mail.body,
            settings.DEFAULT_FROM_EMAIL,
            [to_email],
            html_message=mail.body,
            fail_silently=False,
        )
        mail.status = Mail.SENT
        mail.save()
    except SMTPException as e:
        mail.status = Mail.ERROR
        mail.save()
        raise e

    return sent


def send_email_verification(mail_id):
    """
    Do not call this task directly. Instead use a subclass of MailBase.

    """
    from apps.mail.models import Mail

    mail = Mail.objects.get(pk=mail_id)

    if not settings.SEND_MAIL:
        log.info('SEND_MAIL is not True! {}'.format(mail))
        mail.status = Mail.TEST
        mail.save()
        return

    # Test SMTP connection before sending
    success, message = test_smtp_connection()
    log.info(f'SMTP connection test result: {message}')

    if not success:
        log.error(f'Cannot send verification email {mail_id}: {message}')
        mail.status = Mail.ERROR
        mail.api_response_text = message
        mail.save()
        return None

    return _smtp_send_verification(mail)
