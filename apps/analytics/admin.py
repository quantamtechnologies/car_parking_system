from django.contrib import admin

from apps.analytics.models import AnomalyAlert


@admin.register(AnomalyAlert)
class AnomalyAlertAdmin(admin.ModelAdmin):
    list_display = ("code", "title", "severity", "status", "category", "created_at")
    list_filter = ("severity", "status", "category")
    search_fields = ("code", "title", "description")

