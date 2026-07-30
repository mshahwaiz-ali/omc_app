from frappe.model.document import Document


class OMCLead(Document):
    def validate(self):
        self._normalise_legacy_contact_fields()
        self._derive_identity_fields()

    def _normalise_legacy_contact_fields(self):
        # Keep existing records and older Flutter clients compatible.
        self.email_id = self.email_id or self.email
        self.email = self.email or self.email_id
        self.mobile_no = self.mobile_no or self.phone
        self.phone = self.phone or self.mobile_no

    def _derive_identity_fields(self):
        full_name = " ".join(
            part.strip()
            for part in (self.first_name, self.middle_name, self.last_name)
            if part and part.strip()
        )
        self.lead_name = self.lead_name or full_name or self.company_name or self.title
        self.title = self.title or self.company_name or self.lead_name or full_name
