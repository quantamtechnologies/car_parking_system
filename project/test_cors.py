from django.conf import settings
from django.test import Client, TestCase


class CorsConfigurationTests(TestCase):
    def test_netlify_origin_is_whitelisted(self):
        origin = "https://smart-car-packing-systems.netlify.app"

        self.assertIn(origin, settings.CORS_ALLOWED_ORIGINS)
        self.assertIn(origin, settings.CSRF_TRUSTED_ORIGINS)

    def test_login_preflight_includes_cors_headers(self):
        origin = "https://smart-car-packing-systems.netlify.app"
        client = Client(HTTP_ORIGIN=origin)

        response = client.options(
            "/api/auth/login/",
            HTTP_ACCESS_CONTROL_REQUEST_METHOD="POST",
            HTTP_ACCESS_CONTROL_REQUEST_HEADERS="content-type",
        )

        self.assertLess(response.status_code, 400)
        self.assertEqual(response.headers.get("Access-Control-Allow-Origin"), origin)
        self.assertEqual(response.headers.get("Access-Control-Allow-Credentials"), "true")
