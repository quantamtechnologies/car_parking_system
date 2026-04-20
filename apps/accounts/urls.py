from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from apps.accounts.views import LoginView, LogoutView, MeView, SessionLogViewSet


session_log_list = SessionLogViewSet.as_view({"get": "list"})
session_log_detail = SessionLogViewSet.as_view({"get": "retrieve"})

urlpatterns = [
    path("login/", LoginView.as_view(), name="auth-login"),
    path("refresh/", TokenRefreshView.as_view(), name="auth-refresh"),
    path("logout/", LogoutView.as_view(), name="auth-logout"),
    path("me/", MeView.as_view(), name="auth-me"),
    path("sessions/", session_log_list, name="auth-session-list"),
    path("sessions/<int:pk>/", session_log_detail, name="auth-session-detail"),
]

