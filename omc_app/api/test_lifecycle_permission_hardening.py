from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import request_lifecycle
from omc_app.setup import roles


class TestLifecyclePermissionHardening(FrappeTestCase):
    def test_terminal_document_cleanup_errors_propagate(self):
        with patch(
            "omc_app.api.customer_documents.archive_service_documents_for_status",
            side_effect=RuntimeError("archive failed"),
        ):
            with self.assertRaisesRegex(RuntimeError, "archive failed"):
                request_lifecycle._archive_documents("OMC-SR-TEST", "Cancelled")

    def test_permission_classification_sets_are_disjoint(self):
        groups = (
            roles.ADMIN_MUTABLE_DOCTYPES,
            roles.ADMIN_READ_ONLY_DOCTYPES,
            roles.INTERNAL_ONLY_DOCTYPES,
        )
        for index, left in enumerate(groups):
            for right in groups[index + 1 :]:
                self.assertFalse(left.intersection(right))

    def test_every_non_child_omc_doctype_is_explicitly_classified(self):
        classified = (
            roles.ADMIN_MUTABLE_DOCTYPES
            | roles.ADMIN_READ_ONLY_DOCTYPES
            | roles.INTERNAL_ONLY_DOCTYPES
        )
        rows = frappe.get_all(
            "DocType",
            filters={"module": "OMC App", "name": ["like", "OMC %"]},
            fields=["name", "istable"],
            limit_page_length=500,
        )
        unclassified = sorted(
            row.name
            for row in rows
            if not int(row.istable or 0) and row.name not in classified
        )
        self.assertEqual(unclassified, [])

    def test_system_manager_has_no_omc_docperm(self):
        rows = frappe.get_all(
            "DocPerm",
            filters={
                "role": roles.SYSTEM_ROLE,
                "parent": ["like", "OMC %"],
            },
            pluck="name",
            limit_page_length=500,
        )
        self.assertEqual(rows, [])

    def test_internal_only_models_have_no_staff_docperm(self):
        managed_roles = roles.ACTIVE_OMC_ROLES | {roles.SYSTEM_ROLE}
        violations = []
        for doctype in sorted(roles.INTERNAL_ONLY_DOCTYPES):
            rows = frappe.get_all(
                "DocPerm",
                filters={
                    "parent": doctype,
                    "role": ["in", sorted(managed_roles)],
                },
                fields=["role", "read", "write", "create", "delete"],
                limit_page_length=100,
            )
            violations.extend(
                f"{doctype}:{row.role}"
                for row in rows
                if any(int(row.get(fieldname) or 0) for fieldname in ("read", "write", "create", "delete"))
            )
        self.assertEqual(violations, [])

    def test_evidence_models_are_not_directly_writable_by_admin(self):
        violations = []
        for doctype in sorted(roles.ADMIN_READ_ONLY_DOCTYPES):
            rows = frappe.get_all(
                "DocPerm",
                filters={"parent": doctype, "role": roles.ADMIN_ROLE},
                fields=["write", "create", "delete", "submit", "cancel", "amend", "import", "share"],
                limit_page_length=20,
            )
            for row in rows:
                writable = [
                    fieldname
                    for fieldname in ("write", "create", "delete", "submit", "cancel", "amend", "import", "share")
                    if int(row.get(fieldname) or 0)
                ]
                if writable:
                    violations.append(f"{doctype}:{','.join(writable)}")
        self.assertEqual(violations, [])
