from __future__ import annotations

from django.conf import settings
from django.db import models

from apps.common.models import TimeStampedModel
from apps.common.utils import normalize_plate


class OcrScan(TimeStampedModel):
    class Source(models.TextChoices):
        ENTRY = "ENTRY", "Entry"
        EXIT = "EXIT", "Exit"
        MANUAL = "MANUAL", "Manual"

    image = models.ImageField(upload_to="anpr/%Y/%m/%d")
    original_filename = models.CharField(max_length=255, blank=True)
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.ENTRY)
    raw_text = models.TextField(blank=True)
    candidate_plates = models.JSONField(default=list, blank=True)
    detected_plate = models.CharField(max_length=20, blank=True)
    confirmed_plate = models.CharField(max_length=20, blank=True)
    confidence = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_confirmed = models.BooleanField(default=False)
    manual_entry = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        if self.detected_plate:
            self.detected_plate = normalize_plate(self.detected_plate)
        if self.confirmed_plate:
            self.confirmed_plate = normalize_plate(self.confirmed_plate)
        super().save(*args, **kwargs)

    @property
    def final_plate(self) -> str:
        return self.confirmed_plate or self.detected_plate

