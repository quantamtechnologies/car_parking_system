from __future__ import annotations

from django.db.models import Count, Sum
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError

from apps.accounts.models import User
from apps.common.permissions import IsAdminOrCashierOrSecurity, IsAdminRole, IsCashierRole, IsSecurityRole
from apps.common.utils import normalize_plate
from apps.parking.models import ParkingSession, ParkingSlot, ParkingZone, Vehicle
from apps.parking.serializers import (
    EntryRequestSerializer,
    ExitRequestSerializer,
    ForceExitSerializer,
    ParkingSessionSerializer,
    ParkingSlotSerializer,
    ParkingZoneSerializer,
    QuickRegisterSerializer,
    VehicleSerializer,
)
from apps.parking.services import (
    active_session_queryset,
    close_session_after_payment,
    get_active_session_for_plate,
    get_dashboard_snapshot,
    prepare_exit_session,
    register_vehicle,
    start_parking_session,
)
from apps.camera.models import OcrScan
from apps.audit.services import record_audit_event


class VehicleViewSet(viewsets.ModelViewSet):
    queryset = Vehicle.objects.all()
    serializer_class = VehicleSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["plate_number", "owner_name", "phone_number"]
    filterset_fields = ["vehicle_type", "is_active"]
    ordering_fields = ["plate_number", "created_at"]

    def get_permissions(self):
        if self.action in {"list", "retrieve", "quick_register", "create"}:
            return [IsAdminOrCashierOrSecurity()]
        return [IsAdminRole()]

    def perform_create(self, serializer):
        vehicle = serializer.save()
        record_audit_event(actor=self.request.user, action="CREATE", entity=vehicle, after_data=VehicleSerializer(vehicle).data)

    def perform_update(self, serializer):
        before = VehicleSerializer(serializer.instance).data
        vehicle = serializer.save()
        record_audit_event(actor=self.request.user, action="UPDATE", entity=vehicle, before_data=before, after_data=VehicleSerializer(vehicle).data)

    def perform_destroy(self, instance):
        before = VehicleSerializer(instance).data
        record_audit_event(actor=self.request.user, action="DELETE", entity=instance, before_data=before)
        instance.delete()

    @action(detail=False, methods=["post"], url_path="quick-register")
    def quick_register(self, request):
        serializer = QuickRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        vehicle = register_vehicle(**serializer.validated_data)
        record_audit_event(actor=request.user, action="CREATE", entity=vehicle, after_data=serializer.validated_data)
        return Response(VehicleSerializer(vehicle).data, status=status.HTTP_201_CREATED)


class ParkingZoneViewSet(viewsets.ModelViewSet):
    queryset = ParkingZone.objects.all()
    serializer_class = ParkingZoneSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["name", "notes"]
    filterset_fields = ["zone_type", "is_active"]

    def get_permissions(self):
        if self.action in {"list", "retrieve"}:
            return [IsAdminOrCashierOrSecurity()]
        return [IsAdminRole()]

    def perform_create(self, serializer):
        zone = serializer.save()
        record_audit_event(actor=self.request.user, action="CREATE", entity=zone, after_data=ParkingZoneSerializer(zone).data)

    def perform_update(self, serializer):
        before = ParkingZoneSerializer(serializer.instance).data
        zone = serializer.save()
        record_audit_event(actor=self.request.user, action="UPDATE", entity=zone, before_data=before, after_data=ParkingZoneSerializer(zone).data)

    def perform_destroy(self, instance):
        before = ParkingZoneSerializer(instance).data
        record_audit_event(actor=self.request.user, action="DELETE", entity=instance, before_data=before)
        instance.delete()


class ParkingSlotViewSet(viewsets.ModelViewSet):
    queryset = ParkingSlot.objects.select_related("zone").all()
    serializer_class = ParkingSlotSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["code", "zone__name"]
    filterset_fields = ["status", "zone", "is_manual_only"]
    ordering_fields = ["code", "created_at"]

    def get_permissions(self):
        if self.action in {"list", "retrieve"}:
            return [IsAdminOrCashierOrSecurity()]
        return [IsAdminRole()]

    def perform_create(self, serializer):
        slot = serializer.save()
        record_audit_event(actor=self.request.user, action="CREATE", entity=slot, after_data=ParkingSlotSerializer(slot).data)

    def perform_update(self, serializer):
        before = ParkingSlotSerializer(serializer.instance).data
        slot = serializer.save()
        record_audit_event(actor=self.request.user, action="UPDATE", entity=slot, before_data=before, after_data=ParkingSlotSerializer(slot).data)

    def perform_destroy(self, instance):
        before = ParkingSlotSerializer(instance).data
        record_audit_event(actor=self.request.user, action="DELETE", entity=instance, before_data=before)
        instance.delete()


class ParkingSessionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = active_session_queryset()
    serializer_class = ParkingSessionSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["vehicle__plate_number", "slot__code", "slot__zone__name"]
    filterset_fields = ["status", "slot__zone", "vehicle__vehicle_type"]
    ordering_fields = ["entry_time", "exit_time", "created_at"]

    def get_permissions(self):
        if self.action in {"list", "retrieve", "entry", "exit", "active", "overview"}:
            return [IsAdminOrCashierOrSecurity()]
        if self.action == "force_exit":
            return [IsAdminRole()]
        return [IsAuthenticated()]

    @action(detail=False, methods=["post"])
    def entry(self, request):
        serializer = EntryRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        plate = normalize_plate(data["plate_number"])
        vehicle = Vehicle.objects.filter(plate_number=plate, is_active=True).first()
        if not vehicle:
            return Response(
                {
                    "vehicle_found": False,
                    "needs_registration": True,
                    "plate_number": plate,
                    "prefill": {"plate_number": plate, "vehicle_type": data.get("vehicle_type", Vehicle.VehicleType.CAR)},
                },
                status=status.HTTP_202_ACCEPTED,
            )

        entry_scan = None
        if scan_id := data.get("entry_scan_id"):
            entry_scan = OcrScan.objects.filter(id=scan_id).first()
            if not entry_scan:
                raise ValidationError({"entry_scan_id": "Entry scan not found."})

        requested_slot = None
        if data.get("requested_slot_id"):
            requested_slot = ParkingSlot.objects.filter(id=data["requested_slot_id"]).first()
            if not requested_slot:
                raise ValidationError({"requested_slot_id": "Requested slot not found."})
        session = start_parking_session(
            vehicle=vehicle,
            actor=request.user,
            zone_preference=data.get("zone_preference"),
            entry_scan=entry_scan,
            requested_slot=requested_slot,
        )
        return Response(ParkingSessionSerializer(session).data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=["post"])
    def exit(self, request):
        serializer = ExitRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plate = normalize_plate(serializer.validated_data["plate_number"])
        session = get_active_session_for_plate(plate)
        if not session:
            raise ValidationError({"plate_number": "No active session found for this vehicle."})

        exit_scan = None
        if scan_id := serializer.validated_data.get("exit_scan_id"):
            exit_scan = OcrScan.objects.filter(id=scan_id).first()
            if not exit_scan:
                raise ValidationError({"exit_scan_id": "Exit scan not found."})

        session, breakdown = prepare_exit_session(session=session, actor=request.user, exit_scan=exit_scan)
        return Response(
            {
                "session": ParkingSessionSerializer(session).data,
                "fee_breakdown": breakdown,
                "payment_required": True,
                "exit_blocked": True,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=["get"])
    def active(self, request):
        queryset = active_session_queryset().filter(status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT])
        serializer = ParkingSessionSerializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def overview(self, request):
        snapshot = get_dashboard_snapshot()
        snapshot["active_sessions"] = active_session_queryset().filter(status__in=[ParkingSession.Status.ACTIVE, ParkingSession.Status.PENDING_PAYMENT]).count()
        snapshot["pending_payments"] = active_session_queryset().filter(status=ParkingSession.Status.PENDING_PAYMENT).count()
        snapshot["today_entries"] = ParkingSession.objects.filter(entry_time__date=timezone.localdate()).count()
        return Response(snapshot)

    @action(detail=True, methods=["post"])
    def force_exit(self, request, pk=None):
        session = self.get_object()
        serializer = ForceExitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        session, _ = prepare_exit_session(session=session, actor=request.user, exit_scan=None)
        from apps.billing.services import confirm_cash_payment

        confirm_cash_payment(
            session=session,
            cashier=request.user,
            amount_tendered=0,
            cash_shift=None,
            notes=serializer.validated_data["reason"],
            override=True,
            override_reason=serializer.validated_data["reason"],
        )
        session.refresh_from_db()
        session.manual_override_by = request.user
        session.manual_override_reason = serializer.validated_data["reason"]
        session.save(update_fields=["manual_override_by", "manual_override_reason", "updated_at"])
        return Response(ParkingSessionSerializer(session).data)
