from django.contrib.auth import authenticate, get_user_model
from django.test import TestCase

from apps.accounts.forms import UserCreationForm


class UserAdminFormTests(TestCase):
    def test_admin_creation_form_hashes_password_and_allows_login(self):
        User = get_user_model()
        form = UserCreationForm(
            data={
                "username": "frontdesk",
                "email": "frontdesk@example.com",
                "first_name": "Front",
                "last_name": "Desk",
                "role": User.Role.CASHIER,
                "phone_number": "0712345678",
                "employee_code": "FD-001",
                "is_force_password_change": False,
                "password1": "StrongPass123!",
                "password2": "StrongPass123!",
            }
        )

        self.assertTrue(form.is_valid(), form.errors)

        user = form.save()

        self.assertNotEqual(user.password, "StrongPass123!")
        self.assertTrue(user.check_password("StrongPass123!"))
        self.assertEqual(authenticate(username="frontdesk", password="StrongPass123!"), user)
