from __future__ import annotations

from rest_framework import serializers

from apps.billing.models import CashShift, Payment, PricingPolicy
from apps.parking.serializers import ParkingSessionSerializer


class PricingPolicySerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingPolicy
        fields = [
            "id",
            "name",
            "base_fee",
            "hourly_rate",
            "grace_period_minutes",
            "overdue_penalty",
            "daily_max_cap",
            "special_rules",
            "is_active",
            "version",
            "effective_from",
            "effective_to",
            "notes",
            "created_at",
            "updated_at",
        ]


class CashShiftSerializer(serializers.ModelSerializer):
    class Meta:
        model = CashShift
        fields = [
            "id",
            "cashier",
            "opened_by",
            "closed_by",
            "status",
            "opened_at",
            "closed_at",
            "opening_cash",
            "expected_cash",
            "actual_cash",
            "difference",
            "notes",
        ]
        read_only_fields = ["opened_by", "closed_by", "expected_cash", "difference", "status", "opened_at", "closed_at"]


class CashShiftOpenSerializer(serializers.Serializer):
    cashier_id = serializers.IntegerField()
    opening_cash = serializers.DecimalField(max_digits=12, decimal_places=2)
    notes = serializers.CharField(required=False, allow_blank=True)


class CashShiftCloseSerializer(serializers.Serializer):
    actual_cash = serializers.DecimalField(max_digits=12, decimal_places=2)
    notes = serializers.CharField(required=False, allow_blank=True)


class CashPaymentSerializer(serializers.Serializer):
    session_id = serializers.IntegerField()
    amount_tendered = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default="0.00")
    cash_shift_id = serializers.IntegerField(required=False)
    notes = serializers.CharField(required=False, allow_blank=True)
    override = serializers.BooleanField(required=False, default=False)
    override_reason = serializers.CharField(required=False, allow_blank=True)


class PaymentSerializer(serializers.ModelSerializer):
    session = ParkingSessionSerializer(read_only=True)

    class Meta:
        model = Payment
        fields = [
            "id",
            "session",
            "cashier",
            "cash_shift",
            "method",
            "status",
            "amount_due",
            "amount_tendered",
            "change_due",
            "receipt_number",
            "notes",
            "confirmed_at",
            "created_at",
        ]
