from __future__ import annotations

from django.conf import settings
from django.db import models

from apps.common.models import TimeStampedModel


class AnomalyAlert(TimeStampedModel):
    class Severity(models.TextChoices):
        GREEN = "GREEN", "Green"
        YELLOW = "YELLOW", "Yellow"
        RED = "RED", "Red"

    class Status(models.TextChoices):
        OPEN = "OPEN", "Open"
        RESOLVED = "RESOLVED", "Resolved"

    code = models.CharField(max_length=50, db_index=True)
    title = models.CharField(max_length=150)
    description = models.TextField()
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.GREEN)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    category = models.CharField(max_length=50, blank=True)
    actual_value = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    threshold_value = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    evidence = models.JSONField(default=dict, blank=True)
    source_date = models.DateField(null=True, blank=True)
    resolved_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["status", "-severity", "-created_at"]

