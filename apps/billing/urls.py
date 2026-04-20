from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.billing.views import CashShiftViewSet, PaymentViewSet, PricingPolicyViewSet

router = DefaultRouter()
router.register(r"pricing", PricingPolicyViewSet, basename="pricing-policy")
router.register(r"payments", PaymentViewSet, basename="payment")
router.register(r"cash-shifts", CashShiftViewSet, basename="cash-shift")

urlpatterns = [
    path("", include(router.urls)),
]

