from datetime import datetime, timedelta
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import home_content


class TestHomeContent(FrappeTestCase):
    def test_audience_matching(self):
        self.assertTrue(home_content._audience_matches("All", "Guest"))
        self.assertTrue(home_content._audience_matches("Guest", "Guest"))
        self.assertFalse(home_content._audience_matches("Guest", "Approved Customer"))
        self.assertTrue(home_content._audience_matches("Customer", "Customer"))
        self.assertTrue(home_content._audience_matches("Customer", "Approved Customer"))
        self.assertFalse(home_content._audience_matches("Approved Customer", "Customer"))
        self.assertTrue(
            home_content._audience_matches("Approved Customer", "Approved Customer")
        )

    def test_schedule_helpers_allow_only_current_content(self):
        now = datetime(2026, 8, 12, 12, 0, 0)

        self.assertTrue(home_content._is_started(None, now))
        self.assertTrue(home_content._is_started(now - timedelta(minutes=1), now))
        self.assertFalse(home_content._is_started(now + timedelta(minutes=1), now))

        self.assertTrue(home_content._is_not_expired(None, now))
        self.assertTrue(
            home_content._is_not_expired(now + timedelta(minutes=1), now)
        )
        self.assertFalse(
            home_content._is_not_expired(now - timedelta(minutes=1), now)
        )

    @patch("omc_app.api.home_content._knowledge_items")
    @patch("omc_app.api.home_content._announcement_items")
    @patch("omc_app.api.home_content._tax_update_items")
    @patch("omc_app.api.home_content._banner_items")
    @patch("omc_app.api.home_content._current_audience")
    def test_home_content_returns_lightweight_sections(
        self,
        current_audience,
        banner_items,
        tax_update_items,
        announcement_items,
        knowledge_items,
    ):
        current_audience.return_value = "Approved Customer"
        banner_items.return_value = [{"id": "banner-1", "title": "Deadline"}]
        tax_update_items.return_value = [
            {"id": "tax-1", "title": "Tax update", "priority": 30, "sort_order": 20}
        ]
        announcement_items.return_value = [
            {
                "id": "announcement-1",
                "title": "OMC update",
                "priority": 20,
                "sort_order": 10,
            }
        ]
        knowledge_items.return_value = [
            {"id": "guide-1", "title": "NTN guide", "priority": 10, "sort_order": 10}
        ]

        result = home_content.get_home_content()

        self.assertEqual(result["audience"], "Approved Customer")
        self.assertEqual(result["featured_banners"][0]["id"], "banner-1")
        self.assertEqual(
            [item["id"] for item in result["tax_business_updates"]],
            ["tax-1", "announcement-1"],
        )
        self.assertEqual(result["learn_grow"][0]["id"], "guide-1")
        self.assertNotIn("content", result["learn_grow"][0])
