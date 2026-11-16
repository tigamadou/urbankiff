import os

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from rolepermissions.roles import assign_role
from rolepermissions.checkers import has_role


class Command(BaseCommand):
    help = 'This function create an admin user seed for pre-prod and prod env'

    def handle(self, *args, **kwargs):
        password = os.environ.get("DJANGO_SUPERUSER_PASSWORD")
        if get_user_model().objects.filter(email="urbankiff@admin.com").exists():
            self.stdout.write(self.style.ERROR('Admin with email <<urbankiff@admin.com>> already exist !'))

        elif not password:
            self.stdout.write(self.style.WARNING('DJANGO_SUPERUSER_PASSWORD is not set: admin user not created'))

        else:
            user = get_user_model().objects.create_superuser(
                email="urbankiff@admin.com",
                password=password,
                contact="22999999999",
                firstname="Admin",
                lastname="Admin",
                status="active",
                avatar="images/fck2c7a8-gc4v-4q3s-behi-5fhnqti9mak4.jpg"
            )
            user.save()
            if not has_role(user, "administrator"):
                assign_role(user, "administrator")

            self.stdout.write(self.style.SUCCESS('Admin user created !'))
