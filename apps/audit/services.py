from __future__ import annotations

from typing import Any

from django.contrib.contenttypes.models import ContentType

from apps.audit.models import AuditLog


def client_ip(request) -> str | None:
    if not request:
        return None
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def record_audit_event(
    *,
    actor=None,
    action: str,
    entity: Any,
    before_data: dict | None = None,
    after_data: dict | None = None,
    metadata: dict | None = None,
    reason: str = "",
    request=None,
):
    content_type = None
    object_id = ""
    entity_type = entity if isinstance(entity, str) else entity.__class__.__name__
    entity_id = ""

    if not isinstance(entity, str):
        content_type = ContentType.objects.get_for_model(entity.__class__)
        object_id = str(getattr(entity, "pk", ""))
        entity_id = object_id

    return AuditLog.objects.create(
        actor=actor if getattr(actor, "is_authenticated", False) else None,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        content_type=content_type,
        object_id=object_id,
        before_data=before_data or {},
        after_data=after_data or {},
        metadata=metadata or {},
        reason=reason,
        ip_address=client_ip(request),
    )

