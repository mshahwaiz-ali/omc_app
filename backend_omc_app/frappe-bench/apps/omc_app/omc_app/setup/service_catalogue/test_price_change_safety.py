import unittest

from omc_app.setup.service_catalogue import provisioner


class TestPriceChangeSafety(unittest.TestCase):
    def test_canonical_historical_projection_is_recognized(self):
        self.assertTrue(
            provisioner._request_is_historical_projection(
                {
                    "request_state": "Historical",
                    "source_channel": "Imported",
                    "submission_mode": "Historical Import",
                    "erp_sync_status": "Historical",
                }
            )
        )

    def test_overdue_status_does_not_make_historical_projection_live(self):
        self.assertTrue(
            provisioner._request_is_historical_projection(
                {
                    "status": "Overdue",
                    "request_state": "Historical",
                    "source_channel": "Imported",
                    "submission_mode": "Historical Import",
                    "erp_sync_status": "Historical",
                }
            )
        )

    def test_partial_historical_markers_fail_closed(self):
        self.assertFalse(
            provisioner._request_is_historical_projection(
                {
                    "request_state": "Historical",
                    "source_channel": "Imported",
                    "submission_mode": "",
                    "erp_sync_status": "Historical",
                }
            )
        )

    def test_live_request_is_not_historical_projection(self):
        self.assertFalse(
            provisioner._request_is_historical_projection(
                {
                    "request_state": "Draft",
                    "source_channel": "Mobile",
                    "submission_mode": "Customer",
                    "erp_sync_status": "",
                }
            )
        )

    def test_blank_legacy_snapshot_is_unsafe(self):
        self.assertFalse(
            provisioner._request_pricing_snapshot_is_safe(
                {
                    "payment_policy_snapshot":
                        "Full Settlement",
                    "original_price": 0,
                    "final_price": 0,
                    "payable_amount": 0,
                    "pricing_currency": "",
                    "pricing_version_snapshot": "",
                    "service_version_snapshot": 0,
                    "discount_status": "",
                }
            )
        )

    def test_frozen_payable_snapshot_is_safe(self):
        self.assertTrue(
            provisioner._request_pricing_snapshot_is_safe(
                {
                    "payment_policy_snapshot":
                        "Full Settlement",
                    "original_price": 15000,
                    "final_price": 15000,
                    "payable_amount": 15000,
                    "pricing_currency": "PKR",
                    "pricing_version_snapshot":
                        "pricing-v1",
                    "service_version_snapshot": 1,
                    "discount_status": "None",
                }
            )
        )

    def test_pending_discount_snapshot_is_safe(self):
        self.assertTrue(
            provisioner._request_pricing_snapshot_is_safe(
                {
                    "payment_policy_snapshot":
                        "Full Settlement",
                    "original_price": 15000,
                    "proposed_final_price": 12000,
                    "final_price": 0,
                    "payable_amount": 0,
                    "pricing_currency": "PKR",
                    "pricing_version_snapshot":
                        "pricing-v1",
                    "service_version_snapshot": 1,
                    "discount_status":
                        "Pending Approval",
                }
            )
        )

    def test_existing_payment_is_safe(self):
        self.assertTrue(
            provisioner._request_pricing_snapshot_is_safe(
                {},
                has_active_payment=True,
            )
        )
