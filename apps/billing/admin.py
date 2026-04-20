from django.contrib import admin

from apps.billing.models import CashShift, Payment, PricingPolicy


@admin.register(PricingPolicy)
class PricingPolicyAdmin(admin.ModelAdmin):
    list_display = ("name", "version", "is_active", "effective_from")
    list_filter = ("is_active",)
    search_fields = ("name", "notes")


@admin.register(CashShift)
class CashShiftAdmin(admin.ModelAdmin):
    list_display = ("cashier", "status", "opened_at", "closed_at", "difference")
    list_filter = ("status", "opened_at")
    search_fields = ("cashier__username", "notes")


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("receipt_number", "session", "cashier", "method", "amount_due", "amount_tendered", "change_due")
    list_filter = ("method", "status", "confirmed_at")
    search_fields = ("receipt_number", "session__vehicle__plate_number")

