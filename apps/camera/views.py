from __future__ import annotations

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser

from apps.audit.services import record_audit_event
from apps.camera.models import OcrScan
from apps.camera.serializers import OcrScanSerializer, OcrUploadSerializer
from apps.camera.services import run_anpr
from apps.common.permissions import IsAdminOrCashierOrSecurity


class RecognizePlateAPIView(APIView):
    permission_classes = [IsAuthenticated, IsAdminOrCashierOrSecurity]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        serializer = OcrUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        upload = serializer.validated_data["image"]
        scan = OcrScan.objects.create(
            image=upload,
            original_filename=getattr(upload, "name", ""),
            source=serializer.validated_data["source"],
            uploaded_by=request.user,
        )
        image_path = scan.image.path
        result = run_anpr(image_path)
        scan.raw_text = result.get("raw_text", "")
        scan.detected_plate = result.get("detected_plate", "")
        scan.candidate_plates = result.get("candidate_plates", [])
        scan.confidence = result.get("confidence", 0)
        scan.notes = result.get("error", "")
        scan.save()
        record_audit_event(actor=request.user, action="CREATE", entity=scan, after_data={"detected_plate": scan.detected_plate, "confidence": str(scan.confidence)})
        return Response(OcrScanSerializer(scan, context={"request": request}).data, status=status.HTTP_201_CREATED)
