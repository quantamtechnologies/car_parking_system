from __future__ import annotations

from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError

from apps.accounts.models import User
from apps.billing.models import CashShift, Payment, PricingPolicy
from apps.billing.serializers import (
    CashPaymentSerializer,
    CashShiftCloseSerializer,
    CashShiftOpenSerializer,
    CashShiftSerializer,
    PaymentSerializer,
    PricingPolicySerializer,
)
from apps.audit.services import record_audit_event
from apps.billing.services import close_cash_shift, confirm_cash_payment, get_active_pricing_policy, open_cash_shift
from apps.common.permissions import CanEditPricing, IsAdminOrCashier, IsAdminOrCashierOrSecurity
from apps.parking.models import ParkingSession


class PricingPolicyViewSet(viewsets.ModelViewSet):
    queryset = PricingPolicy.objects.all()
    serializer_class = PricingPolicySerializer
    permission_classes = [IsAuthenticated]
    ordering_fields = ["version", "effective_from", "created_at"]
    search_fields = ["name", "notes"]
    filterset_fields = ["is_active", "version"]

    def get_permissions(self):
        if self.action in {"list", "retrieve", "current", "history"}:
            return [IsAdminOrCashierOrSecurity()]
        return [CanEditPricing()]

    def perform_create(self, serializer):
        policy = serializer.save()
        record_audit_event(
            actor=self.request.user,
            action="CREATE",
            entity=policy,
            after_data=PricingPolicySerializer(policy).data,
        )

    def perform_update(self, serializer):
        before = PricingPolicySerializer(serializer.instance).data
        policy = serializer.save()
        record_audit_event(
            actor=self.request.user,
            action="UPDATE",
            entity=policy,
            before_data=before,
            after_data=PricingPolicySerializer(policy).data,
        )

    def perform_destroy(self, instance):
        before = PricingPolicySerializer(instance).data
        record_audit_event(
            actor=self.request.user,
            action="DELETE",
            entity=instance,
            before_data=before,
        )
        instance.delete()

    @action(detail=False, methods=["get"])
    def current(self, request):
        policy = get_active_pricing_policy()
        if getattr(policy, "pk", None):
            return Response(PricingPolicySerializer(policy).data)
        snapshot = policy.to_snapshot()
        snapshot.update({"id": None, "is_active": False})
        return Response(snapshot)

    @action(detail=False, methods=["get"])
    def history(self, request):
        serializer = self.get_serializer(self.get_queryset().order_by("-effective_from"), many=True)
        return Response(serializer.data)


class PaymentViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Payment.objects.select_related("session", "cashier", "cash_shift").all()
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["receipt_number", "session__vehicle__plate_number"]
    filterset_fields = ["method", "status", "cashier", "cash_shift"]
    ordering_fields = ["confirmed_at", "created_at"]

    def get_permissions(self):
        if self.action == "cash":
            return [IsAdminOrCashier()]
        return [IsAdminOrCashier()]

    @action(detail=False, methods=["post"])
    def cash(self, request):
        serializer = CashPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        session = ParkingSession.objects.filter(pk=data["session_id"]).select_related("slot", "vehicle").first()
        if not session:
            raise ValidationError({"session_id": "Session not found."})
        cash_shift = None
        if data.get("cash_shift_id"):
            cash_shift = CashShift.objects.filter(pk=data["cash_shift_id"]).first()
        payment = confirm_cash_payment(
            session=session,
            cashier=request.user,
            amount_tendered=data.get("amount_tendered") or 0,
            cash_shift=cash_shift,
            notes=data.get("notes", ""),
            override=data.get("override", False),
            override_reason=data.get("override_reason", ""),
        )
        return Response(PaymentSerializer(payment).data, status=status.HTTP_201_CREATED)


class CashShiftViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = CashShift.objects.select_related("cashier", "opened_by", "closed_by").all()
    serializer_class = CashShiftSerializer
    permission_classes = [IsAuthenticated]
    search_fields = ["cashier__username", "cashier__employee_code", "notes"]
    filterset_fields = ["status", "cashier"]
    ordering_fields = ["opened_at", "closed_at"]

    def get_permissions(self):
        if self.action in {"list", "retrieve", "current"}:
            return [IsAdminOrCashierOrSecurity()]
        return [IsAdminOrCashier()]

    @action(detail=False, methods=["post"])
    def open(self, request):
        serializer = CashShiftOpenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        cashier = User.objects.filter(pk=serializer.validated_data["cashier_id"]).first()
        if not cashier:
            raise ValidationError({"cashier_id": "Cashier not found."})
        shift = open_cash_shift(
            cashier=cashier,
            opened_by=request.user,
            opening_cash=serializer.validated_data["opening_cash"],
            notes=serializer.validated_data.get("notes", ""),
        )
        return Response(CashShiftSerializer(shift).data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=["post"])
    def close(self, request):
        serializer = CashShiftCloseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        shift = CashShift.objects.filter(cashier=request.user, status=CashShift.Status.OPEN).first()
        if not shift:
            raise ValidationError({"shift": "No open shift found for the current cashier."})
        closed = close_cash_shift(
            shift=shift,
            closed_by=request.user,
            actual_cash=serializer.validated_data["actual_cash"],
            notes=serializer.validated_data.get("notes", ""),
        )
        return Response(CashShiftSerializer(closed).data)

    @action(detail=False, methods=["get"])
    def current(self, request):
        shift = CashShift.objects.filter(cashier=request.user, status=CashShift.Status.OPEN).first()
        if not shift:
            return Response({"shift": None})
        return Response(CashShiftSerializer(shift).data)
