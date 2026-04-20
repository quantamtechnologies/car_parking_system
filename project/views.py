from __future__ import annotations

from django.http import HttpResponse, JsonResponse
from django.views.decorators.http import require_safe


@require_safe
def root(_request):
    return HttpResponse("Smart Car Parking System is running", content_type="text/plain; charset=utf-8")


@require_safe
def api_root(_request):
    return JsonResponse(
        {
            "service": "smart-parking-api",
            "status": "ok",
            "health": "/health/",
            "docs": "/api/docs/",
            "schema": "/api/schema/",
        }
    )


@require_safe
def healthcheck(_request):
    return JsonResponse({"status": "ok"})
