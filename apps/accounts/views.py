from __future__ import annotations

from rest_framework import generics, permissions, response, status, viewsets
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.models import SessionLog
from apps.accounts.serializers import LoginSerializer, LogoutSerializer, SessionLogSerializer, UserSerializer
from apps.common.permissions import IsAdminRole


class LoginView(TokenObtainPairView):
    serializer_class = LoginSerializer


class LogoutView(generics.GenericAPIView):
    serializer_class = LogoutSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return response.Response({"detail": "Logged out successfully."}, status=status.HTTP_200_OK)


class MeView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class SessionLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SessionLog.objects.select_related("user").all()
    serializer_class = SessionLogSerializer
    permission_classes = [IsAdminRole]
    filterset_fields = ["is_active", "user"]
    ordering_fields = ["login_at", "logout_at"]

