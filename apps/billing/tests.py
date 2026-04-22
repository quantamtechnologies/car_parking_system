from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.exceptions import ValidationError

from apps.billing.models import PricingPolicy
from apps.billing.services import confirm_cash_payment, open_cash_shift
from apps.parking.models import ParkingSlot, ParkingZone, Vehicle
from apps.parking.services import prepare_exit_session, start_parking_session


class BillingSecurityTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.admin = User.objects.create_user(username="admin", password="pass", role="ADMIN")
        self.cashier = User.objects.create_user(username="cashier", password="pass", role="CASHIER")
        self.other_cashier = User.objects.create_user(username="cashier2", password="pass", role="CASHIER")
        self.zone = ParkingZone.objects.create(name="Regular", zone_type=ParkingZone.ZoneType.REGULAR, priority=1)
        self.slot = ParkingSlot.objects.create(zone=self.zone, code="R1")
        self.vehicle = Vehicle.objects.create(plate_number="XYZ789", vehicle_type=Vehicle.VehicleType.CAR)
        PricingPolicy.objects.create(
            name="Standard",
            base_fee=Decimal("5.00"),
            hourly_rate=Decimal("10.00"),
            grace_period_minutes=15,
            overdue_penalty=Decimal("0.00"),
            daily_max_cap=Decimal("100.00"),
            is_active=True,
        )
        self.session = start_parking_session(vehicle=self.vehicle, actor=self.cashier, requested_slot=self.slot)
        self.session, _ = prepare_exit_session(session=self.session, actor=self.cashier)
        self.shift = open_cash_shift(cashier=self.cashier, opened_by=self.admin, opening_cash=Decimal("50.00"))

    def test_cashier_cannot_override_exit_without_admin_privileges(self):
        with self.assertRaises(ValidationError):
            confirm_cash_payment(
                session=self.session,
                cashier=self.cashier,
                amount_tendered=Decimal("0.00"),
                override=True,
                override_reason="test override",
            )

    def test_cash_payment_rejects_shift_from_another_cashier(self):
        with self.assertRaises(ValidationError):
            confirm_cash_payment(
                session=self.session,
                cashier=self.other_cashier,
                amount_tendered=Decimal("200.00"),
                cash_shift=self.shift,
            )
