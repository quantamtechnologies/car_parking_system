from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command, CommandError
from django.test import SimpleTestCase, TestCase, override_settings


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
