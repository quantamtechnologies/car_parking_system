from __future__ import annotations

import math
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.audit.services import record_audit_event
from apps.billing.models import PricingPolicy
from apps.common.utils import normalize_plate
from apps.parking.models import ParkingSession, ParkingSlot, ParkingZone, Vehicle


def active_session_queryset():
    return ParkingSession.objects.select_related(
        "vehicle",
        "slot",
        "slot__zone",
        "entry_by",
        "exit_by",
        "entry_scan",
        "exit_scan",
    )


def get_active_pricing_policy():
    policy = PricingPolicy.objects.filter(is_active=True).order_by("-effective_from", "-version").first()
    return policy or PricingPolicy.get_fallback_policy()


def pricing_snapshot(policy: PricingPolicy) -> dict:
    return policy.to_snapshot()


def assign_slot(*, zone_preference: str | None = None) -> ParkingSlot:
    slots = ParkingSlot.objects.select_related("zone").select_for_update().filter(
        status=ParkingSlot.SlotStatus.AVAILABLE,
        zone__is_active=True,
    )
    if zone_preference:
        preferred = slots.filter(zone__zone_type=zone_preference)
        if preferred.exists():
            slots = preferred
    slot = slots.order_by("zone__priority", "zone__name", "code").first()
    if not slot:
        raise ValidationError({"slot": "No available parking slot found."})
    slot.status = ParkingSlot.SlotStatus.OCCUPIED
    slot.save(update_fields=["status", "updated_at"])
    return slot


def normalize_vehicle_plate(plate: str) -> str:
    return normalize_plate(plate)


def get_active_session_for_plate(plate: str):
    return (
        active_session_queryset()
        .filter(vehicle__plate_number=normalize_vehicle_plate(plate), status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT])
        .order_by("-entry_time")
        .first()
    )


def register_vehicle(*, plate_number: str, vehicle_type: str = Vehicle.VehicleType.CAR, owner_name: str = "", phone_number: str = "") -> Vehicle:
    plate_number = normalize_vehicle_plate(plate_number)
    if not plate_number:
        raise ValidationError({"plate_number": "Plate number is required."})
    vehicle, _ = Vehicle.objects.update_or_create(
        plate_number=plate_number,
        defaults={"vehicle_type": vehicle_type, "owner_name": owner_name, "phone_number": phone_number, "is_active": True},
    )
    return vehicle


def calculate_fee_breakdown(session: ParkingSession, *, end_time=None) -> dict:
    end_time = end_time or timezone.now()
    duration_minutes = max(0, int((end_time - session.entry_time).total_seconds() // 60))
    snapshot = session.pricing_snapshot or {}
    base_fee = Decimal(str(snapshot.get("base_fee", "0.00")))
    rate_per_hour = Decimal(str(snapshot.get("hourly_rate", "0.00")))
    grace_period_minutes = int(snapshot.get("grace_period_minutes", 0))
    daily_max_cap = snapshot.get("daily_max_cap")
    daily_max_cap = Decimal(str(daily_max_cap)) if daily_max_cap not in (None, "") else None
    penalty_amount = Decimal(str(snapshot.get("overdue_penalty", "0.00")))
    special_rules = snapshot.get("special_rules") or {}
    extra_charges = Decimal("0.00")
    if isinstance(special_rules, dict):
        for value in special_rules.values():
            try:
                extra_charges += Decimal(str(value))
            except Exception:
                continue

    billable_minutes = max(0, duration_minutes - grace_period_minutes)
    billable_hours = Decimal("0.00")
    if billable_minutes > 0:
        billable_hours = Decimal(str(math.ceil(billable_minutes / 60)))

    hourly_charge = billable_hours * rate_per_hour
    total = base_fee + hourly_charge + extra_charges + penalty_amount
    if daily_max_cap is not None:
        total = min(total, daily_max_cap)
    total = total.quantize(Decimal("0.01"))

    return {
        "duration_minutes": duration_minutes,
        "billable_minutes": billable_minutes,
        "billable_hours": billable_hours,
        "base_fee": base_fee.quantize(Decimal("0.01")),
        "hourly_charge": hourly_charge.quantize(Decimal("0.01")),
        "extra_charges": extra_charges.quantize(Decimal("0.01")),
        "penalty_amount": penalty_amount.quantize(Decimal("0.01")),
        "daily_max_cap": daily_max_cap.quantize(Decimal("0.01")) if daily_max_cap is not None else None,
        "total_fee": total,
    }


@transaction.atomic
def start_parking_session(
    *,
    vehicle: Vehicle,
    actor,
    zone_preference: str | None = None,
    entry_scan=None,
    requested_slot: ParkingSlot | None = None,
):
    if ParkingSession.objects.filter(vehicle=vehicle, status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT]).exists():
        raise ValidationError({"vehicle": "Vehicle already has an active parking session."})

    if requested_slot:
        slot = ParkingSlot.objects.select_related("zone").select_for_update().get(pk=requested_slot.pk)
        if slot.status != ParkingSlot.SlotStatus.AVAILABLE:
            raise ValidationError({"slot": "Requested slot is not available."})
        slot.status = ParkingSlot.SlotStatus.OCCUPIED
        slot.save(update_fields=["status", "updated_at"])
    else:
        slot = assign_slot(zone_preference=zone_preference)

    policy = get_active_pricing_policy()
    session = ParkingSession.objects.create(
        vehicle=vehicle,
        slot=slot,
        entry_by=actor,
        entry_scan=entry_scan,
        pricing_snapshot=pricing_snapshot(policy),
        base_fee=policy.base_fee,
        rate_per_hour=policy.hourly_rate,
        grace_period_minutes=policy.grace_period_minutes,
        penalty_amount=policy.overdue_penalty,
        daily_max_cap=policy.daily_max_cap,
        total_fee=policy.base_fee,
        status=ParkingSession.Status.ACTIVE,
    )
    if entry_scan:
        entry_scan.confirmed_plate = vehicle.plate_number
        entry_scan.is_confirmed = True
        entry_scan.manual_entry = not bool(entry_scan.detected_plate)
        entry_scan.save(update_fields=["confirmed_plate", "is_confirmed", "manual_entry", "updated_at"])
    record_audit_event(
        actor=actor,
        action="ENTRY",
        entity=session,
        after_data={"vehicle": vehicle.plate_number, "slot": str(slot), "pricing": session.pricing_snapshot},
    )
    return session


@transaction.atomic
def prepare_exit_session(*, session: ParkingSession, actor, exit_scan=None):
    if session.status not in [ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT]:
        raise ValidationError({"session": "Session is not eligible for exit preparation."})
    breakdown = calculate_fee_breakdown(session)
    session.duration_minutes = breakdown["duration_minutes"]
    session.base_fee = breakdown["base_fee"]
    session.rate_per_hour = Decimal(str(session.pricing_snapshot.get("hourly_rate", "0.00")))
    session.grace_period_minutes = int(session.pricing_snapshot.get("grace_period_minutes", 0))
    session.extra_charges = breakdown["extra_charges"]
    session.penalty_amount = breakdown["penalty_amount"]
    session.daily_max_cap = breakdown["daily_max_cap"]
    session.total_fee = breakdown["total_fee"]
    session.status = ParkingSession.Status.PENDING_PAYMENT
    if exit_scan:
        session.exit_scan = exit_scan
        exit_scan.confirmed_plate = session.vehicle.plate_number
        exit_scan.is_confirmed = True
        exit_scan.manual_entry = not bool(exit_scan.detected_plate)
        exit_scan.save(update_fields=["confirmed_plate", "is_confirmed", "manual_entry", "updated_at"])
    session.save()
    record_audit_event(
        actor=actor,
        action="EXIT",
        entity=session,
        after_data={"duration_minutes": session.duration_minutes, "total_fee": str(session.total_fee)},
    )
    return session, breakdown


@transaction.atomic
def close_session_after_payment(*, session: ParkingSession, actor, payment_amount: Decimal, cash_shift=None, payment_method="CASH", receipt_number="", notes="", override_reason=""):
    session = ParkingSession.objects.select_for_update().select_related("slot", "vehicle").get(pk=session.pk)
    if session.status != ParkingSession.Status.PENDING_PAYMENT and payment_method != "OVERRIDE":
        raise ValidationError({"session": "Session must be pending payment before closing."})
    session.exit_time = timezone.now()
    session.exit_by = actor
    session.amount_paid = payment_amount
    session.status = ParkingSession.Status.CLOSED
    session.slot.status = ParkingSlot.SlotStatus.AVAILABLE
    session.slot.save(update_fields=["status", "updated_at"])
    session.save()
    record_audit_event(
        actor=actor,
        action="PAYMENT",
        entity=session,
        after_data={"payment_amount": str(payment_amount), "receipt_number": receipt_number, "payment_method": payment_method},
        reason=notes or override_reason,
    )
    return session


def get_dashboard_snapshot():
    active_sessions = active_session_queryset().filter(status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT])
    occupied_slots = ParkingSlot.objects.filter(status=ParkingSlot.SlotStatus.OCCUPIED).count()
    available_slots = ParkingSlot.objects.filter(status=ParkingSlot.SlotStatus.AVAILABLE).count()
    total_slots = ParkingSlot.objects.exclude(status=ParkingSlot.SlotStatus.OUT_OF_SERVICE).count()
    return {
        "active_sessions": active_sessions.count(),
        "occupied_slots": occupied_slots,
        "available_slots": available_slots,
        "occupancy_rate": round((occupied_slots / max(total_slots, 1)) * 100, 2),
    }
