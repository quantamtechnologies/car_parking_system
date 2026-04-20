from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView

from project.views import api_root, healthcheck, root


urlpatterns = [
    path("", root, name="root"),
    path("api/", api_root, name="api-root"),
    path("health/", healthcheck, name="health"),
    path("admin/", admin.site.urls),
    path("api/health/", healthcheck, name="api-health"),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/parking/", include("apps.parking.urls")),
    path("api/billing/", include("apps.billing.urls")),
    path("api/camera/", include("apps.camera.urls")),
    path("api/analytics/", include("apps.analytics.urls")),
    path("api/audit/", include("apps.audit.urls")),
    path("api/config/", include("apps.config.urls")),
]
