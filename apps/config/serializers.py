from rest_framework import serializers

from apps.config.models import SystemSetting


class SystemSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSetting
        fields = ["id", "key", "value", "description", "is_editable", "is_public", "created_at", "updated_at"]
        read_only_fields = ["created_at", "updated_at"]

