from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_customer_resolver


class TestErpCustomerResolver(FrappeTestCase):
    def _profile(
        self,
        *,
        email="customer@example.com",
        phone="03001234567",
        cnic="",
        ntn="1234567",
    ):
        profile = SimpleNamespace(
            doctype="OMC Customer Profile",
            name="OMC-CUST-1",
            linked_erpnext_customer="",
            linked_app_user=email,
            user=email,
            full_name="Test Customer",
            email=email,
            phone=phone,
            cnic=cnic,
            ntn=ntn,
            customer_origin="App Signup",
            approval_status="Approved",
            is_active=1,
        )
        profile.set = MagicMock()
        return profile

    @staticmethod
    def _identity_row(
        customer,
        *,
        emails=(),
        phones=(),
        tax_ids=(),
    ):
        return {
            "customer": customer,
            "emails": set(emails),
            "phones": set(phones),
            "tax_ids": set(tax_ids),
        }

    def test_valid_existing_link_is_reused(self):
        profile = self._profile()
        profile.linked_erpnext_customer = "ERP-CUST-1"

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            return_value=True,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["customer"], "ERP-CUST-1")
        self.assertFalse(result["created"])

    def test_safe_tax_normalisation_accepts_cnic_and_ntn(self):
        self.assertEqual(
            erp_customer_resolver._normalise_tax_id(
                "35202-1234567-1"
            ),
            "3520212345671",
        )
        self.assertEqual(
            erp_customer_resolver._normalise_tax_id(
                "35202 1234567 1"
            ),
            "3520212345671",
        )
        self.assertEqual(
            erp_customer_resolver._normalise_tax_id("1234567"),
            "1234567",
        )

    def test_safe_tax_normalisation_rejects_legacy_prefixed_ids(self):
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
                erp_customer_resolver._normalise_tax_id(value),
                "",
            )

    def test_unique_cnic_claim_matches_existing_customer(self):
        profile = self._profile(
            cnic="35202-1234567-1",
            ntn="",
            email="new-email@example.com",
            phone="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                tax_ids={"3520212345671"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "new-email@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_unique_ntn_claim_matches_existing_customer(self):
        profile = self._profile(
            cnic="",
            ntn="1234567",
            email="new-email@example.com",
            phone="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                tax_ids={"1234567"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "new-email@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_unique_legacy_email_claim_matches_existing_customer(self):
        profile = self._profile(
            email="customer@example.com",
            phone="",
            cnic="",
            ntn="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                emails={"customer@example.com"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "customer@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_unique_safe_phone_claim_matches_existing_customer(self):
        profile = self._profile(
            email="new-email@example.com",
            phone="03001234567",
            cnic="",
            ntn="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                phones={"+923001234567"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "new-email@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_shared_user_link_is_never_customer_identity(self):
        profile = self._profile(
            email="unmatched@example.com",
            phone="",
            cnic="",
            ntn="",
        )

        rows = [
            self._identity_row("ERP-CUST-1"),
            self._identity_row("ERP-CUST-2"),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "asif@omchouse.com",
            )

        self.assertEqual(matches, [])

    def test_duplicate_tax_identity_is_ambiguous(self):
        profile = self._profile(
            cnic="3520212345671",
            ntn="",
            email="new-email@example.com",
            phone="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                tax_ids={"3520212345671"},
            ),
            self._identity_row(
                "ERP-CUST-2",
                tax_ids={"3520212345671"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "new-email@example.com",
            )

        self.assertEqual(
            matches,
            ["ERP-CUST-1", "ERP-CUST-2"],
        )

    def test_conflicting_unique_signals_are_ambiguous(self):
        profile = self._profile(
            email="customer@example.com",
            phone="",
            cnic="3520212345671",
            ntn="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                tax_ids={"3520212345671"},
            ),
            self._identity_row(
                "ERP-CUST-2",
                emails={"customer@example.com"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "customer@example.com",
            )

        self.assertEqual(
            matches,
            ["ERP-CUST-1", "ERP-CUST-2"],
        )

    def test_unique_strong_signal_wins_over_nonunique_weak_signal(self):
        profile = self._profile(
            email="shared@example.com",
            phone="",
            cnic="3520212345671",
            ntn="",
        )

        rows = [
            self._identity_row(
                "ERP-CUST-1",
                emails={"shared@example.com"},
                tax_ids={"3520212345671"},
            ),
            self._identity_row(
                "ERP-CUST-2",
                emails={"shared@example.com"},
            ),
        ]

        with patch.object(
            erp_customer_resolver,
            "_customer_identity_rows",
            return_value=rows,
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "shared@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_unique_match_relinks_without_creation(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1"],
            ),
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["customer"], "ERP-CUST-1")
        self.assertFalse(result["created"])
        link_profile.assert_called_once_with(profile, "ERP-CUST-1")
        create_customer.assert_not_called()

    def test_multiple_matches_are_not_guessed(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1", "ERP-CUST-2"],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Ambiguous")
        self.assertFalse(result["created"])
        create_customer.assert_not_called()

    def test_unapproved_profile_does_not_claim_or_create_customer(self):
        profile = self._profile()
        profile.approval_status = "Pending Review"

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
            ) as customer_matches,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(
            result["status"],
            "Pending Configuration",
        )
        self.assertIn("not approved", result["reason"])
        customer_matches.assert_not_called()
        create_customer.assert_not_called()

    def test_approved_profile_with_no_existing_match_creates_once(self):
        profile = self._profile()
        customer = SimpleNamespace(name="ERP-CUST-NEW")

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
                return_value=(customer, ""),
            ) as create_customer,
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Created")
        self.assertEqual(result["customer"], "ERP-CUST-NEW")
        self.assertTrue(result["created"])

        create_customer.assert_called_once_with(
            profile,
            "customer@example.com",
        )
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-NEW",
        )


class TestErpCustomerResolverModes(FrappeTestCase):
    def _profile(self):
        profile = SimpleNamespace(
            doctype="OMC Customer Profile",
            name="OMC-CUST-MODE-1",
            linked_erpnext_customer="",
            linked_app_user="customer@example.com",
            user="customer@example.com",
            full_name="Test Customer",
            email="customer@example.com",
            phone="",
            cnic="3520212345671",
            ntn="",
            customer_origin="App Signup",
            approval_status="Approved",
            is_active=1,
        )
        profile.set = MagicMock()
        return profile

    def test_existing_claim_never_creates_when_no_match(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(
                profile,
                resolution_mode="claim_existing",
            )

        self.assertEqual(
            result["status"],
            "Pending Configuration",
        )
        self.assertFalse(result["created"])
        create_customer.assert_not_called()

    def test_existing_claim_links_unique_existing_customer(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1"],
            ),
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(
                profile,
                resolution_mode="claim_existing",
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["customer"], "ERP-CUST-1")
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-1",
        )
        create_customer.assert_not_called()

    def test_existing_claim_reconciles_historical_referral(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1"],
            ),
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                erp_customer_resolver,
                "_reconcile_claim_historical_referral",
                create=True,
            ) as reconcile_referral,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(
                profile,
                resolution_mode="claim_existing",
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["customer"], "ERP-CUST-1")
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-1",
        )
        reconcile_referral.assert_called_once_with(
            profile,
            "ERP-CUST-1",
        )
        create_customer.assert_not_called()

    def test_claim_historical_referral_updates_profile_without_consent(self):
        from omc_app.api import customer_migration

        profile = self._profile()
        profile.acquisition_source = "Existing"
        profile.referral_record = ""
        profile.referred_by = ""
        profile.referral_code_used = ""
        profile.referral_assistance_consent = 0
        profile.referral_consent_timestamp = "KEEP-TIMESTAMP"
        profile.referral_consent_version = "KEEP-VERSION"
        profile.save = MagicMock()

        owner = "historical-owner@omchouse.com"

        context = {
            "users_by_identity": {
                owner: {owner},
            },
            "users_by_name": {
                owner: SimpleNamespace(
                    name=owner,
                    enabled=1,
                    user_type="System User",
                ),
            },
            "staff_access_by_user": {
                owner: SimpleNamespace(
                    name="STAFF-1",
                    access_status="Approved",
                    reconciliation_status="Current",
                    persona_snapshot="Business Partner",
                ),
            },
            "referrals_by_user": {
                owner: SimpleNamespace(
                    name="REF-1",
                    referrer_user=owner,
                    referral_code="HIST-123",
                    status="Approved",
                    is_active=1,
                ),
            },
        }

        with (
            patch.object(
                erp_customer_resolver.frappe.db,
                "get_value",
                return_value={
                    "name": "ERP-CUST-1",
                    "source": "Consultant",
                    "sales_person": owner,
                    "custom_reference_lead": "",
                },
            ),
            patch.object(
                customer_migration,
                "_build_apply_context",
                return_value=context,
            ),
        ):
            result = (
                erp_customer_resolver
                ._reconcile_claim_historical_referral(
                    profile,
                    "ERP-CUST-1",
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
            "REF-1",
        )
        self.assertEqual(
            profile.referred_by,
            owner,
        )
        self.assertEqual(
            profile.referral_code_used,
            "HIST-123",
        )

        self.assertEqual(
            profile.referral_assistance_consent,
            0,
        )
        self.assertEqual(
            profile.referral_consent_timestamp,
            "KEEP-TIMESTAMP",
        )
        self.assertEqual(
            profile.referral_consent_version,
            "KEEP-VERSION",
        )

        profile.save.assert_called_once_with(
            ignore_permissions=True,
        )

    def test_new_customer_does_not_silently_claim_existing_match(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1"],
            ),
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(
                profile,
                resolution_mode="new_customer",
            )

        self.assertEqual(
            result["status"],
            "Existing Customer Detected",
        )
        self.assertFalse(result["created"])
        link_profile.assert_not_called()
        create_customer.assert_not_called()

    def test_new_customer_creates_only_when_no_existing_match(self):
        profile = self._profile()
        customer = SimpleNamespace(name="ERP-CUST-NEW")

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
                return_value=(customer, ""),
            ) as create_customer,
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
        ):
            result = erp_customer_resolver.resolve_profile_customer(
                profile,
                resolution_mode="new_customer",
            )

        self.assertEqual(result["status"], "Created")
        self.assertEqual(result["customer"], "ERP-CUST-NEW")
        self.assertTrue(result["created"])

        create_customer.assert_called_once()
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-NEW",
        )
