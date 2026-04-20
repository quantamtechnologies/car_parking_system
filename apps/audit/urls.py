from django.urls import path

from apps.audit.views import AuditLogViewSet


audit_log_list = AuditLogViewSet.as_view({"get": "list"})
audit_log_detail = AuditLogViewSet.as_view({"get": "retrieve"})

urlpatterns = [
    path("logs/", audit_log_list, name="audit-log-list"),
    path("logs/<int:pk>/", audit_log_detail, name="audit-log-detail"),
]

