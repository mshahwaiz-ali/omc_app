from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_reconciliation


class TestCustomerReconciliation(FrappeTestCase):
    def _profile(self, **overrides):
        values = {
            "name": "OMC-CUST-TEST-1",
            "user": "customer@example.com",
            "linked_app_user": "",
            "email": "customer@example.com",
            "phone": "+923001234567",
            "cnic": "3520212345671",
            "ntn": "",
            "customer_status": "Active",
            "approval_status": "Approved",
            "is_active": 1,
            "linked_erpnext_customer": "",
            "modified": "2026-08-20 01:00:00",
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def _account(self, **overrides):
        values = {
            "erp_customer": "ERP-CUST-1",
            "legacy_customer_profile": "OMC-CUST-TEST-1",
            "identity_proof_status": "Verified",
            "account_link_status": "Linked",
            "service_access_status": "Approved",
            "mapping_provenance": "Deterministic Legacy Link",
            "mapping_confidence": "Exact Link",
            "source_version": "source-v1",
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_profile_user_prefers_linked_app_user(self):
        profile = self._profile(
            user="legacy@example.com",
            linked_app_user="linked@example.com",
        )

        with patch.object(
            customer_reconciliation.frappe.db,
            "exists",
            return_value=True,
        ):
            user = customer_reconciliation._profile_user(profile)

        self.assertEqual(user, "linked@example.com")

    def test_source_version_tracks_reconciliation_identity_fields(self):
        before = self._profile(linked_app_user="")
        after = self._profile(linked_app_user="linked@example.com")

        self.assertNotEqual(
            customer_reconciliation._source_version(before),
            customer_reconciliation._source_version(after),
        )

    def test_missing_erp_customer_opens_review_without_account_creation(self):
        profile = self._profile()

        with (
            patch.object(
                customer_reconciliation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_reconciliation.identity,
                "get_customer_account",
                return_value=None,
            ),
            patch.object(
                customer_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_reconciliation.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Pending Configuration",
                    "customer": "",
                    "created": False,
                    "reason": "no ERP Customer is linked to this profile",
                },
            ),
            patch.object(
                customer_reconciliation.identity,
                "ensure_customer_account_from_legacy",
            ) as ensure_account,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "open_human_review",
            ) as open_review,
        ):
            result = customer_reconciliation._reconcile_profile(
                profile,
                run_id="RUN-1",
            )

        self.assertEqual(result["review"], 1)
        self.assertEqual(result["changed"], 0)
        ensure_account.assert_not_called()
        self.assertEqual(
            open_review.call_args.kwargs["reason_code"],
            "erp_customer_missing",
        )

    def test_ambiguous_erp_customer_opens_review(self):
        profile = self._profile()

        with (
            patch.object(
                customer_reconciliation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_reconciliation.identity,
                "get_customer_account",
                return_value=None,
            ),
            patch.object(
                customer_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_reconciliation.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Ambiguous",
                    "customer": "",
                    "created": False,
                    "reason": "multiple ERP Customers match",
                },
            ),
            patch.object(
                customer_reconciliation.identity,
                "ensure_customer_account_from_legacy",
            ) as ensure_account,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "open_human_review",
            ) as open_review,
        ):
            result = customer_reconciliation._reconcile_profile(
                profile,
                run_id="RUN-2",
            )

        self.assertEqual(result["review"], 1)
        ensure_account.assert_not_called()
        self.assertEqual(
            open_review.call_args.kwargs["reason_code"],
            "erp_customer_ambiguous",
        )

    def test_unique_erp_customer_creates_canonical_account(self):
        profile = self._profile()
        account = self._account()

        with (
            patch.object(
                customer_reconciliation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_reconciliation.identity,
                "get_customer_account",
                side_effect=[None, None, account],
            ),
            patch.object(
                customer_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_reconciliation.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Resolved",
                    "customer": "ERP-CUST-1",
                    "created": False,
                    "reason": "",
                },
            ),
            patch.object(
                customer_reconciliation.identity,
                "ensure_customer_account_from_legacy",
                return_value=account,
            ) as ensure_account,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "resolve_source_queues",
            ) as resolve_queues,
        ):
            result = customer_reconciliation._reconcile_profile(
                profile,
                run_id="RUN-3",
            )

        self.assertEqual(result["changed"], 1)
        self.assertEqual(result["review"], 0)
        ensure_account.assert_called_once_with("customer@example.com")
        resolve_queues.assert_called_once()

    def test_existing_canonical_conflict_is_not_overwritten(self):
        profile = self._profile()
        account = self._account(erp_customer="ERP-CUST-OTHER")

        with (
            patch.object(
                customer_reconciliation.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_reconciliation.identity,
                "get_customer_account",
                side_effect=[account, account],
            ),
            patch.object(
                customer_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_reconciliation.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Resolved",
                    "customer": "ERP-CUST-1",
                    "created": False,
                    "reason": "",
                },
            ),
            patch.object(
                customer_reconciliation.identity,
                "ensure_customer_account_from_legacy",
            ) as ensure_account,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "open_human_review",
            ) as open_review,
        ):
            result = customer_reconciliation._reconcile_profile(
                profile,
                run_id="RUN-4",
            )

        self.assertEqual(result["review"], 1)
        ensure_account.assert_not_called()
        self.assertEqual(
            open_review.call_args.kwargs["reason_code"],
            "canonical_account_conflict",
        )
        self.assertEqual(
            open_review.call_args.kwargs["safe_evidence"]["conflict_kind"],
            "erp_customer_mismatch",
        )


class TestBusinessOnlyCustomerReconciliation(FrappeTestCase):
    def _profile(self, **overrides):
        values = {
            "name": "OMC-CUST-BUSINESS-ONLY",
            "user": "",
            "linked_app_user": "",
            "email": "business@example.com",
            "phone": "",
            "cnic": "",
            "ntn": "",
            "customer_status": "Active",
            "approval_status": "Approved",
            "is_active": 1,
            "linked_erpnext_customer": "ERP-CUST-1",
            "modified": "2026-09-18 12:00:00",
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_email_alone_is_not_app_activation_identity(self):
        profile = self._profile()

        with patch.object(
            customer_reconciliation.frappe.db,
            "exists",
            return_value=True,
        ):
            self.assertEqual(
                customer_reconciliation._profile_user(profile),
                "",
            )

    def test_business_only_profile_needs_no_customer_account(self):
        profile = self._profile()

        with (
            patch.object(
                customer_reconciliation.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_reconciliation.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Resolved",
                    "customer": "ERP-CUST-1",
                    "created": False,
                    "reason": "",
                },
            ),
            patch.object(
                customer_reconciliation.identity,
                "get_customer_account",
            ) as get_account,
            patch.object(
                customer_reconciliation.identity,
                "ensure_customer_account_from_legacy",
            ) as ensure_account,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "open_technical_quarantine",
            ) as quarantine,
            patch.object(
                customer_reconciliation.reconciliation_queues,
                "resolve_source_queues",
            ) as resolve_queues,
        ):
            result = customer_reconciliation._reconcile_profile(
                profile,
                run_id="RUN-BUSINESS-ONLY",
            )

        self.assertEqual(result["changed"], 0)
        self.assertEqual(result["review"], 0)
        self.assertEqual(result["quarantine"], 0)
        get_account.assert_not_called()
        ensure_account.assert_not_called()
        quarantine.assert_not_called()
        resolve_queues.assert_called_once()


class TestCustomerReconciliationLock(FrappeTestCase):
    def test_busy_reconciliation_skips_worker(self):
        with (
            patch.object(
                customer_reconciliation.reconciliation_runs,
                "acquire_job_lock",
                return_value=False,
            ) as acquire,
            patch.object(
                customer_reconciliation,
                "_run_customer_account_reconciliation_unlocked",
            ) as worker,
            patch.object(
                customer_reconciliation.reconciliation_runs,
                "release_job_lock",
            ) as release,
        ):
            result = (
                customer_reconciliation
                .run_customer_account_reconciliation(
                    batch_size=500,
                    lock_timeout=30,
                )
            )

        self.assertEqual(
            result["status"],
            "SkippedLocked",
        )
        self.assertEqual(
            result["safe_error_code"],
            "reconciliation_already_running",
        )
        worker.assert_not_called()
        release.assert_not_called()

        acquire.assert_called_once_with(
            job_key=customer_reconciliation.JOB_KEY,
            domain=customer_reconciliation.DOMAIN,
            timeout=30,
        )

    def test_reconciliation_lock_released_on_worker_failure(self):
        with (
            patch.object(
                customer_reconciliation.reconciliation_runs,
                "acquire_job_lock",
                return_value=True,
            ),
            patch.object(
                customer_reconciliation,
                "_run_customer_account_reconciliation_unlocked",
                side_effect=RuntimeError("test failure"),
            ),
            patch.object(
                customer_reconciliation.reconciliation_runs,
                "release_job_lock",
            ) as release,
        ):
            with self.assertRaises(RuntimeError):
                (
                    customer_reconciliation
                    .run_customer_account_reconciliation(
                        batch_size=500,
                    )
                )

        release.assert_called_once_with(
            job_key=customer_reconciliation.JOB_KEY,
            domain=customer_reconciliation.DOMAIN,
        )
