import frappe
from frappe.tests.utils import FrappeTestCase
from frappe.utils.password import check_password, update_password

from omc_app.api import account_security


class TestAccountSecurity(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.user = "account-security-test@example.com"
        self.old_password = "OldPassword123!"
        self.new_password = "NewPassword456!"
        self.previous_user = frappe.session.user

        frappe.set_user("Administrator")
        if frappe.db.exists("User", self.user):
            frappe.delete_doc(
                "User",
                self.user,
                force=True,
                ignore_permissions=True,
            )

        frappe.get_doc(
            {
                "doctype": "User",
                "email": self.user,
                "first_name": "Account Security Test",
                "enabled": 1,
                "send_welcome_email": 0,
                "user_type": "Website User",
            }
        ).insert(ignore_permissions=True)
        update_password(self.user, self.old_password)
        frappe.db.commit()
        frappe.set_user(self.user)

    def tearDown(self):
        frappe.set_user("Administrator")
        if frappe.db.exists("User", self.user):
            frappe.delete_doc(
                "User",
                self.user,
                force=True,
                ignore_permissions=True,
            )
        frappe.db.rollback()
        frappe.set_user(self.previous_user)
        super().tearDown()

    def test_changes_password_and_requires_logout(self):
        result = account_security.change_password(
            current_password=self.old_password,
            new_password=self.new_password,
            confirm_password=self.new_password,
        )

        self.assertTrue(result["changed"])
        self.assertTrue(result["logout_required"])

        with self.assertRaises(frappe.AuthenticationError):
            check_password(self.user, self.old_password)

        self.assertEqual(
            check_password(self.user, self.new_password),
            self.user,
        )

    def test_rejects_incorrect_current_password(self):
        with self.assertRaises(frappe.AuthenticationError):
            account_security.change_password(
                current_password="WrongPassword123!",
                new_password=self.new_password,
                confirm_password=self.new_password,
            )

        self.assertEqual(
            check_password(self.user, self.old_password),
            self.user,
        )

    def test_rejects_mismatched_confirmation(self):
        with self.assertRaises(frappe.ValidationError):
            account_security.change_password(
                current_password=self.old_password,
                new_password=self.new_password,
                confirm_password="DifferentPassword789!",
            )

    def test_rejects_short_password(self):
        with self.assertRaises(frappe.ValidationError):
            account_security.change_password(
                current_password=self.old_password,
                new_password="short",
                confirm_password="short",
            )

    def test_rejects_reusing_current_password(self):
        with self.assertRaises(frappe.ValidationError):
            account_security.change_password(
                current_password=self.old_password,
                new_password=self.old_password,
                confirm_password=self.old_password,
            )

    def test_guest_is_rejected(self):
        frappe.set_user("Guest")

        with self.assertRaises(frappe.PermissionError):
            account_security.change_password(
                current_password=self.old_password,
                new_password=self.new_password,
                confirm_password=self.new_password,
            )
