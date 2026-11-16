from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.user.models import PasswordResetToken


class Command(BaseCommand):
    help = 'Clean up expired password reset tokens'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        # Find expired tokens
        expired_tokens = PasswordResetToken.objects.filter(
            expires_at__lt=timezone.now()
        )

        count = expired_tokens.count()

        if count == 0:
            self.stdout.write(
                self.style.SUCCESS('No expired tokens found.')
            )
            return

        if dry_run:
            self.stdout.write(
                self.style.WARNING(f'Would delete {count} expired tokens:')
            )
            for token in expired_tokens:
                self.stdout.write(f'  - {token}')
        else:
            # Delete expired tokens
            deleted_count, _ = expired_tokens.delete()
            self.stdout.write(
                self.style.SUCCESS(f'Successfully deleted {deleted_count} expired tokens.')
            )
