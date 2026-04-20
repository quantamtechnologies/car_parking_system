"""
ASGI config for project.
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings")

from apps.accounts.startup import ensure_default_superuser

application = get_asgi_application()
ensure_default_superuser()
