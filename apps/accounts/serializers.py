from __future__ import annotations

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.utils import timezone

from apps.accounts.models import SessionLog, User
from apps.audit.services import record_audit_event


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "phone_number",
            "employee_code",
            "is_staff",
            "is_superuser",
        ]


class LoginSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        request = self.context.get("request")
        session = SessionLog.objects.create(
            user=self.user,
            ip_address=self._get_ip(request),
            device_info=self._get_device_info(request),
        )
        record_audit_event(
            actor=self.user,
            action="LOGIN",
            entity=session,
            after_data={"username": self.user.username, "session_id": session.id},
            request=request,
        )
        data["user"] = UserSerializer(self.user).data
        data["session_id"] = session.id
        data["refresh_token_type"] = "jwt"
        return data

    @staticmethod
    def _get_ip(request):
        if not request:
            return None
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR")

    @staticmethod
    def _get_device_info(request):
        if not request:
            return ""
        return request.META.get("HTTP_USER_AGENT", "")[:255]


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(required=False, allow_blank=True)
    session_id = serializers.IntegerField(required=False)

    def save(self, **kwargs):
        refresh = self.validated_data.get("refresh")
        session_id = self.validated_data.get("session_id")
        if refresh:
            try:
                token = RefreshToken(refresh)
                token.blacklist()
            except TokenError:
                pass
        if session_id:
            session = SessionLog.objects.filter(id=session_id, is_active=True).select_related("user").first()
            if session:
                session.logout_at = timezone.now()
                session.is_active = False
                session.save()
                record_audit_event(
                    actor=session.user,
                    action="LOGOUT",
                    entity=session,
                    after_data={"session_id": session.id, "username": session.user.username},
                )
        return {"detail": "Logged out successfully."}


class SessionLogSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = SessionLog
        fields = ["id", "user", "login_at", "logout_at", "is_active", "ip_address", "device_info"]
