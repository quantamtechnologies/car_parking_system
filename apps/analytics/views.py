from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.analytics.models import AnomalyAlert
from apps.analytics.serializers import AnomalyAlertSerializer, ChatQuerySerializer
from apps.analytics.services import dashboard_metrics, detect_anomalies
from apps.billing.models import Payment
from apps.parking.models import ParkingSession, ParkingSlot


class DashboardAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        start = request.query_params.get("start")
        end = request.query_params.get("end")
        metrics = dashboard_metrics(start, end)
        metrics["alerts"] = AnomalyAlertSerializer(detect_anomalies().filter(status=AnomalyAlert.Status.OPEN), many=True).data
        return Response(metrics)


class AnomalyAlertViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AnomalyAlert.objects.all()
    serializer_class = AnomalyAlertSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["severity", "status", "category", "code"]
    search_fields = ["code", "title", "description"]
    ordering_fields = ["created_at", "severity"]

    @action(detail=False, methods=["post"])
    def refresh(self, request):
        alerts = detect_anomalies()
        serializer = self.get_serializer(alerts, many=True)
        return Response(serializer.data)


class ChatbotQueryAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChatQuerySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        query = serializer.validated_data["query"].lower().strip()
        today = timezone.localdate()

        if "revenue" in query:
            data = Payment.objects.filter(
                confirmed_at__date=today,
                status=Payment.Status.CONFIRMED,
                method=Payment.Method.CASH,
            ).aggregate(total=Sum("amount_due"))
            return Response({"intent": "revenue", "value": str(data.get("total") or Decimal("0.00"))})
        if "cars" in query or "vehicle" in query:
            count = ParkingSession.objects.filter(entry_time__date=today).count()
            return Response({"intent": "cars", "value": count})
        if "occupancy" in query or "parking" in query:
            occupied = ParkingSlot.objects.filter(status=ParkingSlot.SlotStatus.OCCUPIED).count()
            total = ParkingSlot.objects.exclude(status=ParkingSlot.SlotStatus.OUT_OF_SERVICE).count()
            return Response({"intent": "occupancy", "value": round((occupied / max(total, 1)) * 100, 2)})
        return Response(
            {
                "intent": "unknown",
                "message": "Try asking about revenue, cars today, or occupancy.",
            },
            status=status.HTTP_200_OK,
        )
