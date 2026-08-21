from collections import Counter
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_migration


class TestCustomerMigrationTaxFallback(FrappeTestCase):
    def _row(
        self,
        customer,
        *,
        email="",
        cnic="",
        phone="",
        tax_id="",
        phone_conflict=False,
        classification=None,
        review_reason="",
    ):
        row = {
            "customer": customer,
            "customer_name": customer,
            "lead": "",
            "email": email,
            "cnic": cnic,
            "customer_phone": phone,
            "lead_phone": "",
            "resolved_phone": phone,
            "phone_source": "customer" if phone else "",
            "phone_conflict": phone_conflict,
            "tax_id": tax_id,
        }

        if classification is not None:
            row["classification"] = classification
            row["review_reason"] = review_reason

        return row

    def test_normalise_tax_id_accepts_supported_numeric_shapes(self):
        self.assertEqual(
            customer_migration._normalise_tax_id(
                "35202-1234567-1"
            ),
            "3520212345671",
        )
        self.assertEqual(
            customer_migration._normalise_tax_id(
                "35202 1234567 1"
            ),
            "3520212345671",
        )
        self.assertEqual(
            customer_migration._normalise_tax_id("1234567"),
            "1234567",
        )
        self.assertEqual(
            customer_migration._normalise_tax_id("123-4567"),
            "1234567",
        )

    def test_normalise_tax_id_rejects_legacy_and_invalid_shapes(self):
        for value in (
            "G123456",
            "I123456",
            "H123456",
            "J123456",
            "ABC1234567",
            "123456",
            "12345678",
            "",
            None,
        ):
            self.assertEqual(
                customer_migration._normalise_tax_id(value),
                "",
            )

    def test_unique_tax_id_is_last_safe_identity_fallback(self):
        rows = [
            self._row(
                "ERP-CUST-1",
                tax_id="3520212345671",
            ),
            self._row(
                "ERP-CUST-2",
                tax_id="1234567",
            ),
        ]

        with patch.object(
            customer_migration,
            "_identity_rows",
            return_value=rows,
        ):
            classified, _, _, _ = customer_migration._classify()

        self.assertEqual(
            classified[0]["classification"],
            "unique_tax_id",
        )
        self.assertEqual(
            classified[1]["classification"],
            "unique_tax_id",
        )

    def test_duplicate_tax_id_is_never_auto_migrated(self):
        rows = [
            self._row(
                "ERP-CUST-1",
                tax_id="3520212345671",
            ),
            self._row(
                "ERP-CUST-2",
                tax_id="3520212345671",
            ),
        ]

        with patch.object(
            customer_migration,
            "_identity_rows",
            return_value=rows,
        ):
            classified, _, _, _ = customer_migration._classify()

        for row in classified:
            self.assertEqual(
                row["classification"],
                "identity_review",
            )
            self.assertIn(
                "duplicate_tax_id",
                row["review_reason"],
            )

    def test_existing_identity_priority_remains_unchanged(self):
        rows = [
            self._row(
                "ERP-EMAIL",
                email="email@example.com",
                tax_id="1111111111111",
            ),
            self._row(
                "ERP-CNIC",
                cnic="2222222222222",
                phone="+923001111111",
                tax_id="2222222",
            ),
            self._row(
                "ERP-PHONE",
                phone="+923002222222",
                tax_id="3333333",
            ),
            self._row(
                "ERP-TAX",
                tax_id="4444444",
            ),
        ]

        with patch.object(
            customer_migration,
            "_identity_rows",
            return_value=rows,
        ):
            classified, _, _, _ = customer_migration._classify()

        by_customer = {
            row["customer"]: row["classification"]
            for row in classified
        }

        self.assertEqual(
            by_customer["ERP-EMAIL"],
            "unique_email",
        )
        self.assertEqual(
            by_customer["ERP-CNIC"],
            "unique_cnic",
        )
        self.assertEqual(
            by_customer["ERP-PHONE"],
            "unique_safe_phone",
        )
        self.assertEqual(
            by_customer["ERP-TAX"],
            "unique_tax_id",
        )

    def test_dry_run_counts_unique_tax_id_as_auto_migratable(self):
        rows = [
            self._row(
                "ERP-TAX",
                tax_id="1234567",
                classification="unique_tax_id",
            ),
            self._row(
                "ERP-REVIEW",
                classification="identity_review",
                review_reason="no_identity",
            ),
        ]

        with patch.object(
            customer_migration,
            "_classify",
            return_value=(
                rows,
                Counter(),
                Counter(),
                Counter(),
            ),
        ):
            result = customer_migration.dry_run()

        self.assertEqual(result["auto_migratable"], 1)
        self.assertEqual(result["identity_review"], 1)
        self.assertEqual(
            result["classification"]["unique_tax_id_fallback"],
            1,
        )



class TestCustomerMigrationDisposition(FrappeTestCase):
    def _row(
        self,
        customer,
        classification,
        *,
        email="",
        cnic="",
        phone="",
        tax_id="",
    ):
        return {
            "customer": customer,
            "customer_name": customer,
            "lead": "",
            "email": email,
            "cnic": cnic,
            "customer_phone": phone,
            "lead_phone": "",
            "resolved_phone": phone,
            "phone_source": "customer" if phone else "",
            "phone_conflict": False,
            "tax_id": tax_id,
            "classification": classification,
            "review_reason": (
                "no_identity"
                if classification == "identity_review"
                else ""
            ),
        }

    def _classified_rows(self):
        return [
            self._row(
                "ERP-EMAIL",
                "unique_email",
                email="customer@example.com",
            ),
            self._row(
                "ERP-CNIC",
                "unique_cnic",
                cnic="3520212345671",
            ),
            self._row(
                "ERP-PHONE",
                "unique_safe_phone",
                phone="+923001234567",
            ),
            self._row(
                "ERP-TAX",
                "unique_tax_id",
                tax_id="1234567",
            ),
            self._row(
                "ERP-REVIEW",
                "identity_review",
            ),
        ]

    def test_dry_run_separates_import_from_claim_on_signup(self):
        rows = self._classified_rows()

        with patch.object(
            customer_migration,
            "_classify",
            return_value=(
                rows,
                Counter({"customer@example.com": 1}),
                Counter({"3520212345671": 1}),
                Counter({"+923001234567": 1}),
            ),
        ):
            result = customer_migration.dry_run()

        # Backward-compatible broad identity count.
        self.assertEqual(result["auto_migratable"], 4)

        # Explicit new semantics.
        self.assertEqual(result["safely_identifiable"], 4)
        self.assertEqual(result["activation_ready_import"], 1)
        self.assertEqual(result["deferred_claim_on_signup"], 3)
        self.assertEqual(result["identity_review"], 1)

    def test_preflight_plans_only_unique_email_profiles(self):
        rows = self._classified_rows()

        plan = {
            "target_email": "customer@example.com",
            "profile_email": "customer@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    rows,
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_build_apply_context",
                return_value={},
            ),
            patch.object(
                customer_migration,
                "_plan_apply_row",
                return_value=plan,
            ) as plan_row,
        ):
            result = customer_migration.preflight()

        self.assertEqual(result["auto_migratable"], 4)
        self.assertEqual(result["safely_identifiable"], 4)
        self.assertEqual(result["activation_ready_import"], 1)
        self.assertEqual(result["deferred_claim_on_signup"], 3)

        self.assertEqual(result["profile_only_migratable"], 1)
        self.assertEqual(result["create_customer_profile"], 1)
        self.assertEqual(result["reuse_customer_profile"], 0)
        self.assertEqual(result["user_accounts_to_create"], 0)

        plan_row.assert_called_once()
        self.assertEqual(
            plan_row.call_args.args[0]["classification"],
            "unique_email",
        )

    def test_apply_physically_skips_claim_on_signup_rows(self):
        rows = self._classified_rows()

        plan = {
            "target_email": "customer@example.com",
            "profile_email": "customer@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        profile = SimpleNamespace(
            name="OMC-CUST-IMPORTED-1",
            email="customer@example.com",
            user=None,
        )
        profile.get = MagicMock(return_value="")

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    rows,
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_build_apply_context",
                return_value={},
            ),
            patch.object(
                customer_migration,
                "_plan_apply_row",
                return_value=plan,
            ) as plan_row,
            patch.object(
                customer_migration,
                "_create_or_reuse_profile",
                return_value=(profile, "created"),
            ) as create_profile,
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=False,
            )

        self.assertEqual(result["safe_rows_migrated"], 1)
        self.assertEqual(result["profiles_created"], 1)
        self.assertEqual(result["profiles_reused"], 0)

        self.assertEqual(
            result["deferred_claim_on_signup_skipped"],
            3,
        )
        self.assertEqual(result["identity_review_skipped"], 1)

        plan_row.assert_called_once()
        create_profile.assert_called_once()

        migrated_row = create_profile.call_args.args[0]
        self.assertEqual(
            migrated_row["classification"],
            "unique_email",
        )

    def test_new_imported_profile_records_imported_existing_mode(self):
        row = self._row(
            "ERP-EMAIL",
            "unique_email",
            email="customer@example.com",
            cnic="3520212345671",
            phone="+923001234567",
        )

        plan = {
            "profile_email": "customer@example.com",
            "existing_profile": None,
        }

        meta = MagicMock()
        meta.has_field.return_value = True

        profile = SimpleNamespace(
            meta=meta,
            insert=MagicMock(),
        )

        with patch.object(
            customer_migration.frappe,
            "new_doc",
            return_value=profile,
        ):
            created, action = (
                customer_migration._create_or_reuse_profile(
                    row,
                    plan,
                )
            )

        self.assertEqual(action, "created")
        self.assertIs(created, profile)
        self.assertEqual(
            profile.onboarding_mode,
            "Imported Existing",
        )
        profile.insert.assert_called_once_with(
            ignore_permissions=True,
        )


class TestCustomerMigrationActivationSafety(FrappeTestCase):
    def test_internal_user_email_collision_blocks_bulk_import(self):
        row = {
            "customer": "ERP-STAFF-COLLISION",
            "customer_name": "ERP Staff Collision",
            "lead": "",
            "email": "staff@example.com",
            "cnic": "",
            "customer_phone": "",
            "lead_phone": "",
            "resolved_phone": "",
            "phone_source": "",
            "phone_conflict": False,
            "tax_id": "",
            "classification": "unique_email",
            "review_reason": "",
        }

        context = {
            "users_by_name": {
                "staff@example.com": SimpleNamespace(
                    user_type="System User",
                ),
            },
            "roles_by_user": {
                "staff@example.com": set(),
            },
            "users_by_identity": {
                "staff@example.com": {
                    "staff@example.com",
                },
            },
            "users_by_phone": {},
            "profiles_by_name": {},
            "profiles_by_customer": {},
            "profiles_by_identity": {},
            "profiles_by_cnic": {},
            "profiles_by_phone": {},
            "internal_roles": {"System Manager"},
        }

        plan = customer_migration._plan_apply_row(
            row,
            context,
        )

        self.assertIn(
            "activation_existing_internal_user_identity",
            plan["blockers"],
        )
        self.assertNotIn(
            "activation_existing_internal_user_identity",
            plan["warnings"],
        )

class TestCustomerMigrationIdentityReviewDetails(FrappeTestCase):
    def _review_row(
        self,
        customer,
        reason,
        *,
        lead="",
        email="",
        cnic="",
        phone="",
        tax_id="",
        phone_conflict=False,
    ):
        return {
            "customer": customer,
            "customer_name": customer,
            "lead": lead,
            "email": email,
            "cnic": cnic,
            "customer_phone": phone,
            "lead_phone": "",
            "resolved_phone": phone,
            "phone_source": "customer" if phone else "",
            "phone_conflict": phone_conflict,
            "tax_id": tax_id,
            "classification": "identity_review",
            "review_reason": reason,
        }

    def test_identity_review_details_is_paginated_and_pii_minimal(self):
        rows = [
            self._review_row(
                "ERP-REVIEW-1",
                "duplicate_email",
                lead="LEAD-1",
                email="duplicate@example.com",
            ),
            self._review_row(
                "ERP-REVIEW-2",
                "no_identity",
            ),
            self._review_row(
                "ERP-REVIEW-3",
                "duplicate_email",
                email="duplicate@example.com",
            ),
        ]

        with patch.object(
            customer_migration,
            "_classify",
            return_value=(
                rows,
                Counter(),
                Counter(),
                Counter(),
            ),
        ):
            result = customer_migration.identity_review_details(
                limit=2,
            )

        self.assertTrue(result["read_only"])
        self.assertEqual(result["total_identity_review"], 3)
        self.assertEqual(result["filtered_total"], 3)
        self.assertEqual(result["offset"], 0)
        self.assertEqual(result["limit"], 2)
        self.assertTrue(result["has_more"])
        self.assertEqual(len(result["records"]), 2)
        self.assertEqual(
            result["reason_counts"],
            {
                "duplicate_email": 2,
                "no_identity": 1,
            },
        )

        record = result["records"][0]
        self.assertEqual(record["customer"], "ERP-REVIEW-1")
        self.assertEqual(record["lead"], "LEAD-1")
        self.assertEqual(record["reason"], "duplicate_email")
        self.assertEqual(
            record["identity_signals"],
            {
                "email": True,
                "cnic": False,
                "phone": False,
                "tax_id": False,
                "phone_conflict": False,
            },
        )

        # The operator report must not expose raw identifiers.
        for fieldname in ("email", "cnic", "phone", "tax_id"):
            self.assertNotIn(fieldname, record)

    def test_identity_review_details_filters_exact_reason(self):
        rows = [
            self._review_row(
                "ERP-REVIEW-1",
                "duplicate_email",
            ),
            self._review_row(
                "ERP-REVIEW-2",
                "no_identity",
            ),
            self._review_row(
                "ERP-REVIEW-3",
                "duplicate_email",
            ),
        ]

        with patch.object(
            customer_migration,
            "_classify",
            return_value=(
                rows,
                Counter(),
                Counter(),
                Counter(),
            ),
        ):
            result = customer_migration.identity_review_details(
                reason="duplicate_email",
                offset=1,
                limit=1,
            )

        self.assertEqual(result["total_identity_review"], 3)
        self.assertEqual(result["filtered_total"], 2)
        self.assertEqual(result["reason_filter"], "duplicate_email")
        self.assertEqual(result["offset"], 1)
        self.assertEqual(result["limit"], 1)
        self.assertFalse(result["has_more"])
        self.assertEqual(
            result["records"][0]["customer"],
            "ERP-REVIEW-3",
        )
