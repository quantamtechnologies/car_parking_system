from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models

from apps.common.models import TimeStampedModel


class AuditLog(TimeStampedModel):
    class Action(models.TextChoices):
        CREATE = "CREATE", "Create"
        UPDATE = "UPDATE", "Update"
        DELETE = "DELETE", "Delete"
        ENTRY = "ENTRY", "Entry"
        EXIT = "EXIT", "Exit"
        PAYMENT = "PAYMENT", "Payment"
        OVERRIDE = "OVERRIDE", "Override"
        LOGIN = "LOGIN", "Login"
        LOGOUT = "LOGOUT", "Logout"

    actor = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=32, choices=Action.choices)
    entity_type = models.CharField(max_length=100)
    entity_id = models.CharField(max_length=64, blank=True)
    content_type = models.ForeignKey(ContentType, null=True, blank=True, on_delete=models.SET_NULL)
    object_id = models.CharField(max_length=64, blank=True)
    content_object = GenericForeignKey("content_type", "object_id")
    before_data = models.JSONField(default=dict, blank=True)
    after_data = models.JSONField(default=dict, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    reason = models.TextField(blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["action"]),
            models.Index(fields=["entity_type", "entity_id"]),
        ]

