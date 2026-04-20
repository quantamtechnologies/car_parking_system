from django.contrib import admin

from apps.config.models import SystemSetting


@admin.register(SystemSetting)
class SystemSettingAdmin(admin.ModelAdmin):
    list_display = ("key", "is_public", "is_editable", "updated_at")
    search_fields = ("key", "description")

