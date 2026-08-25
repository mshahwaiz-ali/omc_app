import unittest
from unittest.mock import patch

from omc_app.setup.service_catalogue import legacy_retirement

from omc_app.setup.service_catalogue.legacy_retirement import (
    LEGACY_SERVICE_DUPLICATES,
)


class TestLegacyRetirement(unittest.TestCase):
    def test_exact_legacy_aliases_are_locked(self):
        self.assertEqual(
            LEGACY_SERVICE_DUPLICATES,
            (
                {
                    "legacy_id":
                        "advocacy-service---hearing-with-commissioner",
                    "canonical_id":
                        "advocacy-service-hearing-with-commissioner",
                    "task_type":
                        "Advocacy Service - Hearing with Commissioner",
                },
                {
                    "legacy_id":
                        "ntn--modification",
                    "canonical_id":
                        "ntn-modification",
                    "task_type":
                        "NTN  MODIFICATION",
                },
            ),
        )

    def test_single_doctype_reference_is_scanned_without_table_count(self):
        def service_row(service_id):
            for spec in LEGACY_SERVICE_DUPLICATES:
                if service_id == spec["legacy_id"]:
                    return {
                        "name": service_id,
                        "service_id": service_id,
                        "title": "Legacy",
                        "is_active": 0,
                        "erp_task_type": None,
                    }

                if service_id == spec["canonical_id"]:
                    return {
                        "name": service_id,
                        "service_id": service_id,
                        "title": "Canonical",
                        "is_active": 0,
                        "erp_task_type": spec["task_type"],
                    }

            return None

        with (
            patch.object(
                legacy_retirement,
                "_service",
                side_effect=service_row,
            ),
            patch.object(
                legacy_retirement,
                "_historical_requests",
                return_value=[],
            ),
            patch.object(
                legacy_retirement,
                "_link_fields",
                return_value={
                    (
                        "OMC Tax Calculator Settings",
                        "customer_cta_service",
                    ),
                },
            ),
            patch.object(
                legacy_retirement.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                legacy_retirement.frappe,
                "get_meta",
                return_value=type(
                    "Meta",
                    (),
                    {"issingle": 1},
                )(),
            ),
            patch.object(
                legacy_retirement.frappe.db,
                "get_single_value",
                return_value="ntn-modification",
            ) as get_single_value,
            patch.object(
                legacy_retirement.frappe.db,
                "count",
            ) as count,
        ):
            result = (
                legacy_retirement
                .preview_legacy_service_retirement()
            )

        self.assertTrue(
            result["ready_to_retire"]
        )
        get_single_value.assert_called()
        count.assert_not_called()

    def test_reference_scan_failure_blocks_retirement(self):
        def service_row(service_id):
            for spec in LEGACY_SERVICE_DUPLICATES:
                if service_id == spec["legacy_id"]:
                    return {
                        "name": service_id,
                        "service_id": service_id,
                        "title": "Legacy",
                        "is_active": 0,
                        "erp_task_type": spec["task_type"],
                    }

                if service_id == spec["canonical_id"]:
                    return {
                        "name": service_id,
                        "service_id": service_id,
                        "title": "Canonical",
                        "is_active": 0,
                        "erp_task_type": spec["task_type"],
                    }

            return None

        with (
            patch.object(
                legacy_retirement,
                "_service",
                side_effect=service_row,
            ),
            patch.object(
                legacy_retirement,
                "_historical_requests",
                return_value=[],
            ),
            patch.object(
                legacy_retirement,
                "_link_fields",
                return_value={
                    ("OMC Linked Record", "service"),
                },
            ),
            patch.object(
                legacy_retirement.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                legacy_retirement.frappe.db,
                "count",
                side_effect=RuntimeError(
                    "reference scan unavailable"
                ),
            ),
        ):
            result = (
                legacy_retirement
                .preview_legacy_service_retirement()
            )

        self.assertFalse(
            result["ready_to_retire"]
        )
        self.assertTrue(
            any(
                blocker.get("type")
                == "reference_scan_failed"
                for blocker in result["blockers"]
            )
        )

    def test_legacy_and_canonical_ids_are_distinct(self):
        for item in LEGACY_SERVICE_DUPLICATES:
            self.assertNotEqual(
                item["legacy_id"],
                item["canonical_id"],
            )
