from rest_framework import serializers

from apps.analytics.models import AnomalyAlert


class AnomalyAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnomalyAlert
        fields = [
            "id",
            "code",
            "title",
            "description",
            "severity",
            "status",
            "category",
            "actual_value",
            "threshold_value",
            "evidence",
            "source_date",
            "resolved_by",
            "resolved_at",
            "created_at",
        ]


class ChatQuerySerializer(serializers.Serializer):
    query = serializers.CharField()

