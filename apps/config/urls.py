from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.config.views import SystemSettingViewSet

router = DefaultRouter()
router.register(r"settings", SystemSettingViewSet, basename="system-setting")

urlpatterns = [
    path("", include(router.urls)),
]

