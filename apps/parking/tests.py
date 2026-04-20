from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.exceptions import ValidationError

from apps.billing.models import PricingPolicy
from apps.parking.models import ParkingSlot, ParkingZone, Vehicle
from apps.parking.services import start_parking_session


class ParkingServiceTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(username="cashier", password="pass", role="CASHIER")
        self.zone = ParkingZone.objects.create(name="Regular", zone_type=ParkingZone.ZoneType.REGULAR, priority=1)
        self.slot = ParkingSlot.objects.create(zone=self.zone, code="R1")
        self.vehicle = Vehicle.objects.create(plate_number="ABC123", vehicle_type=Vehicle.VehicleType.CAR)
        PricingPolicy.objects.create(
            name="Standard",
            base_fee=Decimal("5.00"),
            hourly_rate=Decimal("10.00"),
            grace_period_minutes=15,
            overdue_penalty=Decimal("0.00"),
            daily_max_cap=Decimal("100.00"),
            is_active=True,
        )

    def test_duplicate_active_session_is_blocked(self):
        start_parking_session(vehicle=self.vehicle, actor=self.staff, requested_slot=self.slot)

        with self.assertRaises(ValidationError):
            start_parking_session(vehicle=self.vehicle, actor=self.staff)

