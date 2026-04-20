from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models

from apps.common.models import TimeStampedModel


class User(AbstractUser):
    class Role(models.TextChoices):
        ADMIN = "ADMIN", "Admin"
        CASHIER = "CASHIER", "Cashier"
        SECURITY = "SECURITY", "Security"

    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CASHIER)
    phone_number = models.CharField(max_length=32, blank=True)
    employee_code = models.CharField(max_length=32, blank=True, db_index=True)
    is_force_password_change = models.BooleanField(default=False)

    class Meta:
        indexes = [models.Index(fields=["role"])]

    def __str__(self) -> str:
        return f"{self.username} ({self.role})"


class SessionLog(TimeStampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="session_logs")
    login_at = models.DateTimeField(auto_now_add=True)
    logout_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    refresh_jti = models.CharField(max_length=64, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    device_info = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-login_at"]

    def close(self) -> None:
        from django.utils import timezone

        self.logout_at = timezone.now()
        self.is_active = False
        self.save()
