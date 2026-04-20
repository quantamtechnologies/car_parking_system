"""
WSGI config for project.
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "project.settings")

from apps.accounts.startup import ensure_default_superuser

application = get_wsgi_application()
ensure_default_superuser()
