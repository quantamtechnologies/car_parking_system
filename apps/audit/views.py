from rest_framework import viewsets

from apps.audit.models import AuditLog
from apps.audit.serializers import AuditLogSerializer
from apps.common.permissions import IsAdminRole


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.select_related("actor").all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsAdminRole]
    filterset_fields = ["action", "entity_type", "actor"]
    search_fields = ["entity_type", "entity_id", "reason"]
    ordering_fields = ["created_at"]

