from __future__ import annotations

import frappe
from frappe.model.document import Document

from omc_app.api.referrals import normalize_referral_code
from omc_app.referral_automation import is_eligible_referral_owner


class OMCReferral(Document):
    def before_insert(self):
        self.referral_code = normalize_referral_code(self.referral_code)
        self._validate_owner()
        self._validate_unique_owner()
        self._snapshot_owner()

    def validate(self):
        self.referral_code = normalize_referral_code(self.referral_code)
        self._validate_owner()
        self._validate_unique_owner()
        self._prevent_identity_changes()

    def _snapshot_owner(self):
        from omc_app.api.identity import get_staff_access, source_version

        access = get_staff_access(self.referrer_user)
        if not access:
            frappe.throw(
                "Referral ownership requires approved Staff Access.",
                frappe.ValidationError,
            )
        self.owner_persona_snapshot = access.persona_snapshot
        self.owner_source_version = access.source_version or source_version(
            access.user, access.persona_snapshot, access.modified
        )

    def _validate_owner(self):
        if not is_eligible_referral_owner(self.referrer_user):
            frappe.throw(
                "Referral codes are available only to eligible active OMC internal staff.",
                frappe.ValidationError,
            )

    def _validate_unique_owner(self):
        existing = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": self.referrer_user, "name": ["!=", self.name]},
            "name",
        )
        if existing:
            frappe.throw(
                "This internal user already has a referral code.",
                frappe.DuplicateEntryError,
            )

    def _prevent_identity_changes(self):
        if self.is_new():
            return
        previous = self.get_doc_before_save()
        if not previous:
            return
        protected = (
            "referral_code",
            "referrer_user",
            "referred_customer_profile",
            "referred_app_user",
            "signup_date",
            "owner_persona_snapshot",
            "owner_source_version",
        )
        for fieldname in protected:
            if self.get(fieldname) != previous.get(fieldname):
                frappe.throw(
                    f"{self.meta.get_label(fieldname)} is system-managed and cannot be changed.",
                    frappe.PermissionError,
                )
