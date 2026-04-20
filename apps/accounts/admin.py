from django.contrib import admin

from apps.accounts.models import SessionLog, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("username", "email", "role", "is_staff", "is_active")
    list_filter = ("role", "is_staff", "is_active")
    search_fields = ("username", "email", "phone_number", "employee_code")


@admin.register(SessionLog)
class SessionLogAdmin(admin.ModelAdmin):
    list_display = ("user", "login_at", "logout_at", "is_active", "ip_address")
    list_filter = ("is_active", "login_at")
    search_fields = ("user__username", "user__email", "device_info")

