from __future__ import annotations

import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction

logger = logging.getLogger(__name__)


def ensure_default_superuser() -> bool:
    """
    Create the default admin account once if it is missing.

    Returns True when the user was created and False when it already existed,
    bootstrap is disabled, or the database was unavailable.
    """

    if not getattr(settings, "AUTO_CREATE_DEFAULT_SUPERUSER", True):
        return False

    username = getattr(settings, "DEFAULT_SUPERUSER_USERNAME", "admin").strip()
    password = getattr(settings, "DEFAULT_SUPERUSER_PASSWORD", "")
    email = getattr(settings, "DEFAULT_SUPERUSER_EMAIL", "admin@example.com").strip()

    if not username or not password:
        logger.warning("Default superuser bootstrap skipped because the username or password is missing.")
        return False

    user_model = get_user_model()
    admin_role = getattr(getattr(user_model, "Role", None), "ADMIN", "ADMIN")

    try:
        with transaction.atomic():
            if user_model.objects.filter(username=username).exists():
                return False

            user = user_model(username=username, email=email)
            user.is_staff = True
            user.is_superuser = True
            user.is_active = True

            if hasattr(user, "role"):
                user.role = admin_role

            user.set_password(password)
            user.save()
            return True
    except IntegrityError:
        if user_model.objects.filter(username=username).exists():
            return False
        logger.exception("Default superuser bootstrap failed because of a database race.")
        return False
    except Exception:
        logger.exception("Default superuser bootstrap failed.")
        return False
