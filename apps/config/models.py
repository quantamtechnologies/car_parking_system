from django.db import models

from apps.common.models import TimeStampedModel


class SystemSetting(TimeStampedModel):
    key = models.CharField(max_length=120, unique=True)
    value = models.JSONField(default=dict, blank=True)
    description = models.TextField(blank=True)
    is_editable = models.BooleanField(default=True)
    is_public = models.BooleanField(default=False)

    class Meta:
        ordering = ["key"]

    def __str__(self) -> str:
        return self.key

