from types import SimpleNamespace
from unittest.mock import MagicMock, call, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile


class TestNotificationOwnershipAuthority(FrappeTestCase):
    @patch("omc_app.api.mobile._assert_notification_access")
    @patch("omc_app.api.mobile._assert_approved_customer")
    @patch("omc_app.api.mobile._can_access_internal_workspace")
    @patch("omc_app.api.mobile._current_user")
    @patch("omc_app.api.mobile.frappe.get_doc")
    @patch("omc_app.api.mobile.frappe.db.exists")
    def test_notification_lookup_requires_current_owner(
        self,
        exists,
        get_doc,
        current_user,
        can_access_internal,
        approved_customer,
        assert_access,
    ):
        exists.return_value = True
        notification = SimpleNamespace(visible_to_customer=1)
        get_doc.return_value = notification
        current_user.return_value = "customer@example.com"
        can_access_internal.return_value = False
        profile = SimpleNamespace(name="CUST-0001")
        approved_customer.return_value = profile

        result = mobile._notification_for_current_user("NOTIF-0001")

        self.assertIs(result, notification)
        assert_access.assert_called_once_with(
            notification,
            user="customer@example.com",
            profile=profile,
        )

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.db.set_value")
    @patch("omc_app.api.mobile.frappe.get_all")
    @patch("omc_app.api.mobile._assert_approved_customer")
    @patch("omc_app.api.mobile._can_access_internal_workspace")
    @patch("omc_app.api.mobile._current_user")
    def test_mark_all_notifications_is_customer_scoped(
        self,
        current_user,
        can_access_internal,
        approved_customer,
        get_all,
        set_value,
        commit,
    ):
        current_user.return_value = "customer@example.com"
        can_access_internal.return_value = False
        approved_customer.return_value = SimpleNamespace(name="CUST-0001")
        get_all.return_value = ["NOTIF-0001"]

        result = mobile.mark_all_notifications_read()

        get_all.assert_called_once_with(
            "OMC Notification",
            filters={
                "visible_to_customer": 1,
                "is_read": 0,
                "customer_profile": "CUST-0001",
            },
            pluck="name",
        )
        set_value.assert_called_once()
        commit.assert_called_once_with()
        self.assertEqual(result["count"], 1)


class TestPushTokenLifecycle(FrappeTestCase):
    def _push_doc(self, *, is_new):
        doc = MagicMock()
        doc.name = "PUSH-0001"
        doc.platform = "android"
        doc.is_active = 1
        doc.is_new.return_value = is_new
        return doc

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.utils.now_datetime")
    @patch("omc_app.api.mobile.frappe.get_doc")
    @patch("omc_app.api.mobile.frappe.new_doc")
    @patch("omc_app.api.mobile.frappe.db.get_value")
    @patch("omc_app.api.mobile._get_customer_profile_for_user")
    @patch("omc_app.api.mobile._current_user")
    def test_register_reuses_existing_token_record(
        self,
        current_user,
        get_profile,
        get_value,
        new_doc,
        get_doc,
        now_datetime,
        commit,
    ):
        current_user.return_value = "user@example.com"
        get_profile.return_value = SimpleNamespace(name="CUST-0001")
        get_value.return_value = "PUSH-0001"
        existing = self._push_doc(is_new=False)
        get_doc.return_value = existing
        now_datetime.return_value = "2026-07-29 20:00:00"

        result = mobile.register_push_token(
            token="TOKEN-A",
            platform="android",
            device_id="DEVICE-1",
        )

        get_value.assert_called_once_with(
            "OMC Push Token",
            {"token": "TOKEN-A"},
            "name",
        )
        new_doc.assert_not_called()
        existing.save.assert_called_once_with(ignore_permissions=True)
        self.assertEqual(existing.user, "user@example.com")
        self.assertEqual(existing.device_id, "DEVICE-1")
        self.assertTrue(result["registered"])
        commit.assert_called_once_with()

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.utils.now_datetime")
    @patch("omc_app.api.mobile.frappe.get_doc")
    @patch("omc_app.api.mobile.frappe.new_doc")
    @patch("omc_app.api.mobile.frappe.db.get_value")
    @patch("omc_app.api.mobile._get_customer_profile_for_user")
    @patch("omc_app.api.mobile._current_user")
    def test_register_reuses_device_record_after_token_refresh(
        self,
        current_user,
        get_profile,
        get_value,
        new_doc,
        get_doc,
        now_datetime,
        commit,
    ):
        current_user.return_value = "user@example.com"
        get_profile.return_value = SimpleNamespace(name="CUST-0001")
        get_value.side_effect = [None, "PUSH-0001"]
        existing = self._push_doc(is_new=False)
        get_doc.return_value = existing
        now_datetime.return_value = "2026-07-29 20:00:00"

        mobile.register_push_token(
            token="TOKEN-NEW",
            platform="android",
            device_id="DEVICE-1",
        )

        self.assertEqual(
            get_value.call_args_list,
            [
                call(
                    "OMC Push Token",
                    {"token": "TOKEN-NEW"},
                    "name",
                ),
                call(
                    "OMC Push Token",
                    {
                        "user": "user@example.com",
                        "device_id": "DEVICE-1",
                    },
                    "name",
                ),
            ],
        )
        self.assertEqual(existing.token, "TOKEN-NEW")
        existing.save.assert_called_once_with(ignore_permissions=True)
        new_doc.assert_not_called()
        commit.assert_called_once_with()

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.utils.now_datetime")
    @patch("omc_app.api.mobile.frappe.get_doc")
    @patch("omc_app.api.mobile.frappe.get_all")
    @patch("omc_app.api.mobile._current_user")
    def test_unregister_is_scoped_to_current_user(
        self,
        current_user,
        get_all,
        get_doc,
        now_datetime,
        commit,
    ):
        current_user.return_value = "user@example.com"
        get_all.return_value = ["PUSH-0001"]
        doc = MagicMock()
        get_doc.return_value = doc
        now_datetime.return_value = "2026-07-29 20:00:00"

        result = mobile.unregister_push_token(
            token="TOKEN-A",
            device_id="DEVICE-1",
        )

        get_all.assert_called_once_with(
            "OMC Push Token",
            filters={
                "user": "user@example.com",
                "token": "TOKEN-A",
            },
            pluck="name",
        )
        self.assertEqual(doc.is_active, 0)
        doc.save.assert_called_once_with(ignore_permissions=True)
        self.assertTrue(result["unregistered"])
        commit.assert_called_once_with()


class TestSettingsPreferenceAuthority(FrappeTestCase):
    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile._get_customer_preferences")
    @patch("omc_app.api.mobile._get_customer_profile_for_user")
    def test_settings_update_ignores_unapproved_fields(
        self,
        get_profile,
        get_preferences,
        commit,
    ):
        profile = SimpleNamespace(name="CUST-0001")
        get_profile.return_value = profile

        preferences = MagicMock()
        preferences.get.return_value = 1
        preferences.theme = "system"
        preferences.language = "en"
        get_preferences.return_value = preferences

        result = mobile.update_settings_preferences(
            service_updates_enabled=True,
            customer_profile="CUST-OTHER",
            is_admin=True,
            unknown_field="ignored",
        )

        get_preferences.assert_called_once_with(profile)
        preferences.set.assert_not_called()
        preferences.save.assert_not_called()
        commit.assert_not_called()
        self.assertFalse(result["updated"])

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile._get_customer_preferences")
    @patch("omc_app.api.mobile._get_customer_profile_for_user")
    def test_settings_update_changes_only_allowed_field(
        self,
        get_profile,
        get_preferences,
        commit,
    ):
        profile = SimpleNamespace(name="CUST-0001")
        get_profile.return_value = profile

        preferences = MagicMock()
        preferences.get.return_value = 1
        preferences.theme = "system"
        preferences.language = "en"
        get_preferences.return_value = preferences

        result = mobile.update_settings_preferences(
            payment_alerts_enabled=False,
            customer_profile="CUST-OTHER",
        )

        preferences.set.assert_called_once_with(
            "payment_alerts_enabled",
            0,
        )
        preferences.save.assert_called_once_with(ignore_permissions=True)
        commit.assert_called_once_with()
        self.assertEqual(
            result["updated_fields"],
            ["payment_alerts_enabled"],
        )

class TestNotificationPreferenceGating(FrappeTestCase):
    @patch("omc_app.api.mobile.frappe.new_doc")
    @patch("omc_app.api.mobile._notification_preference_enabled")
    def test_disabled_customer_preference_suppresses_notification(
        self,
        preference_enabled,
        new_doc,
    ):
        preference_enabled.return_value = False

        result = mobile._create_customer_notification(
            customer_profile="CUST-0001",
            title="Document required",
            message="Please upload the requested document.",
            notification_type="Document Request",
            reference_doctype="OMC Service Document",
            reference_name="DOC-0001",
        )

        self.assertIsNone(result)
        preference_enabled.assert_called_once_with(
            customer_profile="CUST-0001",
            notification_type="Document",
        )
        new_doc.assert_not_called()

    @patch("omc_app.api.mobile.frappe.new_doc")
    @patch("omc_app.api.mobile._notification_preference_enabled")
    def test_enabled_customer_preference_allows_notification(
        self,
        preference_enabled,
        new_doc,
    ):
        preference_enabled.return_value = True
        notification = MagicMock()
        notification.meta.has_field.return_value = False
        new_doc.return_value = notification

        result = mobile._create_customer_notification(
            customer_profile="CUST-0001",
            title="Payment update",
            message="Your payment was received.",
            notification_type="Payment Alert",
            reference_doctype="OMC Service Payment",
            reference_name="PAY-0001",
        )

        self.assertIs(result, notification)
        preference_enabled.assert_called_once_with(
            customer_profile="CUST-0001",
            notification_type="Payment",
        )
        notification.insert.assert_called_once_with(ignore_permissions=True)

    @patch("omc_app.api.mobile.frappe.new_doc")
    @patch("omc_app.api.mobile._notification_preference_enabled")
    def test_internal_recipient_bypasses_customer_preferences(
        self,
        preference_enabled,
        new_doc,
    ):
        notification = MagicMock()
        notification.meta.has_field.return_value = False
        new_doc.return_value = notification

        result = mobile._create_customer_notification(
            recipient_user="staff@example.com",
            title="New service request assigned",
            message="SR-0001 has been assigned.",
            notification_type="Service",
            reference_doctype="OMC Service Request",
            reference_name="SR-0001",
        )

        self.assertIs(result, notification)
        preference_enabled.assert_not_called()
        self.assertEqual(notification.recipient_user, "staff@example.com")
        notification.insert.assert_called_once_with(ignore_permissions=True)

    @patch("omc_app.api.mobile.frappe.db.get_value")
    def test_type_specific_preference_field_is_used(self, get_value):
        get_value.side_effect = ["PREF-0001", 0]

        result = mobile._notification_preference_enabled(
            customer_profile="CUST-0001",
            notification_type="Payment",
        )

        self.assertFalse(result)
        self.assertEqual(
            get_value.call_args_list,
            [
                call(
                    "OMC Customer Preference",
                    {"customer_profile": "CUST-0001"},
                    "name",
                ),
                call(
                    "OMC Customer Preference",
                    "PREF-0001",
                    "payment_alerts_enabled",
                ),
            ],
        )

    @patch("omc_app.api.mobile.frappe.db.get_value")
    def test_missing_preferences_default_to_enabled(self, get_value):
        get_value.return_value = None

        result = mobile._notification_preference_enabled(
            customer_profile="CUST-0001",
            notification_type="Support",
        )

        self.assertTrue(result)
        get_value.assert_called_once_with(
            "OMC Customer Preference",
            {"customer_profile": "CUST-0001"},
            "name",
        )
