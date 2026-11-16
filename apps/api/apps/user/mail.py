import logging
from django.conf import settings
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives

from apps.mail.models import Mail
from apps.mail.tasks import test_smtp_connection

log = logging.getLogger(__name__)

# Supported languages for email templates
SUPPORTED_LANGUAGES = ['fr', 'en']
DEFAULT_LANGUAGE = 'fr'


def send_forgot_password_email(user, reset_token):
    reset_url = settings.RESET_PASSWORD_URL.format(
        reset_token=reset_token,
        user_id=user.id
    )
    Mail.send('ForgotPassword', user, reset_url=reset_url)


def send_welcome_email(user):
    Mail.send('WelcomeUser', user)


def send_otp_mail(email, otp):
    Mail.send_verification_mail('MailVerification', email, otp=otp)


def send_forgot_password_email_template(user, reset_token, language=None):
    """
    Send password reset email using localized HTML template file

    Args:
        user: User object
        reset_token: Password reset token
        language: Language code (fr, en). Defaults to French if not provided or invalid
    """
    # Validate and set language
    if language not in SUPPORTED_LANGUAGES:
        language = DEFAULT_LANGUAGE

    reset_url = settings.RESET_PASSWORD_URL.format(
        reset_token=reset_token,
        user_id=user.id
    )

    # Prepare context data
    context = {
        'app_name': settings.APP_NAME,
        'reset_url': reset_url,
        'email': user.email,
        'user': user,
    }

    # Determine template path based on language
    template_path = f'emails/{language}/forgot_password.html'

    # Fallback to default language if template doesn't exist
    try:
        html_content = render_to_string(template_path, context)
    except:
        # Fallback to default language template
        template_path = f'emails/{DEFAULT_LANGUAGE}/forgot_password.html'
        html_content = render_to_string(template_path, context)

    # Create localized subject
    subjects = {
        'fr': f'Réinitialiser votre mot de passe {settings.APP_NAME}',
        'en': f'Reset Your {settings.APP_NAME} Password'
    }
    subject = subjects.get(language, subjects[DEFAULT_LANGUAGE])

    from_email = settings.DEFAULT_FROM_EMAIL

    # Create email message
    msg = EmailMultiAlternatives(
        subject=subject,
        body=html_content,  # Fallback text content
        from_email=from_email,
        to=[user.email]
    )

    # Attach HTML content
    msg.attach_alternative(html_content, "text/html")

    # Send email
    try:
        msg.send()
        return True
    except Exception as e:
        print(f"Error sending password reset email: {e}")
        return False


def send_invitation_email(invitation, language=None):
    """
    Send invitation email using localized HTML template file

    Args:
        invitation: Invitation object
        language: Language code (fr, en). Defaults to French if not provided or invalid
    """
    # Validate and set language
    if language not in SUPPORTED_LANGUAGES:
        language = DEFAULT_LANGUAGE

    # Prepare context data
    context = {
        'app_name': settings.APP_NAME,
        'invitation_url': f"{settings.WEB_URL}/accept-invitation/{invitation.token}",
        'invitee_email': invitation.invitee_email,
        'inviter_name': f"{invitation.inviter.firstname} {invitation.inviter.lastname}".strip() or invitation.inviter.email,
        'custom_message': invitation.message or '',
        'role': invitation.role.title(),
        'invitation': invitation,
    }

    # Determine template path based on language
    template_path = f'emails/{language}/invitation.html'

    # Fallback to default language if template doesn't exist
    try:
        html_content = render_to_string(template_path, context)
    except:
        # Fallback to default language template
        template_path = f'emails/{DEFAULT_LANGUAGE}/invitation.html'
        html_content = render_to_string(template_path, context)

    # Create localized subject
    subjects = {
        'fr': f'Vous êtes invité à rejoindre {settings.APP_NAME}',
        'en': f'You\'re invited to join {settings.APP_NAME}'
    }
    subject = subjects.get(language, subjects[DEFAULT_LANGUAGE])

    from_email = settings.DEFAULT_FROM_EMAIL

    # Create email message
    msg = EmailMultiAlternatives(
        subject=subject,
        body=html_content,  # Fallback text content
        from_email=from_email,
        to=[invitation.invitee_email]
    )

    # Attach HTML content
    msg.attach_alternative(html_content, "text/html")

    # Test SMTP connection before sending
    success, message = test_smtp_connection()
    log.info(f'SMTP connection test result in send_invitation_email: {message}')

    if not success:
        log.error(f'Cannot send invitation email to {invitation.invitee_email}: {message}')
        return False

    # Send email
    try:
        msg.send()
        log.info(f'Invitation email sent successfully to {invitation.invitee_email}')
        return True
    except Exception as e:
        error_msg = f"Error sending invitation email: {e}"
        log.error(error_msg)
        print(error_msg)
        return False
