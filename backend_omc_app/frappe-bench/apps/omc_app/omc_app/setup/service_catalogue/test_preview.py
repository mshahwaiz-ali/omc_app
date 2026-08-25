from types import SimpleNamespace
import unittest
from unittest.mock import patch

import frappe

from omc_app.setup.service_catalogue.manifest import (
    service_by_id,
)
from omc_app.setup.service_catalogue.provisioner import (
    _changes,
    _desired_service_values,
    preview_service_catalogue,
)


class TestServiceCataloguePreview(unittest.TestCase):
    def test_existing_service_authority_is_preserved(self):
        service = service_by_id()[
            "gst-registration"
        ]

        current = {
            "service_version": 7,
            "tax_policy": "Tax Exclusive",
            "tax_rate": 15,
            "pending_payment_expiry_hours": 96,
            "duplicate_window_hours": 48,
            "allow_parallel_requests": 1,
            "default_assignee": "staff@example.com",
            "default_assignment_role": "OMC Consultant",
            "pricing_version": "SERVER-HASH",
        }

        desired = _desired_service_values(
            service,
            current,
        )

        self.assertEqual(
            desired["service_version"],
            7,
        )
        self.assertEqual(
            desired["tax_policy"],
            "Tax Exclusive",
        )
        self.assertEqual(
            desired["tax_rate"],
            15,
        )
        self.assertEqual(
            desired[
                "pending_payment_expiry_hours"
            ],
            96,
        )
        self.assertEqual(
            desired["duplicate_window_hours"],
            48,
        )
        self.assertEqual(
            desired["allow_parallel_requests"],
            1,
        )

        self.assertNotIn(
            "default_assignee",
            desired,
        )
        self.assertNotIn(
            "default_assignment_role",
            desired,
        )
        self.assertNotIn(
            "pricing_version",
            desired,
        )

    def test_diff_preserves_exact_internal_spaces(self):
        changes = _changes(
            {
                "erp_task_type": (
                    "NTN MODIFICATION"
                ),
            },
            {
                "erp_task_type": (
                    "NTN  MODIFICATION"
                ),
            },
        )

        self.assertIn(
            "erp_task_type",
            changes,
        )

    def test_real_preview_has_no_mutation_calls(self):
        with (
            patch.object(
                frappe.db,
                "commit",
                side_effect=AssertionError(
                    "preview attempted commit"
                ),
            ),
            patch.object(
                frappe.db,
                "set_value",
                side_effect=AssertionError(
                    "preview attempted set_value"
                ),
            ),
            patch.object(
                frappe,
                "new_doc",
                side_effect=AssertionError(
                    "preview attempted new_doc"
                ),
            ),
        ):
            result = (
                preview_service_catalogue()
            )

        self.assertTrue(result["ok"])
        self.assertTrue(result["read_only"])
        self.assertEqual(
            result["operation"],
            "preview_service_catalogue",
        )
        self.assertEqual(
            result["preconditions"][
                "task_types"
            ]["expected"],
            31,
        )

    def test_zero_price_unknown_service_is_not_no_charge(self):
        service = service_by_id()["tax-club"]

        desired = _desired_service_values(
            service,
            {},
        )

        self.assertEqual(
            desired["base_price"],
            0,
        )
        self.assertEqual(
            desired["activation_policy"],
            "Full Settlement",
        )
        self.assertEqual(
            desired["fee_label"],
            "Contact OMC for pricing",
        )
        self.assertEqual(
            desired["is_active"],
            0,
        )
