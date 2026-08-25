from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

import frappe

from omc_app.setup.service_catalogue import provisioner


def _preview(
    *,
    created=0,
    updated=0,
    deactivated=0,
    conflicts=0,
    blockers=0,
    ready=True,
):
    return {
        "ok": True,
        "read_only": True,
        "ready_to_sync": ready,
        "summary": {
            "totals": {
                "created": created,
                "updated": updated,
                "deactivated": deactivated,
                "unchanged": 0,
                "conflicts": conflicts,
                "blockers": blockers,
            }
        },
        "blockers": (
            [{"type": "blocker"}]
            if blockers
            else []
        ),
        "conflicts": (
            [{"type": "conflict"}]
            if conflicts
            else []
        ),
    }


def _counts(
    *,
    created=0,
    updated=0,
    deactivated=0,
    unchanged=0,
):
    return {
        "created": created,
        "updated": updated,
        "deactivated": deactivated,
        "unchanged": unchanged,
    }


class TestServiceCatalogueSync(unittest.TestCase):
    def test_validate_reports_pending_reconciliation(self):
        with patch.object(
            provisioner,
            "preview_service_catalogue",
            return_value=_preview(
                created=10,
                updated=2,
            ),
        ):
            result = (
                provisioner.validate_service_catalogue()
            )

        self.assertFalse(
            result["valid"]
        )
        self.assertTrue(
            result["ready_to_sync"]
        )
        self.assertEqual(
            result["pending"]["created"],
            10,
        )
        self.assertEqual(
            result["pending"]["updated"],
            2,
        )

    def test_sync_rolls_back_when_write_fails(self):
        with (
            patch.object(
                provisioner,
                "preview_service_catalogue",
                return_value=_preview(),
            ),
            patch.object(
                provisioner,
                "_sync_categories",
                return_value=_counts(),
            ),
            patch.object(
                provisioner,
                "_sync_services",
                side_effect=RuntimeError(
                    "forced failure"
                ),
            ),
            patch.object(
                frappe.db,
                "savepoint",
            ) as savepoint,
            patch.object(
                frappe.db,
                "rollback",
            ) as rollback,
            patch.object(
                frappe.db,
                "commit",
            ) as commit,
        ):
            with self.assertRaises(
                RuntimeError
            ):
                provisioner.sync_service_catalogue()

        savepoint.assert_called_once_with(
            "omc_service_catalogue_sync"
        )
        rollback.assert_called_once_with(
            save_point="omc_service_catalogue_sync"
        )
        commit.assert_not_called()

    def test_dirty_post_validation_rolls_back(self):
        preflight = _preview(
            created=10,
        )
        dirty_post = _preview(
            created=1,
        )

        with (
            patch.object(
                provisioner,
                "preview_service_catalogue",
                side_effect=[
                    preflight,
                    dirty_post,
                ],
            ),
            patch.object(
                provisioner,
                "_sync_categories",
                return_value=_counts(),
            ),
            patch.object(
                provisioner,
                "_sync_services",
                return_value=_counts(),
            ),
            patch.object(
                provisioner,
                "_sync_required_documents",
                return_value=_counts(),
            ),
            patch.object(
                provisioner,
                "_sync_form_fields",
                return_value=_counts(),
            ),
            patch.object(
                frappe.db,
                "savepoint",
            ),
            patch.object(
                frappe.db,
                "rollback",
            ) as rollback,
            patch.object(
                frappe.db,
                "commit",
            ) as commit,
        ):
            with self.assertRaises(
                Exception
            ):
                provisioner.sync_service_catalogue()

        rollback.assert_called_once_with(
            save_point="omc_service_catalogue_sync"
        )
        commit.assert_not_called()

    def test_success_commits_once_after_clean_validation(self):
        preflight = _preview(
            created=155,
            updated=36,
        )
        clean_post = _preview()

        fixed_time = (
            "2026-08-25 15:30:00"
        )

        with (
            patch.object(
                provisioner,
                "preview_service_catalogue",
                side_effect=[
                    preflight,
                    clean_post,
                ],
            ),
            patch.object(
                provisioner,
                "now_datetime",
                return_value=fixed_time,
            ),
            patch.object(
                provisioner,
                "_sync_categories",
                return_value=_counts(
                    created=9,
                ),
            ),
            patch.object(
                provisioner,
                "_sync_services",
                return_value=_counts(
                    created=2,
                    updated=29,
                ),
            ),
            patch.object(
                provisioner,
                "_sync_required_documents",
                return_value=_counts(
                    created=86,
                    updated=7,
                ),
            ) as sync_documents,
            patch.object(
                provisioner,
                "_sync_form_fields",
                return_value=_counts(
                    created=58,
                    unchanged=4,
                ),
            ),
            patch.object(
                frappe.db,
                "savepoint",
            ),
            patch.object(
                frappe.db,
                "rollback",
            ) as rollback,
            patch.object(
                frappe.db,
                "commit",
            ) as commit,
        ):
            result = (
                provisioner.sync_service_catalogue()
            )

        sync_documents.assert_called_once_with(
            fixed_time
        )
        rollback.assert_not_called()
        commit.assert_called_once_with()

        self.assertTrue(
            result["validation"]["valid"]
        )
        self.assertTrue(
            result["committed"]
        )
        self.assertEqual(
            result["totals"]["created"],
            155,
        )
        self.assertEqual(
            result["totals"]["updated"],
            36,
        )
        self.assertEqual(
            result["totals"]["deleted"],
            0,
        )
        self.assertEqual(
            result["totals"]["conflicts"],
            0,
        )

    def test_form_field_management_marker_is_fail_closed(self):
        self.assertFalse(
            provisioner._form_field_is_catalogue_managed(
                {}
            )
        )
        self.assertFalse(
            provisioner._form_field_is_catalogue_managed(
                {
                    "catalogue_managed": 0,
                }
            )
        )
        self.assertTrue(
            provisioner._form_field_is_catalogue_managed(
                {
                    "catalogue_managed": 1,
                }
            )
        )

    def test_preview_preserves_unmanaged_extra_form_field(self):
        desired = provisioner._desired_form_field_values(
            provisioner.FORM_FIELDS_BY_SERVICE[
                "gst-registration"
            ][0],
            sort_order=1,
        )

        rows = [
            {
                "name": "OMC-SFF-00004",
                **desired,
            },
            {
                "name": "OMC-SFF-MANUAL",
                "fieldname": "manual_note",
                "label": "Manual Note",
                "fieldtype": "Data",
                "options": "",
                "placeholder": "",
                "description": "",
                "is_required": 0,
                "default_value": "",
                "depends_on": "",
                "sort_order": 99,
                "is_active": 1,
                "catalogue_managed": 0,
            },
        ]

        conflicts = []

        with patch.object(
            provisioner,
            "_form_field_rows",
            return_value=rows,
        ):
            result = (
                provisioner._preview_form_fields_for_service(
                    "gst-registration",
                    "gst-registration",
                    conflicts=conflicts,
                )
            )

        self.assertEqual(
            result["deactivate"],
            [],
        )
        self.assertEqual(
            result["ignored_unmanaged"],
            [
                "gst-registration:manual_note",
            ],
        )
        self.assertEqual(
            conflicts,
            [],
        )

    def test_new_requirement_receives_sync_effective_from(self):
        insert = MagicMock()

        document = SimpleNamespace(
            insert=insert,
        )

        timestamp = (
            "2026-08-25 15:30:00"
        )

        desired = {
            "document_key": "bank_statement",
            "document_title": "Bank Statement",
            "document_type": "Financial",
            "is_required": 1,
            "instructions": "",
            "allowed_extensions": "pdf,jpg,jpeg,png",
            "max_size_mb": 10,
            "sort_order": 1,
            "is_active": 1,
        }

        with patch.object(
            provisioner.frappe,
            "new_doc",
            return_value=document,
        ):
            result = (
                provisioner._insert_required_document(
                    "business-tax-filing",
                    desired,
                    timestamp,
                )
            )

        self.assertIs(
            result,
            document,
        )
        self.assertEqual(
            document.service,
            "business-tax-filing",
        )
        self.assertEqual(
            document.document_key,
            "bank_statement",
        )
        self.assertEqual(
            document.effective_from,
            timestamp,
        )
        insert.assert_called_once_with(
            ignore_permissions=True
        )
