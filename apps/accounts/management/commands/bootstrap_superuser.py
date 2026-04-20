from __future__ import annotations

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction


class Command(BaseCommand):
    help = "Create a superuser from command options or DJANGO_SUPERUSER_* environment variables."

    def add_arguments(self, parser):
        parser.add_argument("--username", help="Admin username. Falls back to DJANGO_SUPERUSER_USERNAME.")
        parser.add_argument("--email", default="", help="Admin email address. Falls back to DJANGO_SUPERUSER_EMAIL.")
        parser.add_argument("--password", help="Admin password. Falls back to DJANGO_SUPERUSER_PASSWORD.")
        parser.add_argument("--first-name", default="", help="Optional first name.")
        parser.add_argument("--last-name", default="", help="Optional last name.")
        parser.add_argument(
            "--force",
            action="store_true",
            help="Update an existing user with the same username instead of failing.",
        )

    def handle(self, *args, **options):
        username = self._value_from_option_or_env(options, "username", "DJANGO_SUPERUSER_USERNAME")
        email = self._value_from_option_or_env(options, "email", "DJANGO_SUPERUSER_EMAIL")
        password = self._value_from_option_or_env(options, "password", "DJANGO_SUPERUSER_PASSWORD")
        first_name = self._value_from_option_or_env(options, "first_name", "DJANGO_SUPERUSER_FIRST_NAME")
        last_name = self._value_from_option_or_env(options, "last_name", "DJANGO_SUPERUSER_LAST_NAME")

        if not username:
            raise CommandError("A username is required. Pass --username or set DJANGO_SUPERUSER_USERNAME.")
        if not password:
            raise CommandError("A password is required. Pass --password or set DJANGO_SUPERUSER_PASSWORD.")

        user_model = get_user_model()
        admin_role = getattr(getattr(user_model, "Role", None), "ADMIN", "ADMIN")

        with transaction.atomic():
            user, created = user_model.objects.get_or_create(username=username)
            if not created and not options["force"]:
                raise CommandError(
                    f"User {username!r} already exists. Re-run with --force if you want to reset that account."
                )

            user.email = email or user.email
            user.first_name = first_name or user.first_name
            user.last_name = last_name or user.last_name
            user.is_staff = True
            user.is_superuser = True
            user.is_active = True

            if hasattr(user, "role"):
                user.role = admin_role

            user.set_password(password)
            user.save()

        action = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"{action} superuser {username!r}."))

    @staticmethod
    def _value_from_option_or_env(options, option_name: str, env_name: str) -> str:
        value = options.get(option_name) or os.getenv(env_name, "")
        return value.strip() if isinstance(value, str) else value
