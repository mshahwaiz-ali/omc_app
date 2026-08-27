from datetime import datetime, timedelta
from pathlib import Path
import re
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

import frappe

from omc_app import hooks
from omc_app.api import (
    accounting_reconciliation,
    bridge_outbox,
    capabilities,
    commission_projection,
    cors,
    overlay_reconciliation,
    profile_self_service,
    redesign_migration,
    security,
    upload_validation,
)


class _Cache:
    def __init__(self):
        self.values = {}

    def incr(self, key):
        self.values[key] = self.values.get(key, 0) + 1
        return self.values[key]

    def expire(self, key, seconds):
        return None

    def delete(self, key):
        self.values.pop(key, None)


class TestBackendRedesignSecurity(TestCase):
    def test_system_manager_has_no_implicit_omc_capability(self):
        with (
            patch.object(capabilities.identity, "user_is_enabled", return_value=True),
            patch.object(capabilities.identity, "get_staff_access", return_value=None),
            patch.object(capabilities.identity, "get_customer_account", return_value=None),
        ):
            values = capabilities.effective("system-manager@example.com")

        self.assertEqual(values["access_state"], "pending")
        self.assertFalse(values["can_access_internal_workspace"])
        self.assertFalse(values["can_manage_staff"])

    def test_only_explicit_staff_access_capabilities_are_enabled(self):
        staff = SimpleNamespace(
            access_status="Approved",
            reconciliation_status="Current",
            capabilities=[SimpleNamespace(capability="can_review_payments")],
        )
        with (
            patch.object(capabilities.identity, "user_is_enabled", return_value=True),
            patch.object(capabilities.identity, "get_staff_access", return_value=staff),
            patch.object(capabilities, "_active_break_glass", return_value=set()),
        ):
            values = capabilities.effective("finance@example.com")

        self.assertTrue(values["can_review_payments"])
        self.assertTrue(values["can_access_internal_workspace"])
        self.assertFalse(values["can_manage_staff"])

    def test_expired_and_wrong_scope_break_glass_grants_are_ignored(self):
        now = datetime(2026, 8, 19, 12, 0, 0)
        rows = [
            frappe._dict(
                capability="can_manage_staff", expires_at=now - timedelta(seconds=1),
                scope_doctype="", scope_name="",
            ),
            frappe._dict(
                capability="can_retry_sync", expires_at=now + timedelta(hours=1),
                scope_doctype="OMC Service Request", scope_name="OMC-SR-OTHER",
            ),
            frappe._dict(
                capability="can_review_payments", expires_at=now + timedelta(hours=1),
                scope_doctype="OMC Service Request", scope_name="OMC-SR-1",
            ),
        ]
        with (
            patch.object(capabilities.frappe.db, "exists", return_value=True),
            patch.object(capabilities.frappe, "get_all", return_value=rows),
            patch.object(capabilities, "now_datetime", return_value=now),
        ):
            result = capabilities._active_break_glass(
                "reviewer@example.com",
                scope_doctype="OMC Service Request",
                scope_name="OMC-SR-1",
            )

        self.assertEqual(result, {"can_review_payments"})

    def test_rate_limit_uses_hashed_actor_and_blocks_replay_burst(self):
        cache = _Cache()
        fixed = datetime(2026, 8, 19, 12, 0, 0)
        with (
            patch.object(security.frappe, "cache", return_value=cache),
            patch.object(security, "now_datetime", return_value=fixed),
            patch.object(security, "_request_ip", return_value="127.0.0.1"),
            patch.object(security, "audit_event"),
        ):
            security.enforce_rate_limit("signup", actor="private@example.com", limit=2)
            security.enforce_rate_limit("signup", actor="private@example.com", limit=2)
            with self.assertRaises(frappe.ValidationError):
                security.enforce_rate_limit("signup", actor="private@example.com", limit=2)

        self.assertTrue(cache.values)
        self.assertTrue(all("private@example.com" not in key for key in cache.values))

    def test_successful_operation_clears_only_the_actor_rate_limit(self):
        cache = _Cache()
        fixed = datetime(2026, 8, 19, 12, 0, 0)
        with (
            patch.object(security.frappe, "cache", return_value=cache),
            patch.object(security, "now_datetime", return_value=fixed),
            patch.object(security, "_request_ip", return_value="127.0.0.1"),
        ):
            security.enforce_rate_limit("login", actor="person@example.com")
            security.clear_actor_rate_limit("login", actor="person@example.com")

        self.assertEqual(len(cache.values), 1)
        self.assertIn(":ip:", next(iter(cache.values)))

    def test_profile_mass_assignment_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            profile_self_service._clean_payload({"full_name": "Ayesha", "is_active": 1})

    def test_cors_is_exact_allowlist_and_never_wildcard(self):
        allowed = SimpleNamespace(headers={})
        denied = SimpleNamespace(headers={})
        with (
            patch.object(cors, "_allowed_origins", return_value={"https://app.omc.test"}),
            patch.object(cors.frappe, "get_request_header", return_value="https://app.omc.test"),
        ):
            cors.add_cors_headers(allowed)
        with (
            patch.object(cors, "_allowed_origins", return_value={"https://app.omc.test"}),
            patch.object(cors.frappe, "get_request_header", return_value="https://evil.test"),
        ):
            cors.add_cors_headers(denied)

        self.assertEqual(allowed.headers["Access-Control-Allow-Origin"], "https://app.omc.test")
        self.assertNotIn("Access-Control-Allow-Origin", denied.headers)

    def test_sensitive_mutations_are_post_only_for_native_csrf(self):
        routes = (
            "omc_app.api.signup_policy.sign_up",
            "omc_app.api.pending_registration.start_registration",
            "omc_app.api.pending_registration.resend_verification",
            "omc_app.api.customer_activation.request_activation",
            "omc_app.api.customer_activation.complete_activation",
            "omc_app.api.password_reset.request_reset",
            "omc_app.api.password_reset.reset_password",
            "omc_app.api.auth_login.login",
            "omc_app.api.service_request_guard.create_service",
            "omc_app.api.document_upload.upload_service_document",
            "omc_app.api.payment_mutation_guard.upload_payment_receipt_file",
            "omc_app.api.payment_mutation_guard.review_payment_receipt",
            "omc_app.api.support_chat.create_support_ticket",
            "omc_app.api.support_chat.add_support_ticket_reply",
            "omc_app.api.admin_control.review_registration",
            "omc_app.api.admin_control.update_staff_account",
        )
        for route in routes:
            function = frappe.get_attr(route)
            self.assertEqual(
                frappe.allowed_http_methods_for_whitelisted_func.get(function),
                ["POST"],
                route,
            )


class TestBackendRedesignFinance(TestCase):
    def test_reconciliation_projects_state_to_base_and_allocation_evidence(self):
        with (
            patch.object(
                accounting_reconciliation.frappe,
                "get_all",
                return_value=["BASE-LINK", "ALLOCATION-LINK"],
            ),
            patch.object(
                accounting_reconciliation.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                accounting_reconciliation,
                "now_datetime",
                return_value="2026-08-27 14:00:00",
            ),
        ):
            accounting_reconciliation._project_link_state(
                "OMC-SR-1",
                "Settled",
            )

        self.assertEqual(set_value.call_count, 2)
        for link_name in ("BASE-LINK", "ALLOCATION-LINK"):
            set_value.assert_any_call(
                "OMC Accounting Link",
                link_name,
                {
                    "accounting_status": "Settled",
                    "reconciled_at": "2026-08-27 14:00:00",
                    "reconciliation_error": "",
                },
                update_modified=False,
            )

    def test_settlement_matrix_caps_overpayment_and_supports_multiple_allocations(self):
        cases = (
            ({"required": 100, "invoice_basis": 100, "allocated": 40}, ("Partially Settled", 40)),
            ({"required": 100, "invoice_basis": 100, "allocated": 100}, ("Settled", 100)),
            ({"required": 100, "invoice_basis": 100, "allocated": 160}, ("Settled", 100)),
            ({"required": 100, "invoice_basis": 150, "allocated": 60 + 40}, ("Settled", 100)),
            ({"required": 100, "invoice_basis": 100, "allocated": 0, "reversed_exists": True}, ("Reversed", 0)),
            ({"required": 100, "invoice_basis": 100, "allocated": 100, "invalid_reason": "return"}, ("Review Required", 100)),
        )
        for arguments, expected in cases:
            with self.subTest(arguments=arguments):
                self.assertEqual(
                    accounting_reconciliation.settlement_state(**arguments),
                    expected,
                )

    def test_payment_allocation_validates_party_company_currency_and_reference(self):
        request = frappe._dict(
            doctype="OMC Service Request",
            name="OMC-SR-1",
            modified="2026-08-19 12:00:00",
            erp_customer="CUST-1",
            company_snapshot="OMC",
        )
        invoice = frappe._dict(name="SINV-1", company="OMC", currency="PKR")
        payment = frappe._dict(
            name="PAY-1",
            modified="2026-08-19 12:00:00",
            docstatus=1,
            payment_type="Receive",
            party_type="Customer",
            party="CUST-1",
            company="OMC",
            paid_from_account_currency="PKR",
        )
        reference = frappe._dict(name="REF-1", allocated_amount=100)

        self.assertIsNone(
            accounting_reconciliation._payment_allocation_issue(
                request, invoice, payment, reference
            )
        )
        payment.party = "CUST-OTHER"
        issue = accounting_reconciliation._payment_allocation_issue(
            request, invoice, payment, reference
        )
        self.assertEqual(issue["kind"], "human")
        self.assertEqual(issue["code"], "payment_party_mismatch")

    def test_no_charge_and_full_settlement_activation_gates(self):
        free = SimpleNamespace(
            name="OMC-SR-FREE", request_state="Payment Not Required",
            payment_policy_snapshot="No Charge", payable_amount=0,
        )
        paid = SimpleNamespace(
            name="OMC-SR-PAID", request_state="Pending Payment",
            payment_policy_snapshot="Full Settlement", payable_amount=100,
        )
        self.assertTrue(bridge_outbox.eligibility(free)["eligible"])
        with patch.object(bridge_outbox.frappe.db, "exists", return_value=False):
            self.assertFalse(bridge_outbox.eligibility(paid)["eligible"])
        with patch.object(bridge_outbox.frappe.db, "exists", return_value=True):
            self.assertTrue(bridge_outbox.eligibility(paid)["eligible"])

    def test_bridge_failure_rolls_back_partial_operational_graph(self):
        source = Path(bridge_outbox.__file__).read_text(encoding="utf-8")
        self.assertIn("frappe.db.savepoint(bridge_savepoint)", source)
        self.assertIn("frappe.db.rollback(save_point=bridge_savepoint)", source)

    def test_bridge_audit_uses_a_valid_session_user(self):
        source = Path(bridge_outbox.__file__).read_text(encoding="utf-8")
        self.assertNotIn('actor="bridge"', source)
        self.assertIn("actor=frappe.session.user", source)
        self.assertNotIn("frappe.db.commit()", source)

    def test_commission_rounding_is_decimal_half_up(self):
        self.assertEqual(commission_projection._money("10.005"), commission_projection.Decimal("10.01"))

    def test_omc_commission_projection_has_no_journal_entry_writer(self):
        source = Path(commission_projection.__file__).read_text(encoding="utf-8")
        self.assertNotIn('frappe.new_doc("Journal Entry")', source)
        self.assertNotIn('frappe.get_doc({"doctype": "Journal Entry"', source)

    def test_mixed_omc_and_unrelated_commission_references_are_rejected(self):
        payment = SimpleNamespace(
            custom_structure_name="OMC Structure",
            references=[
                SimpleNamespace(
                    reference_doctype="Sales Invoice", reference_name="INV-OMC"
                ),
                SimpleNamespace(
                    reference_doctype="Sales Invoice", reference_name="INV-OTHER"
                ),
            ],
            flags=SimpleNamespace(),
        )
        with (
            patch.object(
                commission_projection.frappe,
                "get_all",
                return_value=["INV-OMC"],
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            commission_projection.suppress_legacy_commission_writer(payment)


class TestBackendRedesignMigration(TestCase):
    def test_overlay_preview_queries_only_the_requested_batch(self):
        profile = frappe._dict(name="PROFILE-2", modified="2026-08-19")
        with (
            patch.object(overlay_reconciliation.frappe.db, "count", return_value=3),
            patch.object(
                overlay_reconciliation.frappe,
                "get_all",
                return_value=["PROFILE-2"],
            ) as get_all,
            patch.object(
                overlay_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                overlay_reconciliation,
                "_customer_decision",
                return_value={"action": "review", "reason": "ambiguous"},
            ),
        ):
            result = overlay_reconciliation.run(
                domain="customer", mode="preview", cursor=1, limit=1
            )

        get_all.assert_called_once_with(
            "OMC Customer Profile",
            pluck="name",
            order_by="name asc",
            limit_start=1,
            limit_page_length=1,
        )
        self.assertEqual(result["total"], 3)
        self.assertTrue(result["has_more"])
        self.assertNotIn("PROFILE-2", str(result["items"]))

    def test_commercial_preview_queries_only_the_requested_batch(self):
        with (
            patch.object(redesign_migration.frappe.db, "count", return_value=4),
            patch.object(
                redesign_migration.frappe,
                "get_all",
                return_value=[],
            ) as get_all,
        ):
            result = redesign_migration.commercial_policy(
                mode="preview", cursor=2, limit=2
            )

        get_all.assert_called_once_with(
            "OMC Service",
            pluck="name",
            order_by="name asc",
            limit_start=2,
            limit_page_length=2,
        )
        self.assertEqual(result["total"], 4)
        self.assertTrue(result["has_more"])


class TestFlutterRouteContracts(TestCase):
    def test_all_115_api_config_methods_and_home_route_resolve(self):
        repo_root = Path(__file__).resolve().parents[6]
        config = (
            repo_root / "omc_app/lib/core/config/api_config.dart"
        ).read_text(encoding="utf-8")
        routes = sorted(set(re.findall(r"omc_app\.[A-Za-z0-9_.]+", config)))
        self.assertEqual(len(routes), 115)

        for route in routes:
            with self.subTest(route=route):
                self.assertTrue(callable(frappe.get_attr(route)))

        self.assertTrue(
            callable(frappe.get_attr("omc_app.api.home_content.get_home_content"))
        )

    def test_all_override_targets_resolve(self):
        for route, target in hooks.override_whitelisted_methods.items():
            with self.subTest(route=route, target=target):
                self.assertTrue(callable(frappe.get_attr(route)))
                self.assertTrue(callable(frappe.get_attr(target)))

    def test_seven_previously_missing_routes_resolve(self):
        routes = (
            "omc_app.api.home_content.get_home_content",
            "omc_app.api.payment_read_guard.download_invoice_pdf",
            "omc_app.api.profile_self_service.update_work_address",
            "omc_app.api.profile_self_service.dismiss_work_address_prompt",
            "omc_app.api.referral_commissions.get_my_commission_summary",
            "omc_app.api.referral_commissions.get_my_commissions",
            "omc_app.api.referral_commissions.get_my_commission",
        )
        self.assertTrue(all(callable(frappe.get_attr(route)) for route in routes))
