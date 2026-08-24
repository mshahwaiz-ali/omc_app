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
            patch.object(
                customer_migration,
                "_historical_migration_preflight",
                create=True,
                return_value={
                    "read_only": True,
                    "task_types": {},
                    "historical_services": {},
                    "review_reason_counts": {},
                    "review_samples": [],
                },
            ),
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
                "_sync_migration_staff",
                return_value={
                    "candidate_users": 0,
                    "eligible_users": 0,
                    "synced_users": 0,
                    "skipped_users": 0,
                    "skip_reasons": {},
                    "synced_samples": [],
                    "skipped_samples": [],
                },
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
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value={
                    "task_types": {},
                    "historical_services": {},
                    "review_reason_counts": {},
                    "review_samples": [],
                    "changed": False,
                },
            ),
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


class TestCustomerMigrationHistoricalReferralResolution(FrappeTestCase):
    def _context_for(
        self,
        user,
        *,
        enabled=1,
        user_type="System User",
        current_persona="Business Partner",
        access_status="Approved",
        reconciliation_status="Current",
        referral=True,
    ):
        key = user.lower()

        context = {
            "users_by_identity": {
                key: {user},
            },
            "users_by_name": {
                user: SimpleNamespace(
                    enabled=enabled,
                    user_type=user_type,
                ),
            },
            "staff_access_by_user": {
                user: SimpleNamespace(
                    name=f"ACCESS-{user}",
                    access_status=access_status,
                    reconciliation_status=reconciliation_status,
                    persona_snapshot=current_persona,
                ),
            },
            "referrals_by_user": {},
        }

        if referral:
            context["referrals_by_user"][user] = SimpleNamespace(
                name=f"REF-{user}",
                referrer_user=user,
                referral_code="HISTREF001",
                status="Approved",
                is_active=1,
            )

        return context

    def test_direct_customer_sales_person_preserves_historical_persona(self):
        user = "adnan@omchouse.com"

        row = {
            "customer": "ERP-HIST-1",
            "source": "Consultant",
            "sales_person": "Adnan@OMCHOUSE.COM",
            "lead_sales_person": "",
        }

        # Adnan may currently be a Business Partner, but this customer's
        # historical relationship was Consultant.
        context = self._context_for(
            user,
            current_persona="Business Partner",
        )

        decision = (
            customer_migration._historical_referral_decision(
                row,
                context,
            )
        )

        self.assertEqual(decision["action"], "link")
        self.assertEqual(decision["owner_user"], user)
        self.assertEqual(
            decision["historical_persona"],
            "Consultant",
        )
        self.assertEqual(
            decision["identity_source"],
            "Customer.sales_person",
        )
        self.assertEqual(
            decision["referral_record"],
            f"REF-{user}",
        )
        self.assertEqual(
            decision["referral_code"],
            "HISTREF001",
        )

    def test_lead_sales_person_is_used_only_when_customer_sales_person_blank(self):
        user = "omc@omchouse.com"

        row = {
            "customer": "ERP-HIST-2",
            "source": "Consultant",
            "sales_person": "",
            "lead_sales_person": user,
        }

        context = self._context_for(
            user,
            current_persona="Consultant",
        )

        decision = (
            customer_migration._historical_referral_decision(
                row,
                context,
            )
        )

        self.assertEqual(decision["action"], "link")
        self.assertEqual(decision["owner_user"], user)
        self.assertEqual(
            decision["historical_persona"],
            "Consultant",
        )
        self.assertEqual(
            decision["identity_source"],
            "Lead.sales_person",
        )

    def test_lead_owner_is_never_guessed_as_historical_referrer(self):
        row = {
            "customer": "ERP-HIST-3",
            "source": "Consultant",
            "sales_person": "",
            "lead_sales_person": "",
            "lead_owner": "someone@example.com",
        }

        decision = (
            customer_migration._historical_referral_decision(
                row,
                {},
            )
        )

        self.assertEqual(decision["action"], "review")
        self.assertEqual(
            decision["reason"],
            "missing_historical_referrer",
        )

    def test_non_referral_historical_persona_is_never_linked(self):
        row = {
            "customer": "ERP-HIST-4",
            "source": "Employee",
            "sales_person": "sidra@omchouse.com",
            "lead_sales_person": "",
        }

        decision = (
            customer_migration._historical_referral_decision(
                row,
                {},
            )
        )

        self.assertEqual(decision["action"], "review")
        self.assertEqual(
            decision["reason"],
            "historical_source_not_referral_capable",
        )


class TestCustomerMigrationHistoricalReferralResolution(FrappeTestCase):
    def _context_for(
        self,
        user,
        *,
        enabled=1,
        user_type="System User",
        current_persona="Business Partner",
        access_status="Approved",
        reconciliation_status="Current",
        referral=True,
    ):
        key = user.lower()

        context = {
            "users_by_identity": {
                key: {user},
            },
            "users_by_name": {
                user: SimpleNamespace(
                    enabled=enabled,
                    user_type=user_type,
                ),
            },
            "staff_access_by_user": {
                user: SimpleNamespace(
                    name=f"ACCESS-{user}",
                    access_status=access_status,
                    reconciliation_status=reconciliation_status,
                    persona_snapshot=current_persona,
                ),
            },
            "referrals_by_user": {},
        }

        if referral:
            context["referrals_by_user"][user] = SimpleNamespace(
                name=f"REF-{user}",
                referrer_user=user,
                referral_code="HISTREF001",
                status="Approved",
                is_active=1,
            )

        return context

    def test_direct_customer_sales_person_preserves_historical_persona(self):
        user = "adnan@omchouse.com"

        row = {
            "customer": "ERP-HIST-1",
            "source": "Consultant",
            "sales_person": "Adnan@OMCHOUSE.COM",
            "lead_sales_person": "",
        }

        # Adnan may currently be a Business Partner, but this customer's
        # historical relationship was Consultant.
        context = self._context_for(
            user,
            current_persona="Business Partner",
        )

        decision = (
            customer_migration._historical_referral_decision(
                row,
                context,
            )
        )

        self.assertEqual(decision["action"], "link")
        self.assertEqual(decision["owner_user"], user)
        self.assertEqual(
            decision["historical_persona"],
            "Consultant",
        )
        self.assertEqual(
            decision["identity_source"],
            "Customer.sales_person",
        )
        self.assertEqual(
            decision["referral_record"],
            f"REF-{user}",
        )
        self.assertEqual(
            decision["referral_code"],
            "HISTREF001",
        )

    def test_lead_sales_person_is_used_only_when_customer_sales_person_blank(self):
        user = "omc@omchouse.com"

        row = {
            "customer": "ERP-HIST-2",
            "source": "Consultant",
            "sales_person": "",
            "lead_sales_person": user,
        }

        context = self._context_for(
            user,
            current_persona="Consultant",
        )

        decision = (
            customer_migration._historical_referral_decision(
                row,
                context,
            )
        )

        self.assertEqual(decision["action"], "link")
        self.assertEqual(decision["owner_user"], user)
        self.assertEqual(
            decision["historical_persona"],
            "Consultant",
        )
        self.assertEqual(
            decision["identity_source"],
            "Lead.sales_person",
        )

    def test_lead_owner_is_never_guessed_as_historical_referrer(self):
        row = {
            "customer": "ERP-HIST-3",
            "source": "Consultant",
            "sales_person": "",
            "lead_sales_person": "",
            "lead_owner": "someone@example.com",
        }

        decision = (
            customer_migration._historical_referral_decision(
                row,
                {},
            )
        )

        self.assertEqual(decision["action"], "review")
        self.assertEqual(
            decision["reason"],
            "missing_historical_referrer",
        )

    def test_non_referral_historical_persona_is_never_linked(self):
        row = {
            "customer": "ERP-HIST-4",
            "source": "Employee",
            "sales_person": "sidra@omchouse.com",
            "lead_sales_person": "",
        }

        decision = (
            customer_migration._historical_referral_decision(
                row,
                {},
            )
        )

        self.assertEqual(decision["action"], "review")
        self.assertEqual(
            decision["reason"],
            "historical_source_not_referral_capable",
        )


class TestCustomerMigrationHistoricalReferralDataPlumbing(FrappeTestCase):
    def test_identity_rows_carry_customer_and_lead_referral_evidence(self):
        customer = customer_migration.frappe._dict({
            "name": "ERP-HIST-DATA-1",
            "customer_name": "Historical Customer",
            "tax_id": "",
            "custom_email_address": "hist@example.com",
            "contact_no": "",
            "custom_reference_lead": "LEAD-HIST-1",
            "source": "Consultant",
            "sales_person": "",
        })

        lead = customer_migration.frappe._dict({
            "name": "LEAD-HIST-1",
            "mobile_no": "",
            "custom_cnic": "",
            "sales_person": "omc@omchouse.com",
        })

        with (
            patch.object(
                customer_migration,
                "_load_customers",
                return_value=[customer],
            ),
            patch.object(
                customer_migration,
                "_load_leads",
                return_value={
                    "LEAD-HIST-1": lead,
                },
            ),
        ):
            rows = customer_migration._identity_rows()

        self.assertEqual(len(rows), 1)

        row = rows[0]

        self.assertEqual(row["source"], "Consultant")
        self.assertEqual(row["sales_person"], "")
        self.assertEqual(
            row["lead_sales_person"],
            "omc@omchouse.com",
        )

    def test_customer_and_lead_load_fields_include_historical_referral_evidence(self):
        self.assertIn(
            "source",
            customer_migration.CUSTOMER_FIELDS,
        )
        self.assertIn(
            "sales_person",
            customer_migration.CUSTOMER_FIELDS,
        )
        self.assertIn(
            "sales_person",
            customer_migration.LEAD_FIELDS,
        )

    def test_apply_context_loads_staff_access_and_referral_registry(self):
        user = "adnan@omchouse.com"

        users = [
            customer_migration.frappe._dict({
                "name": user,
                "email": user,
                "enabled": 1,
                "user_type": "System User",
                "mobile_no": "",
            }),
        ]

        staff_access = [
            customer_migration.frappe._dict({
                "name": "ACCESS-ADNAN",
                "user": user,
                "access_status": "Approved",
                "reconciliation_status": "Current",
                "persona_snapshot": "Business Partner",
            }),
        ]

        referrals = [
            customer_migration.frappe._dict({
                "name": "REF-ADNAN",
                "referrer_user": user,
                "referral_code": "ADNAN001",
                "status": "Approved",
                "is_active": 1,
            }),
        ]

        def fake_get_all(doctype, *args, **kwargs):
            if doctype == "User":
                return users

            if doctype == "Has Role":
                return []

            if doctype == "OMC Customer Profile":
                return []

            if doctype == "OMC Staff Access":
                return staff_access

            if doctype == "OMC Referral":
                return referrals

            self.fail(
                f"Unexpected get_all doctype: {doctype}"
            )

        with patch.object(
            customer_migration.frappe,
            "get_all",
            side_effect=fake_get_all,
        ):
            context = (
                customer_migration._build_apply_context()
            )

        self.assertIs(
            context["staff_access_by_user"][user],
            staff_access[0],
        )
        self.assertIs(
            context["referrals_by_user"][user],
            referrals[0],
        )


class TestCustomerMigrationHistoricalReferralProfileLink(FrappeTestCase):
    def _decision(self):
        return {
            "action": "link",
            "reason": "",
            "historical_persona": "Consultant",
            "identity_source": "Customer.sales_person",
            "owner_user": "adnan@omchouse.com",
            "staff_access": "ACCESS-ADNAN",
            "current_persona": "Business Partner",
            "referral_record": "REF-ADNAN",
            "referral_code": "ADNAN001",
        }

    def _profile(
        self,
        *,
        acquisition_source="Existing",
        referral_record="",
        referred_by="",
        referral_code_used="",
        consent=0,
        consent_timestamp=None,
        consent_version="",
    ):
        return SimpleNamespace(
            name="OMC-CUST-HIST-1",
            acquisition_source=acquisition_source,
            referral_record=referral_record,
            referred_by=referred_by,
            referral_code_used=referral_code_used,
            referral_assistance_consent=consent,
            referral_consent_timestamp=consent_timestamp,
            referral_consent_version=consent_version,
            save=MagicMock(),
        )

    def test_historical_referral_links_imported_profile_without_fabricating_consent(self):
        profile = self._profile()

        result = (
            customer_migration._apply_historical_referral_to_profile(
                profile,
                self._decision(),
            )
        )

        self.assertEqual(result["action"], "linked")
        self.assertTrue(result["changed"])

        self.assertEqual(
            profile.acquisition_source,
            "Referral",
        )
        self.assertEqual(
            profile.referral_record,
            "REF-ADNAN",
        )
        self.assertEqual(
            profile.referred_by,
            "adnan@omchouse.com",
        )
        self.assertEqual(
            profile.referral_code_used,
            "ADNAN001",
        )

        # Historical ERP relationship is not customer assistance consent.
        self.assertEqual(
            profile.referral_assistance_consent,
            0,
        )
        self.assertIsNone(
            profile.referral_consent_timestamp,
        )
        self.assertEqual(
            profile.referral_consent_version,
            "",
        )

        profile.save.assert_called_once_with(
            ignore_permissions=True,
        )

    def test_correct_existing_historical_referral_is_idempotent(self):
        profile = self._profile(
            acquisition_source="Referral",
            referral_record="REF-ADNAN",
            referred_by="adnan@omchouse.com",
            referral_code_used="ADNAN001",
        )

        result = (
            customer_migration._apply_historical_referral_to_profile(
                profile,
                self._decision(),
            )
        )

        self.assertEqual(
            result["action"],
            "already_linked",
        )
        self.assertFalse(result["changed"])
        profile.save.assert_not_called()

    def test_conflicting_existing_referral_is_never_overwritten(self):
        profile = self._profile(
            acquisition_source="Referral",
            referral_record="REF-SOMEONE-ELSE",
            referred_by="someone@example.com",
            referral_code_used="OTHER001",
        )

        before = (
            profile.acquisition_source,
            profile.referral_record,
            profile.referred_by,
            profile.referral_code_used,
            profile.referral_assistance_consent,
        )

        result = (
            customer_migration._apply_historical_referral_to_profile(
                profile,
                self._decision(),
            )
        )

        self.assertEqual(result["action"], "review")
        self.assertEqual(
            result["reason"],
            "existing_referral_conflict",
        )
        self.assertFalse(result["changed"])

        after = (
            profile.acquisition_source,
            profile.referral_record,
            profile.referred_by,
            profile.referral_code_used,
            profile.referral_assistance_consent,
        )

        self.assertEqual(after, before)
        profile.save.assert_not_called()

    def test_existing_nonlegacy_acquisition_source_is_not_silently_replaced(self):
        profile = self._profile(
            acquisition_source="Website",
        )

        result = (
            customer_migration._apply_historical_referral_to_profile(
                profile,
                self._decision(),
            )
        )

        self.assertEqual(result["action"], "review")
        self.assertEqual(
            result["reason"],
            "existing_acquisition_source_conflict",
        )
        self.assertFalse(result["changed"])

        self.assertEqual(
            profile.acquisition_source,
            "Website",
        )
        self.assertEqual(profile.referral_record, "")
        self.assertEqual(profile.referred_by, "")
        self.assertEqual(profile.referral_code_used, "")
        self.assertEqual(
            profile.referral_assistance_consent,
            0,
        )

        profile.save.assert_not_called()


class TestCustomerMigrationOneCommandOrchestration(FrappeTestCase):
    def test_staff_phase_syncs_only_authoritative_eligible_system_users(self):
        from omc_app.setup import staff_sync

        users = [
            customer_migration.frappe._dict(
                {"name": "consultant@example.com"}
            ),
            customer_migration.frappe._dict(
                {"name": "bp@example.com"}
            ),
            customer_migration.frappe._dict(
                {"name": "ordinary@example.com"}
            ),
        ]

        previews = {
            "consultant@example.com": {
                "eligible": True,
                "user": "consultant@example.com",
                "mapped_staff_persona": "Consultant",
                "reason": "",
            },
            "bp@example.com": {
                "eligible": True,
                "user": "bp@example.com",
                "mapped_staff_persona": "Business Partner",
                "reason": "",
            },
            "ordinary@example.com": {
                "eligible": False,
                "user": "ordinary@example.com",
                "mapped_staff_persona": "",
                "reason": "unsupported_or_missing_omc_user_type",
            },
        }

        def preview(user):
            return previews[user]

        def sync(user, *, apply=False, commit=True):
            self.assertTrue(apply)
            self.assertFalse(commit)

            return {
                **previews[user],
                "applied": True,
                "staff_access": f"ACCESS-{user}",
                "referral_record": f"REF-{user}",
            }

        with (
            patch.object(
                customer_migration.frappe,
                "get_all",
                return_value=users,
            ) as get_all,
            patch.object(
                staff_sync,
                "preview_staff_user",
                side_effect=preview,
            ) as preview_user,
            patch.object(
                staff_sync,
                "sync_staff_user",
                side_effect=sync,
            ) as sync_user,
        ):
            result = (
                customer_migration._sync_migration_staff()
            )

        self.assertEqual(result["candidate_users"], 3)
        self.assertEqual(result["eligible_users"], 2)
        self.assertEqual(result["synced_users"], 2)
        self.assertEqual(result["skipped_users"], 1)

        self.assertEqual(
            result["skip_reasons"],
            {
                "unsupported_or_missing_omc_user_type": 1,
            },
        )

        get_all.assert_called_once()

        query_kwargs = get_all.call_args.kwargs
        self.assertEqual(
            query_kwargs["filters"],
            {
                "enabled": 1,
                "user_type": "System User",
            },
        )

        self.assertEqual(preview_user.call_count, 3)
        self.assertEqual(sync_user.call_count, 2)

        synced = [
            call.args[0]
            for call in sync_user.call_args_list
        ]

        self.assertEqual(
            synced,
            [
                "consultant@example.com",
                "bp@example.com",
            ],
        )

    def test_apply_runs_staff_phase_before_context_then_links_referral(self):
        events = []

        row = {
            "customer": "ERP-HIST-ORCH-1",
            "customer_name": "Historical Customer",
            "classification": "unique_email",
            "review_reason": "",
            "email": "customer@example.com",
            "cnic": "",
            "resolved_phone": "",
            "source": "Consultant",
            "sales_person": "adnan@omchouse.com",
            "lead_sales_person": "",
        }

        plan = {
            "target_email": "customer@example.com",
            "profile_email": "customer@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        profile = SimpleNamespace(
            name="OMC-CUST-HIST-ORCH-1",
            email="customer@example.com",
            user=None,
        )
        profile.get = MagicMock(return_value="")

        staff_result = {
            "candidate_users": 1,
            "eligible_users": 1,
            "synced_users": 1,
            "skipped_users": 0,
            "skip_reasons": {},
            "synced_samples": [
                "adnan@omchouse.com",
            ],
            "skipped_samples": [],
        }

        context = {"rebuilt_after_staff": True}

        decision = {
            "action": "link",
            "reason": "",
            "historical_persona": "Consultant",
            "owner_user": "adnan@omchouse.com",
            "referral_record": "REF-ADNAN",
            "referral_code": "ADNAN001",
        }

        link_result = {
            "action": "linked",
            "reason": "",
            "changed": True,
        }

        def staff_phase():
            events.append("staff")
            return staff_result

        def build_context():
            events.append("context")
            return context

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [row],
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_sync_migration_staff",
                create=True,
                side_effect=staff_phase,
            ) as sync_staff,
            patch.object(
                customer_migration,
                "_build_apply_context",
                side_effect=build_context,
            ),
            patch.object(
                customer_migration,
                "_plan_apply_row",
                return_value=plan,
            ),
            patch.object(
                customer_migration,
                "_create_or_reuse_profile",
                return_value=(profile, "created"),
            ),
            patch.object(
                customer_migration,
                "_historical_referral_decision",
                return_value=decision,
            ) as referral_decision,
            patch.object(
                customer_migration,
                "_apply_historical_referral_to_profile",
                return_value=link_result,
            ) as link_referral,
            patch(
                "omc_app.api.referral_attribution."
                "create_historical_acquisition_snapshot",
            ),
            patch.object(
                customer_migration.frappe.db,
                "commit",
            ) as commit,
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value={
                    "task_types": {},
                    "historical_services": {},
                    "review_reason_counts": {},
                    "review_samples": [],
                    "changed": False,
                },
            ),
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=False,
            )

        sync_staff.assert_called_once_with()

        # Critical ordering contract:
        # new Staff Access + Referral records must exist before
        # apply-context is rebuilt.
        self.assertEqual(
            events[:2],
            ["staff", "context"],
        )

        referral_decision.assert_called_once_with(
            row,
            context,
        )

        link_referral.assert_called_once_with(
            profile,
            decision,
        )

        self.assertEqual(
            result["staff_sync"],
            staff_result,
        )
        self.assertEqual(
            result["historical_referrals_linked"],
            1,
        )
        self.assertEqual(
            result["historical_referrals_already_linked"],
            0,
        )
        self.assertEqual(
            result["historical_referral_review"],
            0,
        )

        commit.assert_not_called()

    def test_apply_reports_unresolved_historical_referral_fail_closed(self):
        row = {
            "customer": "ERP-HIST-ORCH-2",
            "customer_name": "Historical Customer",
            "classification": "unique_email",
            "review_reason": "",
            "email": "customer2@example.com",
            "cnic": "",
            "resolved_phone": "",
            "source": "Consultant",
            "sales_person": "",
            "lead_sales_person": "",
        }

        plan = {
            "target_email": "customer2@example.com",
            "profile_email": "customer2@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        profile = SimpleNamespace(
            name="OMC-CUST-HIST-ORCH-2",
            email="customer2@example.com",
            user=None,
        )
        profile.get = MagicMock(return_value="")

        decision = {
            "action": "review",
            "reason": "missing_historical_referrer",
            "historical_persona": "Consultant",
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [row],
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_sync_migration_staff",
                create=True,
                return_value={
                    "candidate_users": 0,
                    "eligible_users": 0,
                    "synced_users": 0,
                    "skipped_users": 0,
                    "skip_reasons": {},
                    "synced_samples": [],
                    "skipped_samples": [],
                },
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
            ),
            patch.object(
                customer_migration,
                "_create_or_reuse_profile",
                return_value=(profile, "created"),
            ),
            patch.object(
                customer_migration,
                "_historical_referral_decision",
                return_value=decision,
            ),
            patch.object(
                customer_migration,
                "_apply_historical_referral_to_profile",
            ) as link_referral,
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value={
                    "task_types": {},
                    "historical_services": {},
                    "review_reason_counts": {},
                    "review_samples": [],
                    "changed": False,
                },
            ),
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=False,
            )

        link_referral.assert_not_called()

        self.assertEqual(
            result["historical_referrals_linked"],
            0,
        )
        self.assertEqual(
            result["historical_referral_review"],
            1,
        )
        self.assertEqual(
            result["historical_referral_review_counts"],
            {
                "missing_historical_referrer": 1,
            },
        )

        self.assertEqual(
            result["historical_referral_review_samples"][0]["customer"],
            "ERP-HIST-ORCH-2",
        )
        self.assertEqual(
            result["historical_referral_review_samples"][0]["reason"],
            "missing_historical_referrer",
        )


class TestCustomerMigrationHistoricalAttributionOrchestration(FrappeTestCase):
    def test_apply_ensures_historical_acquisition_attribution(self):
        from omc_app.api import referral_attribution

        row = {
            "customer": "ERP-HIST-ATTR-1",
            "customer_name": "Historical Customer",
            "classification": "unique_email",
            "review_reason": "",
            "email": "customer@example.com",
            "cnic": "",
            "resolved_phone": "",
            "source": "Consultant",
            "sales_person": "adnan@omchouse.com",
            "lead_sales_person": "",
        }

        plan = {
            "target_email": "customer@example.com",
            "profile_email": "customer@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        profile = SimpleNamespace(
            name="OMC-CUST-HIST-ATTR-1",
            email="customer@example.com",
            user=None,
        )
        profile.get = MagicMock(return_value="")

        decision = {
            "action": "link",
            "reason": "",
            "historical_persona": "Consultant",
            "owner_user": "adnan@omchouse.com",
            "referral_record": "REF-ADNAN",
            "referral_code": "ADNAN001",
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [row],
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_sync_migration_staff",
                return_value={
                    "candidate_users": 0,
                    "eligible_users": 0,
                    "synced_users": 0,
                    "skipped_users": 0,
                    "skip_reasons": {},
                    "synced_samples": [],
                    "skipped_samples": [],
                },
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
            ),
            patch.object(
                customer_migration,
                "_create_or_reuse_profile",
                return_value=(profile, "created"),
            ),
            patch.object(
                customer_migration,
                "_historical_referral_decision",
                return_value=decision,
            ),
            patch.object(
                customer_migration,
                "_apply_historical_referral_to_profile",
                return_value={
                    "action": "linked",
                    "reason": "",
                    "changed": True,
                },
            ),
            patch.object(
                referral_attribution,
                "create_historical_acquisition_snapshot",
            ) as create_attribution,
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value={
                    "task_types": {},
                    "historical_services": {},
                    "review_reason_counts": {},
                    "review_samples": [],
                    "changed": False,
                },
            ),
        ):
            customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=False,
            )

        create_attribution.assert_called_once_with(
            referral_registry="REF-ADNAN",
            erp_customer="ERP-HIST-ATTR-1",
            historical_persona="Consultant",
        )

    def test_historical_attribution_conflict_becomes_review(self):
        row = {
            "customer": "ERP-HIST-ATTR-CONFLICT",
        }
        decision = {
            "referral_record": "REF-ADNAN",
            "historical_persona": "Consultant",
        }

        with patch(
            "omc_app.api.referral_attribution."
            "create_historical_acquisition_snapshot",
            side_effect=customer_migration.frappe.ValidationError(
                "Conflicting acquisition attribution."
            ),
        ):
            result = (
                customer_migration
                ._ensure_historical_attribution(
                    row,
                    decision,
                )
            )

        self.assertEqual(result["action"], "review")
        self.assertEqual(
            result["reason"],
            "historical_attribution_validation_error",
        )

class TestCustomerMigrationHistoricalServiceUnifiedCommand(
    FrappeTestCase
):
    @staticmethod
    def _staff_result():
        return {
            "candidate_users": 0,
            "eligible_users": 0,
            "synced_users": 0,
            "skipped_users": 0,
            "skip_reasons": {},
            "synced_samples": [],
            "skipped_samples": [],
        }

    def test_preflight_includes_historical_service_plan(self):
        historical_plan = {
            "read_only": True,
            "task_types": {"total": 31},
            "historical_services": {"total": 69},
            "review_reason_counts": {},
            "review_samples": [],
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [],
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
                "_historical_migration_preflight",
                create=True,
                return_value=historical_plan,
            ) as historical_preflight,
        ):
            result = customer_migration.preflight()

        historical_preflight.assert_called_once_with()

        self.assertEqual(
            result["historical_service_migration"],
            historical_plan,
        )

    def test_profile_limit_does_not_skip_historical_projection(self):
        rows = [
            {
                "customer": "ERP-LIMIT-1",
                "customer_name": "Customer One",
                "classification": "unique_email",
                "review_reason": "",
                "email": "one@example.com",
                "cnic": "",
                "resolved_phone": "",
                "source": "",
                "sales_person": "",
                "lead_sales_person": "",
            },
            {
                "customer": "ERP-LIMIT-2",
                "customer_name": "Customer Two",
                "classification": "unique_email",
                "review_reason": "",
                "email": "two@example.com",
                "cnic": "",
                "resolved_phone": "",
                "source": "",
                "sales_person": "",
                "lead_sales_person": "",
            },
        ]

        plan = {
            "target_email": "customer@example.com",
            "profile_email": "customer@example.com",
            "existing_user": None,
            "existing_profile": None,
            "blockers": [],
            "warnings": [],
        }

        profile = SimpleNamespace(
            name="OMC-CUST-LIMIT-1",
            email="one@example.com",
            user=None,
        )
        profile.get = MagicMock(return_value="")

        historical_result = {
            "task_types": {"created": 31},
            "historical_services": {"created": 68},
            "review_reason_counts": {},
            "review_samples": [],
            "changed": True,
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
                "_sync_migration_staff",
                return_value=self._staff_result(),
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
            ),
            patch.object(
                customer_migration,
                "_create_or_reuse_profile",
                return_value=(profile, "created"),
            ) as create_profile,
            patch.object(
                customer_migration,
                "_historical_referral_decision",
                return_value={
                    "action": "review",
                    "reason": "no_historical_referral_evidence",
                },
            ),
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value=historical_result,
            ) as historical_projection,
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                limit=1,
                commit=False,
            )

        self.assertEqual(result["safe_rows_migrated"], 1)
        self.assertEqual(create_profile.call_count, 1)

        historical_projection.assert_called_once_with()

        self.assertEqual(
            result["historical_service_migration"],
            historical_result,
        )

    def test_commit_false_never_commits_historical_projection(self):
        historical_result = {
            "task_types": {"created": 1},
            "historical_services": {"created": 1},
            "review_reason_counts": {},
            "review_samples": [],
            "changed": True,
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [],
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_sync_migration_staff",
                return_value=self._staff_result(),
            ),
            patch.object(
                customer_migration,
                "_build_apply_context",
                return_value={},
            ),
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value=historical_result,
            ) as historical_projection,
            patch.object(
                customer_migration.frappe.db,
                "commit",
            ) as commit,
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=False,
            )

        historical_projection.assert_called_once_with()
        commit.assert_not_called()

        self.assertEqual(
            result["historical_service_migration"],
            historical_result,
        )

    def test_commit_true_commits_historical_changes_at_outer_boundary(self):
        historical_result = {
            "task_types": {"created": 1},
            "historical_services": {"created": 1},
            "review_reason_counts": {},
            "review_samples": [],
            "changed": True,
        }

        with (
            patch.object(
                customer_migration,
                "_classify",
                return_value=(
                    [],
                    Counter(),
                    Counter(),
                    Counter(),
                ),
            ),
            patch.object(
                customer_migration,
                "_sync_migration_staff",
                return_value=self._staff_result(),
            ),
            patch.object(
                customer_migration,
                "_build_apply_context",
                return_value={},
            ),
            patch.object(
                customer_migration,
                "_apply_historical_service_projection",
                create=True,
                return_value=historical_result,
            ) as historical_projection,
            patch.object(
                customer_migration.frappe.db,
                "commit",
            ) as commit,
        ):
            result = customer_migration.apply(
                confirm=customer_migration.APPLY_CONFIRMATION,
                commit=True,
            )

        historical_projection.assert_called_once_with()
        commit.assert_called_once_with()

        self.assertEqual(
            result["historical_service_migration"],
            historical_result,
        )
