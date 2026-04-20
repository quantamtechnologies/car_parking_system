from __future__ import annotations

from decimal import Decimal

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

from apps.common.models import TimeStampedModel
from apps.common.utils import normalize_plate


class ParkingZone(TimeStampedModel):
    class ZoneType(models.TextChoices):
        VIP = "VIP", "VIP"
        REGULAR = "REGULAR", "Regular"
        RESERVED = "RESERVED", "Reserved"

    name = models.CharField(max_length=80, unique=True)
    zone_type = models.CharField(max_length=20, choices=ZoneType.choices, default=ZoneType.REGULAR)
    priority = models.PositiveSmallIntegerField(default=100)
    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ["priority", "name"]

    def __str__(self) -> str:
        return f"{self.name} ({self.zone_type})"


class ParkingSlot(TimeStampedModel):
    class SlotStatus(models.TextChoices):
        AVAILABLE = "AVAILABLE", "Available"
        OCCUPIED = "OCCUPIED", "Occupied"
        OUT_OF_SERVICE = "OUT_OF_SERVICE", "Out of service"

    zone = models.ForeignKey(ParkingZone, on_delete=models.CASCADE, related_name="slots")
    code = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=SlotStatus.choices, default=SlotStatus.AVAILABLE)
    is_manual_only = models.BooleanField(default=False)
    notes = models.TextField(blank=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["zone", "code"], name="unique_slot_per_zone")]
        ordering = ["zone__priority", "zone__name", "code"]

    def __str__(self) -> str:
        return f"{self.zone.name}-{self.code}"


class Vehicle(TimeStampedModel):
    class VehicleType(models.TextChoices):
        CAR = "CAR", "Car"
        SUV = "SUV", "SUV"
        VAN = "VAN", "Van"
        TRUCK = "TRUCK", "Truck"
        BIKE = "BIKE", "Motorbike"
        OTHER = "OTHER", "Other"

    plate_number = models.CharField(max_length=20, unique=True, db_index=True)
    vehicle_type = models.CharField(max_length=20, choices=VehicleType.choices, default=VehicleType.CAR)
    owner_name = models.CharField(max_length=120, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["plate_number"]

    def save(self, *args, **kwargs):
        self.plate_number = normalize_plate(self.plate_number)
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.plate_number


class ParkingSession(TimeStampedModel):
    class Status(models.TextChoices):
        ACTIVE = "ACTIVE", "Active"
        PENDING_PAYMENT = "PENDING_PAYMENT", "Pending payment"
        CLOSED = "CLOSED", "Closed"
        CANCELLED = "CANCELLED", "Cancelled"

    vehicle = models.ForeignKey(Vehicle, on_delete=models.PROTECT, related_name="sessions")
    slot = models.ForeignKey(ParkingSlot, on_delete=models.PROTECT, related_name="sessions")
    entry_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="entry_sessions")
    exit_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="exit_sessions",
        null=True,
        blank=True,
    )
    entry_time = models.DateTimeField(default=timezone.now)
    exit_time = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE, db_index=True)
    entry_scan = models.ForeignKey(
        "camera.OcrScan",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="entry_sessions",
    )
    exit_scan = models.ForeignKey(
        "camera.OcrScan",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="exit_sessions",
    )
    pricing_snapshot = models.JSONField(default=dict, blank=True)
    duration_minutes = models.PositiveIntegerField(default=0)
    base_fee = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    rate_per_hour = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    grace_period_minutes = models.PositiveIntegerField(default=0)
    extra_charges = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    penalty_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    daily_max_cap = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    total_fee = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    manual_override_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="manual_exit_sessions",
    )
    manual_override_reason = models.TextField(blank=True)

    class Meta:
        ordering = ["-entry_time"]
        constraints = [
            models.UniqueConstraint(
                fields=["vehicle"],
                condition=Q(status__in=["ACTIVE", "PENDING_PAYMENT"]),
                name="unique_active_vehicle_session",
            ),
            models.UniqueConstraint(
                fields=["slot"],
                condition=Q(status__in=["ACTIVE", "PENDING_PAYMENT"]),
                name="unique_active_slot_session",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.vehicle.plate_number} @ {self.slot}"

