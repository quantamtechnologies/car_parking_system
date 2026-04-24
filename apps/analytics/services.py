from __future__ import annotations

from decimal import Decimal
from datetime import date, timedelta

from django.db.models import Count, Sum
from django.db.models.functions import ExtractHour
from django.utils.dateparse import parse_date
from django.utils import timezone

from apps.analytics.models import AnomalyAlert
from apps.billing.models import CashShift, Payment
from apps.parking.models import ParkingSession, ParkingSlot


def _date_range(start=None, end=None):
    now = timezone.localdate()
    if isinstance(start, str):
        start = parse_date(start) or now
    if isinstance(end, str):
        end = parse_date(end) or now
    start = start or now
    end = end or now
    return start, end


def dashboard_metrics(start=None, end=None):
    start, end = _date_range(start, end)
    sessions = ParkingSession.objects.filter(entry_time__date__range=(start, end))
    payments = Payment.objects.filter(confirmed_at__date__range=(start, end), status=Payment.Status.CONFIRMED, method=Payment.Method.CASH)
    total_sessions = sessions.count()
    revenue = payments.aggregate(total=Sum("amount_due")).get("total") or Decimal("0.00")
    occupied = ParkingSlot.objects.filter(status=ParkingSlot.SlotStatus.OCCUPIED).count()
    total_slots = ParkingSlot.objects.exclude(status=ParkingSlot.SlotStatus.OUT_OF_SERVICE).count()
    occupancy_rate = round((occupied / max(total_slots, 1)) * 100, 2)
    peak_hours = list(
        sessions.annotate(hour=ExtractHour("entry_time"))
        .values("hour")
        .annotate(total=Count("id"))
        .order_by("-total", "hour")[:5]
    )
    staff_performance = list(
        payments.values("cashier__id", "cashier__username")
        .annotate(total_revenue=Sum("amount_due"), payments=Count("id"))
        .order_by("-total_revenue", "-payments")[:10]
    )
    day_span = max((end - start).days + 1, 1) if isinstance(start, date) and isinstance(end, date) else 1

    return {
        "date_range": {"start": str(start), "end": str(end)},
        "cars_per_day": total_sessions,
        "revenue_per_day": str(revenue),
        "average_cars_per_day": float(total_sessions / day_span) if day_span else float(total_sessions),
        "peak_hours": peak_hours,
        "staff_performance": staff_performance,
        "occupancy_rate": occupancy_rate,
        "active_sessions": ParkingSession.objects.filter(status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT]).count(),
        "pending_payments": ParkingSession.objects.filter(status=ParkingSession.Status.PENDING_PAYMENT).count(),
        "open_cash_shifts": CashShift.objects.filter(status=CashShift.Status.OPEN).count(),
    }


def detect_anomalies():
    alerts = []
    today = timezone.localdate()
    recent_sessions = ParkingSession.objects.filter(entry_time__date__gte=today - timedelta(days=7))
    today_count = ParkingSession.objects.filter(entry_time__date=today).count()
    recent_count = recent_sessions.count()
    avg_count = recent_count / 7 if recent_count else 0
    if avg_count and today_count < avg_count * 0.7:
        alerts.append(
            {
                "code": "LOW_CAR_COUNT",
                "title": "Low car count versus average",
                "description": "Today's car count is significantly below the 7-day average.",
                "severity": AnomalyAlert.Severity.YELLOW if today_count > 0 else AnomalyAlert.Severity.RED,
                "category": "volume",
                "actual_value": today_count,
                "threshold_value": avg_count,
                "source_date": today,
            }
        )

    revenue_today = (
        Payment.objects.filter(confirmed_at__date=today, status=Payment.Status.CONFIRMED, method=Payment.Method.CASH)
        .aggregate(total=Sum("amount_due"))
        .get("total")
        or Decimal("0.00")
    )
    expected_revenue = ParkingSession.objects.filter(entry_time__date=today).aggregate(total=Sum("total_fee")).get("total") or Decimal("0.00")
    if expected_revenue and revenue_today < expected_revenue * Decimal("0.95"):
        alerts.append(
            {
                "code": "REVENUE_MISMATCH",
                "title": "Revenue mismatch",
                "description": "Cash-in is lower than expected revenue.",
                "severity": AnomalyAlert.Severity.RED,
                "category": "revenue",
                "actual_value": revenue_today,
                "threshold_value": expected_revenue,
                "source_date": today,
            }
        )

    manual_overrides = ParkingSession.objects.filter(entry_time__date=today, manual_override_by__isnull=False).count()
    if manual_overrides > 3:
        alerts.append(
            {
                "code": "EXCESSIVE_OVERRIDE",
                "title": "Excessive manual overrides",
                "description": "Manual overrides exceed the recommended daily limit.",
                "severity": AnomalyAlert.Severity.YELLOW,
                "category": "control",
                "actual_value": manual_overrides,
                "threshold_value": 3,
                "source_date": today,
            }
        )

    for payload in alerts:
        AnomalyAlert.objects.update_or_create(
            code=payload["code"],
            status=AnomalyAlert.Status.OPEN,
            defaults=payload,
        )
    return AnomalyAlert.objects.all()
