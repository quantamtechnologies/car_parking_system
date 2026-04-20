from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.parking.views import ParkingSessionViewSet, ParkingSlotViewSet, ParkingZoneViewSet, VehicleViewSet

router = DefaultRouter()
router.register(r"vehicles", VehicleViewSet, basename="vehicle")
router.register(r"zones", ParkingZoneViewSet, basename="zone")
router.register(r"slots", ParkingSlotViewSet, basename="slot")
router.register(r"sessions", ParkingSessionViewSet, basename="session")

urlpatterns = [
    path("", include(router.urls)),
]

