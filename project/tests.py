from io import StringIO
from itertools import count
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command, CommandError
from django.test import SimpleTestCase, TestCase, override_settings
from django.db import OperationalError

from apps.accounts.startup import ensure_default_superuser
import project.settings as project_settings


class ProjectUrlTests(SimpleTestCase):
    def test_root_returns_plain_text_status(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["Content-Type"], "text/plain; charset=utf-8")
        self.assertEqual(response.content.decode("utf-8"), "Smart Car Parking System is running")

    def test_api_root_returns_service_metadata(self):
        response = self.client.get("/api/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertEqual(response.json()["health"], "/health/")
        self.assertEqual(response.json()["schema"], "/api/schema/")

    def test_health_endpoint_returns_ok(self):
        response = self.client.get("/health/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_health_endpoint_accepts_railway_healthcheck_host(self):
        response = self.client.get("/health/", HTTP_HOST="healthcheck.railway.app")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    @override_settings(SECURE_SSL_REDIRECT=True, SECURE_REDIRECT_EXEMPT=[r"^health/$", r"^api/health/$"])
    def test_health_endpoint_stays_available_when_ssl_redirect_is_enabled(self):
        response = self.client.get("/health/", HTTP_HOST="healthcheck.railway.app")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_legacy_api_health_alias_still_works(self):
        response = self.client.get("/api/health/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})


class SecretKeyValidationTests(SimpleTestCase):
    def test_short_explicit_secret_is_allowed_in_production(self):
        self.assertEqual(
            project_settings._validate_secret_key("short-secret", debug=False),
            "short-secret",
        )

    def test_missing_secret_is_rejected_in_production(self):
        with self.assertRaises(ImproperlyConfigured):
            project_settings._validate_secret_key("", debug=False)

    def test_default_development_secret_is_rejected_in_production(self):
        with self.assertRaises(ImproperlyConfigured):
            project_settings._validate_secret_key("unsafe-development-key", debug=False)


class BootstrapSuperuserTests(TestCase):
    def test_bootstrap_superuser_creates_admin_account(self):
        stdout = StringIO()

        call_command(
            "bootstrap_superuser",
            username="admin",
            email="admin@example.com",
            password="StrongPass123!",
            stdout=stdout,
        )

        user = get_user_model().objects.get(username="admin")
        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)
        self.assertEqual(user.role, get_user_model().Role.ADMIN)
        self.assertTrue(user.check_password("StrongPass123!"))
        self.assertIn("Created superuser 'admin'.", stdout.getvalue())

    def test_bootstrap_superuser_rejects_existing_user_without_force(self):
        user_model = get_user_model()
        user_model.objects.create_user(username="admin", password="OldPass123!", role=user_model.Role.CASHIER)

        with self.assertRaises(CommandError):
            call_command(
                "bootstrap_superuser",
                username="admin",
                password="NewPass123!",
            )


class DefaultSuperuserStartupTests(TestCase):
    @override_settings(
        AUTO_CREATE_DEFAULT_SUPERUSER=True,
        DEFAULT_SUPERUSER_USERNAME="admin",
        DEFAULT_SUPERUSER_PASSWORD="admin12345",
        DEFAULT_SUPERUSER_EMAIL="admin@example.com",
    )
    def test_ensure_default_superuser_creates_missing_admin_once(self):
        first_call = ensure_default_superuser()
        second_call = ensure_default_superuser()

        user_model = get_user_model()
        user = user_model.objects.get(username="admin")

        self.assertTrue(first_call)
        self.assertFalse(second_call)
        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)
        self.assertEqual(user.role, user_model.Role.ADMIN)
        self.assertTrue(user.check_password("admin12345"))
        self.assertEqual(user_model.objects.filter(username="admin").count(), 1)

    @override_settings(AUTO_CREATE_DEFAULT_SUPERUSER=False)
    def test_ensure_default_superuser_can_be_disabled(self):
        self.assertFalse(ensure_default_superuser())
        self.assertFalse(get_user_model().objects.filter(username="admin").exists())

    @override_settings(
        AUTO_CREATE_DEFAULT_SUPERUSER=True,
        AUTO_RESET_DEFAULT_SUPERUSER_PASSWORD=True,
        DEFAULT_SUPERUSER_USERNAME="admin",
        DEFAULT_SUPERUSER_PASSWORD="FreshPass123!",
        DEFAULT_SUPERUSER_EMAIL="admin@example.com",
    )
    def test_ensure_default_superuser_can_repair_existing_account(self):
        user_model = get_user_model()
        user_model.objects.create_user(username="admin", password="OldPass123!", role=user_model.Role.CASHIER)

        created = ensure_default_superuser()

        user = user_model.objects.get(username="admin")

        self.assertFalse(created)
        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)
        self.assertEqual(user.role, user_model.Role.ADMIN)
        self.assertTrue(user.check_password("FreshPass123!"))


class DeployMigrateCommandTests(SimpleTestCase):
    @mock.patch("apps.config.management.commands.deploy_migrate.call_command")
    @mock.patch("apps.config.management.commands.deploy_migrate.connections")
    @mock.patch("apps.config.management.commands.deploy_migrate.sleep", return_value=None)
    @mock.patch("apps.config.management.commands.deploy_migrate.monotonic")
    def test_command_retries_database_and_runs_migrations(
        self,
        mock_monotonic,
        mock_sleep,
        mock_connections,
        mock_call_command,
    ):
        connection = mock.Mock()
        connection.ensure_connection.side_effect = [OperationalError("temporary dns failure"), None]
        mock_connections.__getitem__.return_value = connection
        mock_monotonic.side_effect = count()

        stdout = StringIO()
        call_command("deploy_migrate", timeout=5, interval=1, migrate_retries=1, stdout=stdout)

        self.assertGreaterEqual(connection.ensure_connection.call_count, 2)
        mock_call_command.assert_called_once_with(
            "migrate",
            database="default",
            run_syncdb=True,
            interactive=False,
            verbosity=0,
        )
        mock_sleep.assert_called_once()
        self.assertIn("Database 'default' is reachable.", stdout.getvalue())
