from django.contrib import admin

from apps.camera.models import OcrScan


@admin.register(OcrScan)
class OcrScanAdmin(admin.ModelAdmin):
    list_display = ("id", "source", "detected_plate", "confirmed_plate", "confidence", "is_confirmed", "created_at")
    list_filter = ("source", "is_confirmed", "created_at")
    search_fields = ("detected_plate", "confirmed_plate", "raw_text")

