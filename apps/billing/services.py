from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.audit.services import record_audit_event
from apps.billing.models import CashShift, Payment, PricingPolicy
from apps.common.utils import build_receipt_number
from apps.parking.models import ParkingSession
from apps.parking.services import calculate_fee_breakdown, close_session_after_payment


def get_active_pricing_policy() -> PricingPolicy:
    policy = PricingPolicy.objects.filter(is_active=True).order_by("-effective_from", "-version").first()
    return policy or PricingPolicy.get_fallback_policy()


@transaction.atomic
def open_cash_shift(*, cashier, opened_by, opening_cash: Decimal, notes: str = "") -> CashShift:
    if CashShift.objects.filter(cashier=cashier, status=CashShift.Status.OPEN).exists():
        raise ValidationError({"cashier": "Cashier already has an open shift."})
    shift = CashShift.objects.create(
        cashier=cashier,
        opened_by=opened_by,
        opening_cash=opening_cash,
        notes=notes,
        status=CashShift.Status.OPEN,
    )
    record_audit_event(actor=opened_by, action="CREATE", entity=shift, after_data={"opening_cash": str(opening_cash)})
    return shift


@transaction.atomic
def close_cash_shift(*, shift: CashShift, closed_by, actual_cash: Decimal, notes: str = "") -> CashShift:
    shift = CashShift.objects.select_for_update().get(pk=shift.pk)
    if shift.status != CashShift.Status.OPEN:
        raise ValidationError({"shift": "Shift is already closed."})
    shift.actual_cash = actual_cash
    shift.expected_cash = (
        shift.opening_cash
        + (
            shift.payments.filter(status=Payment.Status.CONFIRMED, method=Payment.Method.CASH).aggregate(total=Sum("amount_due")).get("total")
            or Decimal("0.00")
        )
    )
    shift.difference = (actual_cash - shift.expected_cash).quantize(Decimal("0.01"))
    shift.closed_by = closed_by
    shift.closed_at = timezone.now()
    shift.status = CashShift.Status.CLOSED
    shift.notes = notes
    shift.save()
    record_audit_event(
        actor=closed_by,
        action="UPDATE",
        entity=shift,
        after_data={"actual_cash": str(actual_cash), "difference": str(shift.difference)},
    )
    return shift


@transaction.atomic
def confirm_cash_payment(
    *,
    session: ParkingSession,
    cashier,
    amount_tendered: Decimal,
    cash_shift: CashShift | None = None,
    notes: str = "",
    override: bool = False,
    override_reason: str = "",
):
    session = ParkingSession.objects.select_for_update().select_related("slot", "vehicle").get(pk=session.pk)
    if session.status != ParkingSession.Status.PENDING_PAYMENT and not override:
        raise ValidationError({"session": "Session must be pending payment before confirmation."})

    if not session.total_fee or session.total_fee == Decimal("0.00"):
        breakdown = calculate_fee_breakdown(session)
        session.total_fee = breakdown["total_fee"]
        session.save(update_fields=["total_fee", "updated_at"])

    amount_due = session.total_fee
    if override:
        if getattr(cashier, "role", None) != "ADMIN" and not getattr(cashier, "is_superuser", False):
            raise ValidationError({"override": "Only admins can override payment and exit without cash."})
        payment_method = Payment.Method.OVERRIDE
        payment_status = Payment.Status.OVERRIDDEN
        amount_tendered = Decimal("0.00")
        change_due = Decimal("0.00")
        paid_amount = Decimal("0.00")
        if not override_reason:
            raise ValidationError({"reason": "Override reason is required."})
    else:
        payment_method = Payment.Method.CASH
        payment_status = Payment.Status.CONFIRMED
        if amount_tendered < amount_due:
            raise ValidationError({"amount_tendered": "Amount tendered cannot be less than the amount due."})
        change_due = (amount_tendered - amount_due).quantize(Decimal("0.01"))
        paid_amount = amount_due

    payment = Payment.objects.create(
        session=session,
        cashier=cashier,
        cash_shift=cash_shift,
        method=payment_method,
        status=payment_status,
        amount_due=amount_due,
        amount_tendered=amount_tendered,
        change_due=change_due,
        receipt_number=build_receipt_number(),
        notes=notes or override_reason,
    )
    close_session_after_payment(
        session=session,
        actor=cashier,
        payment_amount=paid_amount,
        cash_shift=cash_shift,
        payment_method=payment_method,
        receipt_number=payment.receipt_number,
        notes=notes,
        override_reason=override_reason,
    )
    record_audit_event(
        actor=cashier,
        action="PAYMENT",
        entity=payment,
        after_data={
            "session_id": session.id,
            "amount_due": str(amount_due),
            "amount_tendered": str(amount_tendered),
            "change_due": str(change_due),
            "receipt_number": payment.receipt_number,
            "payment_method": payment_method,
        },
        reason=notes or override_reason,
    )
    return payment
