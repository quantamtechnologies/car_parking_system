from rest_framework import viewsets

from apps.audit.services import record_audit_event
from apps.common.permissions import IsAdminRole
from apps.config.models import SystemSetting
from apps.config.serializers import SystemSettingSerializer


class SystemSettingViewSet(viewsets.ModelViewSet):
    queryset = SystemSetting.objects.all()
    serializer_class = SystemSettingSerializer
    permission_classes = [IsAdminRole]
    search_fields = ["key", "description"]
    ordering_fields = ["key", "created_at"]

    def perform_create(self, serializer):
        setting = serializer.save()
        record_audit_event(actor=self.request.user, action="CREATE", entity=setting, after_data=SystemSettingSerializer(setting).data)

    def perform_update(self, serializer):
        before = SystemSettingSerializer(serializer.instance).data
        setting = serializer.save()
        record_audit_event(
            actor=self.request.user,
            action="UPDATE",
            entity=setting,
            before_data=before,
            after_data=SystemSettingSerializer(setting).data,
        )

    def perform_destroy(self, instance):
        before = SystemSettingSerializer(instance).data
        record_audit_event(actor=self.request.user, action="DELETE", entity=instance, before_data=before)
        instance.delete()
