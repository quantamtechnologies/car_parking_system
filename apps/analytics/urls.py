from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.analytics.views import AnomalyAlertViewSet, ChatbotQueryAPIView, DashboardAPIView

router = DefaultRouter()
router.register(r"alerts", AnomalyAlertViewSet, basename="anomaly-alert")

urlpatterns = [
    path("dashboard/", DashboardAPIView.as_view(), name="analytics-dashboard"),
    path("chat/", ChatbotQueryAPIView.as_view(), name="analytics-chat"),
    path("", include(router.urls)),
]

