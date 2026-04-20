from __future__ import annotations

from rest_framework import serializers

from apps.accounts.serializers import UserSerializer
from apps.camera.serializers import OcrScanSerializer
from apps.common.utils import normalize_plate
from apps.parking.models import ParkingSession, ParkingSlot, ParkingZone, Vehicle


class ParkingZoneSerializer(serializers.ModelSerializer):
    available_slots = serializers.SerializerMethodField()
    occupied_slots = serializers.SerializerMethodField()

    class Meta:
        model = ParkingZone
        fields = ["id", "name", "zone_type", "priority", "is_active", "notes", "available_slots", "occupied_slots"]

    def get_available_slots(self, obj):
        return obj.slots.filter(status=ParkingSlot.SlotStatus.AVAILABLE).count()

    def get_occupied_slots(self, obj):
        return obj.slots.filter(status=ParkingSlot.SlotStatus.OCCUPIED).count()


class ParkingSlotSerializer(serializers.ModelSerializer):
    zone = ParkingZoneSerializer(read_only=True)
    zone_id = serializers.PrimaryKeyRelatedField(source="zone", queryset=ParkingZone.objects.all(), write_only=True)

    class Meta:
        model = ParkingSlot
        fields = ["id", "zone", "zone_id", "code", "status", "is_manual_only", "notes", "created_at", "updated_at"]


class VehicleSerializer(serializers.ModelSerializer):
    plate_number = serializers.CharField()

    class Meta:
        model = Vehicle
        fields = ["id", "plate_number", "vehicle_type", "owner_name", "phone_number", "is_active", "created_at", "updated_at"]

    def validate_plate_number(self, value):
        normalized = normalize_plate(value)
        if not normalized:
            raise serializers.ValidationError("Plate number is required.")
        return normalized


class ParkingSessionSerializer(serializers.ModelSerializer):
    vehicle = VehicleSerializer(read_only=True)
    slot = ParkingSlotSerializer(read_only=True)
    entry_by = UserSerializer(read_only=True)
    exit_by = UserSerializer(read_only=True)
    entry_scan = OcrScanSerializer(read_only=True)
    exit_scan = OcrScanSerializer(read_only=True)
    is_closed = serializers.SerializerMethodField()
    can_exit = serializers.SerializerMethodField()
    fee_summary = serializers.SerializerMethodField()

    class Meta:
        model = ParkingSession
        fields = [
            "id",
            "vehicle",
            "slot",
            "entry_by",
            "exit_by",
            "entry_scan",
            "exit_scan",
            "entry_time",
            "exit_time",
            "status",
            "pricing_snapshot",
            "duration_minutes",
            "base_fee",
            "rate_per_hour",
            "grace_period_minutes",
            "extra_charges",
            "penalty_amount",
            "daily_max_cap",
            "total_fee",
            "amount_paid",
            "manual_override_by",
            "manual_override_reason",
            "is_closed",
            "can_exit",
            "fee_summary",
            "created_at",
            "updated_at",
        ]

    def get_is_closed(self, obj):
        return obj.status == ParkingSession.Status.CLOSED

    def get_can_exit(self, obj):
        return obj.status in [ParkingSession.Status.PENDING_PAYMENT, ParkingSession.Status.CLOSED]

    def get_fee_summary(self, obj):
        return {
            "duration_minutes": obj.duration_minutes,
            "base_fee": str(obj.base_fee),
            "rate_per_hour": str(obj.rate_per_hour),
            "grace_period_minutes": obj.grace_period_minutes,
            "extra_charges": str(obj.extra_charges),
            "penalty_amount": str(obj.penalty_amount),
            "daily_max_cap": str(obj.daily_max_cap) if obj.daily_max_cap is not None else None,
            "total_fee": str(obj.total_fee),
            "amount_paid": str(obj.amount_paid),
        }


class EntryRequestSerializer(serializers.Serializer):
    plate_number = serializers.CharField(max_length=20)
    vehicle_type = serializers.ChoiceField(choices=Vehicle.VehicleType.choices, default=Vehicle.VehicleType.CAR)
    owner_name = serializers.CharField(max_length=120, required=False, allow_blank=True)
    phone_number = serializers.CharField(max_length=32, required=False, allow_blank=True)
    zone_preference = serializers.ChoiceField(choices=ParkingZone.ZoneType.choices, required=False, allow_blank=True)
    requested_slot_id = serializers.IntegerField(required=False)
    entry_scan_id = serializers.IntegerField(required=False)


class ExitRequestSerializer(serializers.Serializer):
    plate_number = serializers.CharField(max_length=20)
    exit_scan_id = serializers.IntegerField(required=False)


class QuickRegisterSerializer(serializers.Serializer):
    plate_number = serializers.CharField(max_length=20)
    vehicle_type = serializers.ChoiceField(choices=Vehicle.VehicleType.choices, default=Vehicle.VehicleType.CAR)
    owner_name = serializers.CharField(max_length=120, required=False, allow_blank=True)
    phone_number = serializers.CharField(max_length=32, required=False, allow_blank=True)


class ForceExitSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500)
    exit_scan_id = serializers.IntegerField(required=False)

