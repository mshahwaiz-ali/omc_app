from pathlib import Path

from frappe.tests.utils import FrappeTestCase


class TestDeskDiscountWorkflow(FrappeTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()

        cls.source = (
            Path(__file__).resolve().parents[1]
            / "omc_app"
            / "doctype"
            / "omc_service_request"
            / "omc_service_request.js"
        ).read_text(encoding="utf-8")

    def test_new_desk_request_exposes_discount_inputs(self):
        for marker in (
            '"discount_type"',
            '"discount_value"',
            '"discount_reason"',
            "omc_validate_desk_discount",
            "omc_refresh_discount_preview",
        ):
            self.assertIn(marker, self.source)

    def test_guarded_create_sends_discount_payload(self):
        for marker in (
            "discount_type:",
            "discount_value:",
            "discount_reason:",
            "discount.discountType",
            "discount.discountValue",
            "discount.discountReason",
        ):
            self.assertIn(marker, self.source)

    def test_saved_request_uses_authoritative_review_api(self):
        self.assertIn(
            "omc_app.api.admin_control.review_discount",
            self.source,
        )
        self.assertIn(
            "get_case_admin_options",
            self.source,
        )
        self.assertIn(
            "can_review_discount",
            self.source,
        )

    def test_review_actions_exist_only_for_pending_discount_flow(self):
        for marker in (
            "Pending Approval",
            "Approve Discount",
            "Reject Discount",
            "omc_add_request_discount_actions",
        ):
            self.assertIn(marker, self.source)
