from rest_framework.permissions import BasePermission


class RolePermission(BasePermission):
    allowed_roles: tuple[str, ...] = ()

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_superuser:
            return True
        return getattr(user, "role", None) in self.allowed_roles


class IsAdminRole(RolePermission):
    allowed_roles = ("ADMIN",)


class IsAdminOrCashier(RolePermission):
    allowed_roles = ("ADMIN", "CASHIER")


class IsCashierRole(RolePermission):
    allowed_roles = ("CASHIER",)


class IsSecurityRole(RolePermission):
    allowed_roles = ("SECURITY",)


class IsAdminOrCashierOrSecurity(RolePermission):
    allowed_roles = ("ADMIN", "CASHIER", "SECURITY")


class CanEditPricing(RolePermission):
    allowed_roles = ("ADMIN",)
