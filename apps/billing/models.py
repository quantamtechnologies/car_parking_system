from __future__ import annotations

from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel


class PricingPolicy(TimeStampedModel):
    name = models.CharField(max_length=120)
    base_fee = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    grace_period_minutes = models.PositiveIntegerField(default=0)
    overdue_penalty = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    daily_max_cap = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    special_rules = models.JSONField(default=dict, blank=True)
    is_active = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    effective_from = models.DateTimeField(default=timezone.now)
    effective_to = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-is_active", "-effective_from"]

    def save(self, *args, **kwargs):
        if self.is_active:
            PricingPolicy.objects.exclude(pk=self.pk).filter(is_active=True).update(is_active=False, effective_to=timezone.now())
        super().save(*args, **kwargs)

    def to_snapshot(self) -> dict:
        return {
            "policy_id": self.id,
            "name": self.name,
            "version": self.version,
            "base_fee": str(self.base_fee),
            "hourly_rate": str(self.hourly_rate),
            "grace_period_minutes": self.grace_period_minutes,
            "overdue_penalty": str(self.overdue_penalty),
            "daily_max_cap": str(self.daily_max_cap) if self.daily_max_cap is not None else None,
            "special_rules": self.special_rules or {},
            "effective_from": self.effective_from.isoformat(),
        }

    @staticmethod
    def get_fallback_policy():
        return PricingPolicy(
            name="Fallback policy",
            base_fee=Decimal("0.00"),
            hourly_rate=Decimal("0.00"),
            grace_period_minutes=0,
            overdue_penalty=Decimal("0.00"),
            daily_max_cap=None,
            special_rules={},
            is_active=False,
            version=1,
        )


class CashShift(TimeStampedModel):
    class Status(models.TextChoices):
        OPEN = "OPEN", "Open"
        CLOSED = "CLOSED", "Closed"

    cashier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="cash_shifts")
    opened_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="opened_cash_shifts")
    closed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="closed_cash_shifts",
        null=True,
        blank=True,
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    opened_at = models.DateTimeField(default=timezone.now)
    closed_at = models.DateTimeField(null=True, blank=True)
    opening_cash = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    expected_cash = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    actual_cash = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    difference = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-opened_at"]

    def __str__(self) -> str:
        return f"{self.cashier} ({self.status})"


class Payment(TimeStampedModel):
    class Method(models.TextChoices):
        CASH = "CASH", "Cash"
        OVERRIDE = "OVERRIDE", "Override"

    class Status(models.TextChoices):
        CONFIRMED = "CONFIRMED", "Confirmed"
        OVERRIDDEN = "OVERRIDDEN", "Overridden"
        VOIDED = "VOIDED", "Voided"

    session = models.OneToOneField("parking.ParkingSession", on_delete=models.CASCADE, related_name="payment")
    cashier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="payments")
    cash_shift = models.ForeignKey(CashShift, on_delete=models.SET_NULL, null=True, blank=True, related_name="payments")
    method = models.CharField(max_length=20, choices=Method.choices, default=Method.CASH)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.CONFIRMED)
    amount_due = models.DecimalField(max_digits=12, decimal_places=2)
    amount_tendered = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    change_due = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    receipt_number = models.CharField(max_length=64, unique=True)
    notes = models.TextField(blank=True)
    confirmed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-confirmed_at"]

