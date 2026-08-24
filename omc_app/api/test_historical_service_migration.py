import json
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import historical_service_migration


class TestHistoricalServiceMigrationSchema(FrappeTestCase):
    @staticmethod
    def _options(field):
        return {
            value.strip()
            for value in str(field.options or "").splitlines()
            if value.strip()
        }

    def test_company_snapshot_authority_field_exists(self):
        meta = frappe.get_meta(
            "OMC Service Request",
            cached=False,
        )

        field = meta.get_field("company_snapshot")

        self.assertIsNotNone(field)
        self.assertEqual(field.fieldtype, "Link")
        self.assertEqual(field.options, "Company")
        self.assertTrue(field.read_only)

    def test_submission_mode_supports_historical_import(self):
        meta = frappe.get_meta(
            "OMC Service Request",
            cached=False,
        )

        field = meta.get_field("submission_mode")

        self.assertIsNotNone(field)
        self.assertIn(
            "Historical Import",
            self._options(field),
        )

    def test_erp_sync_status_supports_historical(self):
        meta = frappe.get_meta(
            "OMC Service Request",
            cached=False,
        )

        field = meta.get_field("erp_sync_status")

        self.assertIsNotNone(field)
        self.assertIn(
            "Historical",
            self._options(field),
        )

    def test_historical_evidence_field_is_read_only_json(self):
        meta = frappe.get_meta(
            "OMC Service Request",
            cached=False,
        )

        field = meta.get_field("historical_evidence_json")

        self.assertIsNotNone(field)
        self.assertEqual(field.fieldtype, "Code")
        self.assertEqual(field.options, "JSON")
        self.assertTrue(field.read_only)
        self.assertTrue(field.hidden)

class TestHistoricalServiceMigrationProjectionContracts(FrappeTestCase):
    def test_approved_existing_account_requires_canonical_safe_state(self):
        accounts = [
            frappe._dict(
                name="customer@example.com",
                erp_customer="ERP-CUST-1",
                legacy_customer_profile="OMC-CUST-1",
                identity_proof_status="Verified",
                account_link_status="Linked",
                service_access_status="Approved",
            )
        ]

        self.assertEqual(
            historical_service_migration
            ._approved_existing_account_name(
                "ERP-CUST-1",
                "OMC-CUST-1",
                accounts,
            ),
            "customer@example.com",
        )

    def test_approved_existing_account_rejects_unapproved_or_conflicting_account(self):
        pending = [
            frappe._dict(
                name="customer@example.com",
                erp_customer="ERP-CUST-1",
                legacy_customer_profile="OMC-CUST-1",
                identity_proof_status="Verified",
                account_link_status="Linked",
                service_access_status="Pending Review",
            )
        ]

        self.assertEqual(
            historical_service_migration
            ._approved_existing_account_name(
                "ERP-CUST-1",
                "OMC-CUST-1",
                pending,
            ),
            "",
        )

        conflicting_profile = [
            frappe._dict(
                name="customer@example.com",
                erp_customer="ERP-CUST-1",
                legacy_customer_profile="OMC-CUST-OTHER",
                identity_proof_status="Verified",
                account_link_status="Linked",
                service_access_status="Approved",
            )
        ]

        self.assertEqual(
            historical_service_migration
            ._approved_existing_account_name(
                "ERP-CUST-1",
                "OMC-CUST-1",
                conflicting_profile,
            ),
            "",
        )

    def test_completed_task_projects_existing_task_and_closed_on(self):
        service = frappe._dict(
            name="SERV0001",
            customer="ERP-CUST-1",
            service_type="Tax Filing",
        )
        task = frappe._dict(
            name="TASK-0001",
            customer="ERP-CUST-1",
            type="Tax Filing",
            status="Completed",
            custom_operation_status="Open",
            completed_on="2026-01-15 12:30:00",
            modified="2026-01-16 09:00:00",
        )

        result = historical_service_migration._task_projection(
            service,
            task,
        )

        self.assertEqual(result["erp_task"], "TASK-0001")
        self.assertEqual(result["status"], "Completed")
        self.assertEqual(
            str(result["closed_on"]),
            "2026-01-15 12:30:00",
        )
        self.assertEqual(result["review_reasons"], [])

    def test_task_type_mismatch_never_links_task(self):
        service = frappe._dict(
            name="SERV0037",
            customer="Shahrukh sattar Testing",
            service_type="Financials",
        )
        task = frappe._dict(
            name="TASK-2026-00210",
            customer="Shahrukh sattar Testing",
            type="7E Exemption Certificate",
            status="Overdue",
            custom_operation_status="Open",
            modified="2026-02-01 10:00:00",
        )

        result = historical_service_migration._task_projection(
            service,
            task,
        )

        self.assertEqual(result["erp_task"], "")
        self.assertEqual(result["status"], "Historical")
        self.assertIsNone(result["closed_on"])
        self.assertIn(
            "task_type_mismatch",
            result["review_reasons"],
        )

    def test_missing_task_stays_neutral_historical(self):
        service = frappe._dict(
            name="SERV0002",
            customer="ERP-CUST-2",
            service_type="Tax Filing",
        )

        result = historical_service_migration._task_projection(
            service,
            None,
        )

        self.assertEqual(result["erp_task"], "")
        self.assertEqual(result["status"], "Historical")
        self.assertIsNone(result["closed_on"])

    def test_overdue_task_status_remains_authoritative(self):
        service = frappe._dict(
            name="SERV0003",
            customer="ERP-CUST-3",
            service_type="Tax Filing",
        )
        task = frappe._dict(
            name="TASK-0003",
            customer="ERP-CUST-3",
            type="Tax Filing",
            status="Overdue",
            custom_operation_status="Open",
            modified="2026-01-20 10:00:00",
        )

        result = historical_service_migration._task_projection(
            service,
            task,
        )

        self.assertEqual(result["erp_task"], "TASK-0003")
        self.assertEqual(result["status"], "Overdue")
        self.assertIsNone(result["closed_on"])

    def test_historical_evidence_preserves_raw_amounts_without_financial_truth(self):
        service = frappe._dict(
            name="SERV0004",
            customer="ERP-CUST-4",
            service_type="Tax Filing",
            service_amount=12000,
            discount=2000,
            net_service_amount=9000,
            task_created=1,
            task_link="TASK-0004",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )
        task = frappe._dict(
            name="TASK-0004",
            customer="ERP-CUST-4",
            type="Tax Filing",
            status="Completed",
            custom_operation_status="Completed",
            completed_on="2025-12-15 14:00:00",
            modified="2025-12-15 14:05:00",
        )

        evidence = (
            historical_service_migration
            ._historical_evidence(
                service,
                task,
                ["task_type_mismatch"],
            )
        )

        self.assertEqual(
            evidence["erp_service"]["service_amount"],
            12000,
        )
        self.assertEqual(
            evidence["erp_service"]["discount"],
            2000,
        )
        self.assertEqual(
            evidence["erp_service"]["net_service_amount"],
            9000,
        )
        self.assertEqual(
            evidence["erp_task"]["name"],
            "TASK-0004",
        )
        self.assertIn(
            "task_type_mismatch",
            evidence["review_reasons"],
        )
        self.assertNotIn(
            "historical_amount_mismatch",
            evidence["review_reasons"],
        )
        self.assertNotIn(
            "amount_consistent",
            evidence,
        )

        for forbidden in (
            "final_price",
            "payable_amount",
            "payment_status",
            "settlement_status",
            "accounting_status",
        ):
            self.assertNotIn(forbidden, evidence)

    def test_service_master_values_are_inactive_legacy_catalogue_only(self):
        task_type = frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

        values = historical_service_migration._service_master_values(
            task_type
        )

        self.assertEqual(values["title"], "Tax Filing Service")
        self.assertEqual(values["erp_task_type"], "Tax Filing")
        self.assertEqual(values["base_price"], 15000)
        self.assertEqual(values["currency"], "PKR")
        self.assertEqual(values["is_active"], 0)

        self.assertNotIn("company", values)
        self.assertNotIn("default_assignee", values)
        self.assertNotIn("estimated_duration", values)
        self.assertNotIn("activation_policy", values)

class TestHistoricalServiceRequestPayloadContracts(FrappeTestCase):
    def _service(self, **overrides):
        values = {
            "name": "SERV0001",
            "customer": "ERP-CUST-1",
            "service_type": "Tax Filing",
            "service_amount": 12000,
            "discount": 2000,
            "net_service_amount": 10000,
            "task_created": 0,
            "task_link": "",
            "date": "2025-12-01",
            "creation": "2025-12-01 10:00:00",
        }
        values.update(overrides)
        return frappe._dict(values)

    def _mapped_service(self):
        return frappe._dict(
            name="tax-filing-service",
            title="Tax Filing Service",
            erp_task_type="Tax Filing",
            is_active=0,
        )

    def test_no_task_builds_neutral_historical_request(self):
        values = (
            historical_service_migration
            ._historical_request_values(
                self._service(),
                self._mapped_service(),
                profile_name="OMC-CUST-1",
                account_name="customer@example.com",
                task=None,
            )
        )

        self.assertEqual(
            values["doctype"],
            "OMC Service Request",
        )
        self.assertEqual(
            values["request_state"],
            "Historical",
        )
        self.assertEqual(
            values["status"],
            "Historical",
        )
        self.assertEqual(
            values["source_channel"],
            "Imported",
        )
        self.assertEqual(
            values["submission_mode"],
            "Historical Import",
        )
        self.assertEqual(
            values["erp_sync_status"],
            "Historical",
        )

        self.assertEqual(
            values["service"],
            "tax-filing-service",
        )
        self.assertEqual(
            values["service_title"],
            "Tax Filing Service",
        )
        self.assertEqual(
            values["title"],
            "Tax Filing Service",
        )
        self.assertEqual(
            values["erp_customer"],
            "ERP-CUST-1",
        )
        self.assertEqual(
            values["erp_service"],
            "SERV0001",
        )
        self.assertEqual(values["erp_task"], "")

        self.assertEqual(
            values["customer_profile"],
            "OMC-CUST-1",
        )
        self.assertEqual(
            values["customer_account"],
            "customer@example.com",
        )

        self.assertEqual(values["requested_by"], "")
        self.assertEqual(values["company_snapshot"], "")
        self.assertIsNone(values["closed_on"])

    def test_request_payload_never_fabricates_financial_or_submission_truth(self):
        values = (
            historical_service_migration
            ._historical_request_values(
                self._service(),
                self._mapped_service(),
                profile_name="",
                account_name="",
                task=None,
            )
        )

        for forbidden in (
            "original_price",
            "discount_type",
            "discount_value",
            "discount_amount",
            "proposed_final_price",
            "final_price",
            "tax_amount",
            "payable_amount",
            "pricing_snapshot_json",
            "payment_policy_snapshot",
            "tax_policy_snapshot",
            "submission_data_json",
            "referral_attribution",
        ):
            self.assertNotIn(forbidden, values)

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertEqual(
            evidence["erp_service"]["service_amount"],
            12000,
        )
        self.assertEqual(
            evidence["erp_service"]["discount"],
            2000,
        )
        self.assertEqual(
            evidence["erp_service"]["net_service_amount"],
            10000,
        )

    def test_mismatched_task_is_preserved_as_evidence_but_not_linked(self):
        task = frappe._dict(
            name="TASK-2026-00210",
            customer="ERP-CUST-1",
            type="7E Exemption Certificate",
            status="Overdue",
            custom_operation_status="Open",
            modified="2026-02-01 10:00:00",
        )

        values = (
            historical_service_migration
            ._historical_request_values(
                self._service(
                    name="SERV0037",
                    service_type="Financials",
                    task_created=1,
                    task_link="TASK-2026-00210",
                ),
                frappe._dict(
                    name="financials",
                    title="Financials",
                    erp_task_type="Financials",
                    is_active=0,
                ),
                profile_name="",
                account_name="",
                task=task,
            )
        )

        self.assertEqual(values["status"], "Historical")
        self.assertEqual(values["erp_task"], "")
        self.assertIsNone(values["closed_on"])

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertEqual(
            evidence["erp_task"]["name"],
            "TASK-2026-00210",
        )
        self.assertIn(
            "task_type_mismatch",
            evidence["review_reasons"],
        )

class TestHistoricalServiceMasterWriterContracts(FrappeTestCase):
    def _task_type(self):
        return frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

    def test_new_task_type_creates_one_inactive_service(self):
        fake_doc = MagicMock()
        fake_doc.name = "tax-filing-service"

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=[],
        ), patch.object(
            historical_service_migration,
            "_service_master_values",
            return_value={
                "doctype": "OMC Service",
                "title": "Tax Filing Service",
                "description": "Legacy tax filing service.",
                "base_price": 15000,
                "currency": "PKR",
                "erp_task_type": "Tax Filing",
                "is_active": 0,
            },
        ), patch.object(
            historical_service_migration.frappe,
            "get_doc",
            return_value=fake_doc,
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_service_master(
                    self._task_type()
                )
            )

        self.assertEqual(result["action"], "created")
        self.assertEqual(
            result["service"],
            "tax-filing-service",
        )
        self.assertEqual(
            result["review_reasons"],
            [],
        )

        fake_doc.insert.assert_called_once_with(
            ignore_permissions=True
        )

        values = get_doc.call_args.args[0]

        self.assertEqual(
            values["doctype"],
            "OMC Service",
        )
        self.assertEqual(
            values["erp_task_type"],
            "Tax Filing",
        )
        self.assertEqual(
            values["title"],
            "Tax Filing Service",
        )
        self.assertEqual(values["is_active"], 0)
        self.assertEqual(values["currency"], "PKR")

        self.assertNotIn("company", values)
        self.assertNotIn("default_assignee", values)
        self.assertNotIn("activation_policy", values)

    def test_existing_unique_mapping_is_reused_without_insert(self):
        existing = [
            frappe._dict(
                name="existing-tax-service",
                title="Tax Filing Service",
                erp_task_type="Tax Filing",
                is_active=0,
            )
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=existing,
        ), patch.object(
            historical_service_migration.frappe,
            "get_doc",
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_service_master(
                    self._task_type()
                )
            )

        self.assertEqual(result["action"], "reused")
        self.assertEqual(
            result["service"],
            "existing-tax-service",
        )
        self.assertEqual(
            result["review_reasons"],
            [],
        )
        get_doc.assert_not_called()

    def test_multiple_existing_mappings_fail_closed(self):
        existing = [
            frappe._dict(
                name="tax-service-a",
                title="Tax Filing A",
                erp_task_type="Tax Filing",
                is_active=0,
            ),
            frappe._dict(
                name="tax-service-b",
                title="Tax Filing B",
                erp_task_type="Tax Filing",
                is_active=0,
            ),
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=existing,
        ), patch.object(
            historical_service_migration.frappe,
            "get_doc",
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_service_master(
                    self._task_type()
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertEqual(result["service"], "")
        self.assertIn(
            "multiple_omc_service_mappings",
            result["review_reasons"],
        )
        self.assertEqual(
            result["omc_services"],
            ["tax-service-a", "tax-service-b"],
        )
        get_doc.assert_not_called()

    def test_rerun_reuses_created_mapping_instead_of_second_insert(self):
        fake_doc = MagicMock()
        fake_doc.name = "tax-filing-service"

        existing_after_first_run = [
            frappe._dict(
                name="tax-filing-service",
                title="Tax Filing Service",
                erp_task_type="Tax Filing",
                is_active=0,
            )
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            side_effect=[
                [],
                existing_after_first_run,
            ],
        ), patch.object(
            historical_service_migration,
            "_service_master_values",
            return_value={
                "doctype": "OMC Service",
                "title": "Tax Filing Service",
                "description": "Legacy tax filing service.",
                "base_price": 15000,
                "currency": "PKR",
                "erp_task_type": "Tax Filing",
                "is_active": 0,
            },
        ), patch.object(
            historical_service_migration.frappe,
            "get_doc",
            return_value=fake_doc,
        ):
            first = (
                historical_service_migration
                ._ensure_service_master(
                    self._task_type()
                )
            )
            second = (
                historical_service_migration
                ._ensure_service_master(
                    self._task_type()
                )
            )

        self.assertEqual(first["action"], "created")
        self.assertEqual(second["action"], "reused")
        self.assertEqual(
            first["service"],
            second["service"],
        )
        fake_doc.insert.assert_called_once_with(
            ignore_permissions=True
        )

class TestHistoricalRequestWriterContracts(FrappeTestCase):
    def _service(self):
        return frappe._dict(
            name="SERV0001",
            customer="ERP-CUST-1",
            service_type="Tax Filing",
            service_amount=12000,
            discount=2000,
            net_service_amount=10000,
            task_created=0,
            task_link="",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )

    def _mapped_service(self):
        return frappe._dict(
            name="tax-filing-service",
            title="Tax Filing Service",
            erp_task_type="Tax Filing",
            is_active=0,
        )

    def _payload(self):
        return {
            "doctype": "OMC Service Request",
            "title": "Tax Filing Service",
            "service": "tax-filing-service",
            "service_title": "Tax Filing Service",
            "status": "Historical",
            "request_state": "Historical",
            "source_channel": "Imported",
            "submission_mode": "Historical Import",
            "erp_customer": "ERP-CUST-1",
            "erp_service": "SERV0001",
            "erp_task": "",
            "erp_sync_status": "Historical",
            "requested_by": "",
            "company_snapshot": "",
            "historical_evidence_json": "{}",
            "closed_on": None,
        }

    def test_new_erp_service_creates_one_historical_request(self):
        fake_doc = MagicMock()
        fake_doc.name = "OMC-SR-2026-00001"

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=[],
        ), patch.object(
            historical_service_migration,
            "_historical_request_values",
            return_value=self._payload(),
        ) as values_builder, patch.object(
            historical_service_migration.frappe,
            "get_doc",
            return_value=fake_doc,
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    profile_name="OMC-CUST-1",
                    account_name="customer@example.com",
                    task=None,
                )
            )

        self.assertEqual(result["action"], "created")
        self.assertEqual(
            result["request"],
            "OMC-SR-2026-00001",
        )
        self.assertEqual(result["review_reasons"], [])

        values_builder.assert_called_once()
        get_doc.assert_called_once_with(self._payload())
        fake_doc.insert.assert_called_once_with(
            ignore_permissions=True
        )

    def test_existing_single_projection_is_reused_without_insert(self):
        existing = [
            frappe._dict(
                name="OMC-SR-2025-00001",
                service="tax-filing-service",
                erp_service="SERV0001",
                erp_customer="ERP-CUST-1",
                erp_task="",
                source_channel="Imported",
                request_state="Historical",
                historical_evidence_json="{}",
            )
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=existing,
        ), patch.object(
            historical_service_migration,
            "_historical_request_values",
            return_value=self._payload(),
        ) as values_builder, patch.object(
            historical_service_migration.frappe,
            "get_doc",
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                )
            )

        self.assertEqual(result["action"], "reused")
        self.assertEqual(
            result["request"],
            "OMC-SR-2025-00001",
        )
        self.assertEqual(result["review_reasons"], [])
        values_builder.assert_called_once()
        self.assertFalse(result["changed"])
        self.assertEqual(result["repaired_fields"], [])
        get_doc.assert_not_called()

    def test_multiple_existing_projections_fail_closed(self):
        existing = [
            frappe._dict(
                name="OMC-SR-2025-00001",
                erp_service="SERV0001",
                erp_customer="ERP-CUST-1",
                source_channel="Imported",
                request_state="Historical",
            ),
            frappe._dict(
                name="OMC-SR-2025-00002",
                erp_service="SERV0001",
                erp_customer="ERP-CUST-1",
                source_channel="Imported",
                request_state="Historical",
            ),
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=existing,
        ), patch.object(
            historical_service_migration,
            "_historical_request_values",
        ) as values_builder, patch.object(
            historical_service_migration.frappe,
            "get_doc",
        ) as get_doc:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertEqual(result["request"], "")
        self.assertIn(
            "multiple_omc_projections",
            result["review_reasons"],
        )
        self.assertEqual(
            result["omc_requests"],
            [
                "OMC-SR-2025-00001",
                "OMC-SR-2025-00002",
            ],
        )
        values_builder.assert_not_called()
        get_doc.assert_not_called()

    def test_rerun_reuses_first_projection_instead_of_second_insert(self):
        fake_doc = MagicMock()
        fake_doc.name = "OMC-SR-2026-00001"

        existing_after_first_run = [
            frappe._dict(
                name="OMC-SR-2026-00001",
                service="tax-filing-service",
                erp_service="SERV0001",
                erp_customer="ERP-CUST-1",
                erp_task="",
                source_channel="Imported",
                request_state="Historical",
                historical_evidence_json="{}",
            )
        ]

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            side_effect=[
                [],
                existing_after_first_run,
            ],
        ), patch.object(
            historical_service_migration,
            "_historical_request_values",
            return_value=self._payload(),
        ), patch.object(
            historical_service_migration.frappe,
            "get_doc",
            return_value=fake_doc,
        ):
            first = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                )
            )
            second = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                )
            )

        self.assertEqual(first["action"], "created")
        self.assertEqual(second["action"], "reused")
        self.assertEqual(
            first["request"],
            second["request"],
        )
        fake_doc.insert.assert_called_once_with(
            ignore_permissions=True
        )

class TestHistoricalProjectionOrchestration(FrappeTestCase):
    def _task_type(self):
        return frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

    def _service(self, **overrides):
        values = {
            "name": "SERV0001",
            "customer": "ERP-CUST-1",
            "service_type": "Tax Filing",
            "service_amount": 12000,
            "discount": 2000,
            "net_service_amount": 10000,
            "task_created": 0,
            "task_link": "",
            "date": "2025-12-01",
            "creation": "2025-12-01 10:00:00",
        }
        values.update(overrides)
        return frappe._dict(values)

    def _get_all(self, doctype, **kwargs):
        if doctype == "Customer":
            return ["ERP-CUST-1"]

        if doctype == "OMC Customer Profile":
            return [
                frappe._dict(
                    name="OMC-CUST-1",
                    linked_erpnext_customer="ERP-CUST-1",
                )
            ]

        if doctype == "OMC Customer Account":
            return [
                frappe._dict(
                    name="customer@example.com",
                    erp_customer="ERP-CUST-1",
                    legacy_customer_profile="OMC-CUST-1",
                    identity_proof_status="Verified",
                    account_link_status="Linked",
                    service_access_status="Approved",
                )
            ]

        raise AssertionError(
            f"Unexpected get_all doctype: {doctype}"
        )

    def test_safe_service_projects_with_existing_profile_and_account(self):
        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[self._service()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=self._get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "created",
                    "service": "tax-filing-service",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["tax-filing-service"],
                },
            ) as ensure_master,
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
                return_value={
                    "action": "created",
                    "request": "OMC-SR-2026-00001",
                    "review_reasons": [],
                    "omc_requests": ["OMC-SR-2026-00001"],
                },
            ) as ensure_request,
            patch.object(
                historical_service_migration.frappe.db,
                "commit",
            ) as commit,
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        ensure_master.assert_called_once()

        request_kwargs = ensure_request.call_args.kwargs

        self.assertEqual(
            request_kwargs["profile_name"],
            "OMC-CUST-1",
        )
        self.assertEqual(
            request_kwargs["account_name"],
            "customer@example.com",
        )

        self.assertEqual(
            result["task_types"]["created"],
            1,
        )
        self.assertEqual(
            result["historical_services"]["created"],
            1,
        )
        self.assertTrue(result["changed"])

        commit.assert_not_called()

    def test_missing_customer_is_reviewed_and_never_projected(self):
        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return []
            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
            ):
                return []
            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[self._service()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "created",
                    "service": "tax-filing-service",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["tax-filing-service"],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
            ) as ensure_request,
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        ensure_request.assert_not_called()

        self.assertEqual(
            result["historical_services"]["skipped"],
            1,
        )
        self.assertEqual(
            result["review_reason_counts"],
            {"missing_erp_customer": 1},
        )

    def test_multiple_profiles_never_guessed_but_service_history_still_projects(self):
        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["ERP-CUST-1"]

            if doctype == "OMC Customer Profile":
                return [
                    frappe._dict(
                        name="OMC-CUST-A",
                        linked_erpnext_customer="ERP-CUST-1",
                    ),
                    frappe._dict(
                        name="OMC-CUST-B",
                        linked_erpnext_customer="ERP-CUST-1",
                    ),
                ]

            if doctype == "OMC Customer Account":
                return []

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[self._service()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "reused",
                    "service": "tax-filing-service",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["tax-filing-service"],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
                return_value={
                    "action": "created",
                    "request": "OMC-SR-2026-00001",
                    "review_reasons": [],
                    "omc_requests": ["OMC-SR-2026-00001"],
                },
            ) as ensure_request,
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        request_kwargs = ensure_request.call_args.kwargs

        self.assertEqual(
            request_kwargs["profile_name"],
            "",
        )
        self.assertEqual(
            request_kwargs["account_name"],
            "",
        )

        self.assertEqual(
            result["historical_services"]["created"],
            1,
        )
        self.assertEqual(
            result["review_reason_counts"],
            {"multiple_customer_profiles": 1},
        )

    def test_service_master_conflict_blocks_request_projection(self):
        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[self._service()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=self._get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "conflict",
                    "service": "",
                    "title": "",
                    "review_reasons": [
                        "multiple_omc_service_mappings",
                    ],
                    "omc_services": [
                        "tax-service-a",
                        "tax-service-b",
                    ],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
            ) as ensure_request,
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        ensure_request.assert_not_called()

        self.assertEqual(
            result["task_types"]["conflicts"],
            1,
        )
        self.assertEqual(
            result["historical_services"]["skipped"],
            1,
        )
        self.assertEqual(
            result["review_reason_counts"],
            {
                "multiple_omc_service_mappings": 1,
            },
        )

class TestHistoricalAmountEvidenceContracts(FrappeTestCase):
    def test_request_payload_never_derives_amount_mismatch(self):
        service = frappe._dict(
            name="SERV-AMOUNT-1",
            customer="ERP-CUST-1",
            service_type="Tax Filing",
            service_amount=12000,
            discount=2000,
            net_service_amount=9000,
            task_created=0,
            task_link="",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )

        mapped_service = frappe._dict(
            name="OMC-SERVICE-TAX",
            title="Tax Filing",
        )

        values = (
            historical_service_migration
            ._historical_request_values(
                service,
                mapped_service,
            )
        )

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertEqual(
            evidence["erp_service"]["service_amount"],
            12000,
        )
        self.assertEqual(
            evidence["erp_service"]["discount"],
            2000,
        )
        self.assertEqual(
            evidence["erp_service"]["net_service_amount"],
            9000,
        )

        self.assertNotIn(
            "amount_consistent",
            evidence,
        )
        self.assertNotIn(
            "historical_amount_mismatch",
            evidence["review_reasons"],
        )

class TestHistoricalCustomerResolutionContracts(FrappeTestCase):
    def test_exact_customer_name_wins_without_normalization(self):
        result = (
            historical_service_migration
            ._resolve_customer_name(
                "Faraz",
                ["Faraz", "Other Customer"],
            )
        )

        self.assertEqual(result["customer"], "Faraz")
        self.assertTrue(result["valid"])
        self.assertFalse(result["normalized"])
        self.assertEqual(result["review_reasons"], [])

    def test_unique_case_only_customer_name_is_canonicalized(self):
        result = (
            historical_service_migration
            ._resolve_customer_name(
                "faraz",
                ["Faraz", "Other Customer"],
            )
        )

        self.assertEqual(result["customer"], "Faraz")
        self.assertTrue(result["valid"])
        self.assertTrue(result["normalized"])
        self.assertEqual(
            result["review_reasons"],
            ["customer_name_case_normalized"],
        )

    def test_missing_customer_name_fails_closed(self):
        result = (
            historical_service_migration
            ._resolve_customer_name(
                "Missing Customer",
                ["Faraz", "Other Customer"],
            )
        )

        self.assertEqual(result["customer"], "")
        self.assertFalse(result["valid"])
        self.assertFalse(result["normalized"])
        self.assertEqual(
            result["review_reasons"],
            ["missing_erp_customer"],
        )

    def test_ambiguous_case_insensitive_customer_match_fails_closed(self):
        result = (
            historical_service_migration
            ._resolve_customer_name(
                "faraz",
                ["Faraz", "FARAZ"],
            )
        )

        self.assertEqual(result["customer"], "")
        self.assertFalse(result["valid"])
        self.assertFalse(result["normalized"])
        self.assertEqual(
            result["review_reasons"],
            ["ambiguous_customer_case_match"],
        )

    def test_request_uses_canonical_customer_but_preserves_raw_evidence(self):
        service = frappe._dict(
            name="SERV-CASE-1",
            customer="faraz",
            service_type="Tax Filing",
            service_amount=12000,
            discount=0,
            net_service_amount=5000,
            task_created=0,
            task_link="",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )

        mapped_service = frappe._dict(
            name="OMC-SERVICE-TAX",
            title="Tax Filing",
        )

        values = (
            historical_service_migration
            ._historical_request_values(
                service,
                mapped_service,
                erp_customer="Faraz",
            )
        )

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertEqual(
            values["erp_customer"],
            "Faraz",
        )
        self.assertEqual(
            evidence["erp_service"]["customer"],
            "faraz",
        )

class TestHistoricalCustomerResolutionWiring(FrappeTestCase):
    def _task_type(self):
        return frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

    def _service(self, **overrides):
        values = {
            "name": "SERV-CASE-1",
            "customer": "faraz",
            "service_type": "Tax Filing",
            "service_amount": 12000,
            "discount": 0,
            "net_service_amount": 5000,
            "task_created": 0,
            "task_link": "",
            "date": "2025-12-01",
            "creation": "2025-12-01 10:00:00",
        }
        values.update(overrides)
        return frappe._dict(values)

    def test_request_task_validation_uses_canonical_customer(self):
        service = self._service(
            task_created=1,
            task_link="TASK-CASE-1",
        )

        task = frappe._dict(
            name="TASK-CASE-1",
            customer="Faraz",
            type="Tax Filing",
            status="Completed",
            custom_operation_status="Completed",
            completed_on="2025-12-15 14:00:00",
            modified="2025-12-15 14:05:00",
        )

        mapped_service = frappe._dict(
            name="OMC-SERVICE-TAX",
            title="Tax Filing Service",
        )

        values = (
            historical_service_migration
            ._historical_request_values(
                service,
                mapped_service,
                task=task,
                erp_customer="Faraz",
            )
        )

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertNotIn(
            "task_customer_mismatch",
            evidence["review_reasons"],
        )
        self.assertEqual(values["erp_customer"], "Faraz")
        self.assertEqual(
            evidence["erp_service"]["customer"],
            "faraz",
        )

    def test_apply_projection_canonicalizes_unique_case_only_customer(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype == "OMC Customer Profile":
                return [
                    frappe._dict(
                        name="OMC-CUST-FARAZ",
                        linked_erpnext_customer="Faraz",
                    )
                ]

            if doctype == "OMC Customer Account":
                return [
                    frappe._dict(
                        name="faraz@example.com",
                        erp_customer="Faraz",
                        legacy_customer_profile="OMC-CUST-FARAZ",
                        identity_proof_status="Verified",
                        account_link_status="Linked",
                        service_access_status="Approved",
                    )
                ]

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "reused",
                    "service": "tax-filing-service",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["tax-filing-service"],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
                return_value={
                    "action": "created",
                    "request": "OMC-SR-CASE-1",
                    "review_reasons": [],
                    "omc_requests": ["OMC-SR-CASE-1"],
                },
            ) as ensure_request,
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        kwargs = ensure_request.call_args.kwargs

        self.assertEqual(
            kwargs["erp_customer"],
            "Faraz",
        )
        self.assertEqual(
            kwargs["profile_name"],
            "OMC-CUST-FARAZ",
        )
        self.assertEqual(
            kwargs["account_name"],
            "faraz@example.com",
        )

        self.assertEqual(
            result["historical_services"]["created"],
            1,
        )
        self.assertEqual(
            result["review_reason_counts"],
            {"customer_name_case_normalized": 1},
        )

    def test_preflight_treats_unique_case_match_as_valid_reviewed_customer(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
                "OMC Service",
                "OMC Service Request",
            ):
                return []

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            result = historical_service_migration.preflight()

        historical = result["historical_services"]

        self.assertEqual(historical["valid_customer"], 1)
        self.assertEqual(historical["missing_customer"], 0)
        self.assertEqual(
            historical["customer_case_normalized"],
            1,
        )
        self.assertEqual(
            historical["safe_projection_candidates"],
            1,
        )
        self.assertEqual(
            result["review_reason_counts"],
            {"customer_name_case_normalized": 1},
        )

    def test_preflight_marks_incompatible_single_projection_as_conflict(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
            ):
                return []

            if doctype == "OMC Service":
                return [
                    frappe._dict(
                        name="tax-filing-service",
                        title="Tax Filing Service",
                        erp_task_type="Tax Filing",
                        is_active=0,
                        company="",
                    )
                ]

            if doctype == "OMC Service Request":
                return [
                    frappe._dict(
                        name="OMC-SR-PREFLIGHT-CONFLICT",
                        service="tax-filing-service",
                        erp_service=service.name,
                        erp_customer="Faraz",
                        erp_task="",
                        source_channel="Imported",
                        request_state="Activated",
                    )
                ]

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            result = historical_service_migration.preflight()

        historical = result["historical_services"]

        self.assertEqual(historical["already_projected"], 0)
        self.assertEqual(historical["projection_conflicts"], 1)
        self.assertEqual(historical["safe_projection_candidates"], 0)
        self.assertEqual(
            result["review_reason_counts"].get(
                "existing_projection_not_historical"
            ),
            1,
        )

    def test_preflight_service_mapping_conflict_is_not_safe_candidate(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
                "OMC Service Request",
            ):
                return []

            if doctype == "OMC Service":
                return [
                    frappe._dict(
                        name="tax-filing-a",
                        title="Tax Filing A",
                        erp_task_type="Tax Filing",
                        is_active=0,
                        company="",
                    ),
                    frappe._dict(
                        name="tax-filing-b",
                        title="Tax Filing B",
                        erp_task_type="Tax Filing",
                        is_active=0,
                        company="",
                    ),
                ]

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            result = historical_service_migration.preflight()

        historical = result["historical_services"]

        self.assertEqual(
            result["task_types"]["mapping_conflicts"],
            1,
        )
        self.assertEqual(
            historical["safe_projection_candidates"],
            0,
        )
        self.assertEqual(
            result["review_reason_counts"].get(
                "multiple_omc_service_mappings"
            ),
            1,
        )


    def test_preflight_account_available_requires_same_safe_account_contract(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype == "OMC Customer Profile":
                return [
                    frappe._dict(
                        name="OMC-CUST-FARAZ",
                        linked_erpnext_customer="Faraz",
                    )
                ]

            if doctype == "OMC Customer Account":
                return [
                    frappe._dict(
                        name="faraz@example.com",
                        erp_customer="Faraz",
                        legacy_customer_profile="OMC-CUST-OTHER",
                        identity_proof_status="Verified",
                        account_link_status="Linked",
                        service_access_status="Approved",
                    )
                ]

            if doctype in (
                "OMC Service",
                "OMC Service Request",
            ):
                return []

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            result = historical_service_migration.preflight()

        self.assertEqual(
            result["historical_services"]["profile_available"],
            1,
        )
        self.assertEqual(
            result["historical_services"]["account_available"],
            0,
        )


class TestHistoricalPersistedReviewReasonWiring(FrappeTestCase):
    def _task_type(self):
        return frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

    def _service(self):
        return frappe._dict(
            name="SERV-REASON-1",
            customer="faraz",
            service_type="Tax Filing",
            service_amount=12000,
            discount=0,
            net_service_amount=5000,
            task_created=0,
            task_link="",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )

    def test_request_payload_persists_external_review_reason(self):
        values = (
            historical_service_migration
            ._historical_request_values(
                self._service(),
                frappe._dict(
                    name="OMC-SERVICE-TAX",
                    title="Tax Filing Service",
                ),
                erp_customer="Faraz",
                review_reasons=[
                    "customer_name_case_normalized"
                ],
            )
        )

        evidence = json.loads(
            values["historical_evidence_json"]
        )

        self.assertEqual(
            evidence["review_reasons"],
            ["customer_name_case_normalized"],
        )

    def test_apply_projection_forwards_customer_resolution_reason(self):
        service = self._service()

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["Faraz"]

            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
            ):
                return []

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[self._task_type()],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[service],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "reused",
                    "service": "OMC-SERVICE-TAX",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["OMC-SERVICE-TAX"],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
                return_value={
                    "action": "created",
                    "request": "OMC-SR-REASON-1",
                    "review_reasons": [],
                    "omc_requests": ["OMC-SR-REASON-1"],
                },
            ) as ensure_request,
        ):
            historical_service_migration._apply_projection()

        self.assertEqual(
            ensure_request.call_args.kwargs["review_reasons"],
            ["customer_name_case_normalized"],
        )

class TestHistoricalRequestReuseSafetyContracts(FrappeTestCase):
    def _service(self):
        return frappe._dict(
            name="SERV-SAFE-REUSE-1",
            customer="ERP-CUST-1",
            service_type="Tax Filing",
            service_amount=12000,
            discount=0,
            net_service_amount=5000,
            task_created=0,
            task_link="",
            date="2025-12-01",
            creation="2025-12-01 10:00:00",
        )

    def _mapped_service(self):
        return frappe._dict(
            name="OMC-SERVICE-TAX",
            title="Tax Filing Service",
            erp_task_type="Tax Filing",
            is_active=0,
        )

    def _existing(self, **overrides):
        values = {
            "name": "OMC-SR-SAFE-1",
            "service": "OMC-SERVICE-TAX",
            "erp_service": "SERV-SAFE-REUSE-1",
            "erp_customer": "ERP-CUST-1",
            "erp_task": "",
            "source_channel": "Imported",
            "request_state": "Historical",
            "historical_evidence_json": "{}",
        }
        values.update(overrides)
        return frappe._dict(values)

    def _payload(self, evidence_json):
        return {
            "doctype": "OMC Service Request",
            "service": "OMC-SERVICE-TAX",
            "service_title": "Tax Filing Service",
            "title": "Tax Filing Service",
            "status": "Historical",
            "request_state": "Historical",
            "customer_profile": "",
            "customer_account": "",
            "requested_by": "",
            "company_snapshot": "",
            "source_channel": "Imported",
            "submission_mode": "Historical Import",
            "erp_customer": "ERP-CUST-1",
            "erp_service": "SERV-SAFE-REUSE-1",
            "erp_task": "",
            "erp_sync_status": "Historical",
            "closed_on": None,
            "historical_evidence_json": evidence_json,
        }

    def test_compatible_existing_projection_repairs_only_stale_evidence(self):
        expected_evidence = (
            '{"review_reasons":["customer_name_case_normalized"]}'
        )

        with (
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                return_value=[self._existing()],
            ),
            patch.object(
                historical_service_migration,
                "_historical_request_values",
                return_value=self._payload(expected_evidence),
            ),
            patch.object(
                historical_service_migration.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                historical_service_migration.frappe,
                "get_doc",
            ) as get_doc,
        ):
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                    review_reasons=[
                        "customer_name_case_normalized"
                    ],
                )
            )

        self.assertEqual(result["action"], "reused")
        self.assertTrue(result["changed"])
        self.assertEqual(
            result["repaired_fields"],
            ["historical_evidence_json"],
        )

        set_value.assert_called_once_with(
            "OMC Service Request",
            "OMC-SR-SAFE-1",
            "historical_evidence_json",
            expected_evidence,
            update_modified=False,
        )
        get_doc.assert_not_called()

    def test_compatible_existing_projection_with_current_evidence_is_noop(self):
        expected_evidence = (
            '{"review_reasons":["customer_name_case_normalized"]}'
        )

        existing = self._existing(
            historical_evidence_json=expected_evidence,
        )

        with (
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                return_value=[existing],
            ),
            patch.object(
                historical_service_migration,
                "_historical_request_values",
                return_value=self._payload(expected_evidence),
            ),
            patch.object(
                historical_service_migration.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                historical_service_migration.frappe,
                "get_doc",
            ) as get_doc,
        ):
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                    review_reasons=[
                        "customer_name_case_normalized"
                    ],
                )
            )

        self.assertEqual(result["action"], "reused")
        self.assertFalse(result["changed"])
        self.assertEqual(result["repaired_fields"], [])
        set_value.assert_not_called()
        get_doc.assert_not_called()

    def test_existing_projection_with_wrong_service_fails_closed(self):
        existing = self._existing(
            service="OMC-SERVICE-WRONG",
        )

        with (
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                return_value=[existing],
            ),
            patch.object(
                historical_service_migration,
                "_historical_request_values",
                return_value=self._payload("{}"),
            ) as values_builder,
            patch.object(
                historical_service_migration.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                historical_service_migration.frappe,
                "get_doc",
            ) as get_doc,
        ):
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertIn(
            "existing_projection_service_mismatch",
            result["review_reasons"],
        )
        values_builder.assert_not_called()
        set_value.assert_not_called()
        get_doc.assert_not_called()

    def test_existing_projection_with_wrong_customer_fails_closed(self):
        existing = self._existing(
            erp_customer="OTHER-CUSTOMER",
        )

        with (
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                return_value=[existing],
            ),
            patch.object(
                historical_service_migration.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                historical_service_migration.frappe,
                "get_doc",
            ) as get_doc,
        ):
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertIn(
            "existing_projection_customer_mismatch",
            result["review_reasons"],
        )
        set_value.assert_not_called()
        get_doc.assert_not_called()

    def test_existing_non_historical_projection_fails_closed(self):
        existing = self._existing(
            request_state="Submitted",
        )

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=[existing],
        ), patch.object(
            historical_service_migration.frappe.db,
            "set_value",
        ) as set_value:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertIn(
            "existing_projection_not_historical",
            result["review_reasons"],
        )
        set_value.assert_not_called()

    def test_existing_non_imported_projection_fails_closed(self):
        existing = self._existing(
            source_channel="App",
        )

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=[existing],
        ), patch.object(
            historical_service_migration.frappe.db,
            "set_value",
        ) as set_value:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertIn(
            "existing_projection_not_imported",
            result["review_reasons"],
        )
        set_value.assert_not_called()

    def test_existing_projection_with_wrong_task_fails_closed(self):
        existing = self._existing(
            erp_task="TASK-WRONG",
        )

        with patch.object(
            historical_service_migration.frappe,
            "get_all",
            return_value=[existing],
        ), patch.object(
            historical_service_migration.frappe.db,
            "set_value",
        ) as set_value:
            result = (
                historical_service_migration
                ._ensure_historical_request(
                    self._service(),
                    self._mapped_service(),
                    erp_customer="ERP-CUST-1",
                )
            )

        self.assertEqual(result["action"], "conflict")
        self.assertIn(
            "existing_projection_task_mismatch",
            result["review_reasons"],
        )
        set_value.assert_not_called()

    def test_apply_projection_marks_evidence_repair_as_changed(self):
        task_type = frappe._dict(
            name="Tax Filing",
            service_name="Tax Filing Service",
            rate=15000,
            days=7,
            description="Legacy tax filing service.",
        )

        def get_all(doctype, **kwargs):
            if doctype == "Customer":
                return ["ERP-CUST-1"]

            if doctype in (
                "OMC Customer Profile",
                "OMC Customer Account",
            ):
                return []

            raise AssertionError(
                f"Unexpected get_all doctype: {doctype}"
            )

        with (
            patch.object(
                historical_service_migration,
                "_load_task_types",
                return_value=[task_type],
            ),
            patch.object(
                historical_service_migration,
                "_load_services",
                return_value=[self._service()],
            ),
            patch.object(
                historical_service_migration,
                "_load_tasks",
                return_value={},
            ),
            patch.object(
                historical_service_migration.frappe,
                "get_all",
                side_effect=get_all,
            ),
            patch.object(
                historical_service_migration,
                "_ensure_service_master",
                return_value={
                    "action": "reused",
                    "service": "OMC-SERVICE-TAX",
                    "title": "Tax Filing Service",
                    "review_reasons": [],
                    "omc_services": ["OMC-SERVICE-TAX"],
                },
            ),
            patch.object(
                historical_service_migration,
                "_ensure_historical_request",
                return_value={
                    "action": "reused",
                    "request": "OMC-SR-SAFE-1",
                    "review_reasons": [],
                    "omc_requests": ["OMC-SR-SAFE-1"],
                    "changed": True,
                    "repaired_fields": [
                        "historical_evidence_json"
                    ],
                },
            ),
        ):
            result = (
                historical_service_migration
                ._apply_projection()
            )

        self.assertEqual(
            result["historical_services"]["reused"],
            1,
        )
        self.assertTrue(result["changed"])

