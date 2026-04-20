from __future__ import annotations

import re
import uuid
from decimal import Decimal, InvalidOperation

from django.utils import timezone

PLATE_RE = re.compile(r"[^A-Z0-9]")


def normalize_plate(plate: str | None) -> str:
    if not plate:
        return ""
    return PLATE_RE.sub("", plate.upper().strip())


def build_receipt_number(prefix: str = "RCPT") -> str:
    return f"{prefix}-{timezone.now():%Y%m%d%H%M%S}-{uuid.uuid4().hex[:6].upper()}"


def decimal_value(value, default: str = "0.00") -> Decimal:
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return Decimal(default)


def parse_jsonish(value):
    if isinstance(value, dict):
        return value
    if value in (None, ""):
        return {}
    return value

