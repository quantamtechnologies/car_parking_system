from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from apps.accounts.forms import UserChangeForm, UserCreationForm
from apps.accounts.models import SessionLog, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    add_form = UserCreationForm
    form = UserChangeForm
    model = User
    list_display = ("username", "email", "role", "is_staff", "is_superuser", "is_active")
    list_filter = ("role", "is_staff", "is_superuser", "is_active")
    search_fields = ("username", "email", "phone_number", "employee_code")
    ordering = ("username",)
    fieldsets = (
        (None, {"fields": ("username", "password")}),
        (
            "Personal info",
            {
                "fields": (
                    "first_name",
                    "last_name",
                    "email",
                    "role",
                    "phone_number",
                    "employee_code",
                    "is_force_password_change",
                )
            },
        ),
        (
            "Permissions",
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                )
            },
        ),
        ("Important dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": (
                    "username",
                    "email",
                    "password1",
                    "password2",
                    "first_name",
                    "last_name",
                    "role",
                    "phone_number",
                    "employee_code",
                    "is_force_password_change",
                ),
            },
        ),
    )
    filter_horizontal = ("groups", "user_permissions")


@admin.register(SessionLog)
class SessionLogAdmin(admin.ModelAdmin):
    list_display = ("user", "login_at", "logout_at", "is_active", "ip_address")
    list_filter = ("is_active", "login_at")
    search_fields = ("user__username", "user__email", "device_info")
