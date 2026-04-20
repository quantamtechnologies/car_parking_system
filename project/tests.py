from django.test import SimpleTestCase
from django.test import override_settings


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
