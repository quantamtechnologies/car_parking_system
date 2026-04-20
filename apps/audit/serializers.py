from rest_framework import serializers

from apps.audit.models import AuditLog
from apps.accounts.serializers import UserSerializer


class AuditLogSerializer(serializers.ModelSerializer):
    actor = UserSerializer(read_only=True)

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "actor",
            "action",
            "entity_type",
            "entity_id",
            "before_data",
            "after_data",
            "metadata",
            "reason",
            "ip_address",
            "created_at",
        ]

