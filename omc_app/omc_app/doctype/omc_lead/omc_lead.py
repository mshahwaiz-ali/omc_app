from frappe.model.document import Document


ERP_LEAD_FIELD_MAP = {
    "first_name": "first_name",
    "middle_name": "middle_name",
    "last_name": "last_name",
    "lead_name": "lead_name",
    "company_name": "company_name",
    "email_id": "email_id",
    "mobile_no": "mobile_no",
    "whatsapp_no": "whatsapp_no",
    "phone": "phone",
    "phone_ext": "phone_ext",
    "website": "website",
    "status": "status",
    "source": "source",
    "lead_type": "type",
    "request_type": "request_type",
    "lead_owner": "lead_owner",
    "sales_person": "sales_person",
    "industry": "industry",
    "market_segment": "market_segment",
    "territory": "territory",
    "no_of_employees": "no_of_employees",
    "annual_revenue": "annual_revenue",
    "city": "city",
    "state": "state",
    "country": "country",
    "qualification_status": "qualification_status",
    "qualified_by": "qualified_by",
    "qualified_on": "qualified_on",
    "campaign_name": "campaign_name",
    "reference_business_partner": "reference_business_partner",
    "notes": "notes",
}


class OMCLead(Document):
    def validate(self):
        self._normalise_legacy_contact_fields()
        self._derive_identity_fields()
        self.erp_doctype = self.erp_doctype or "Lead"
        self.erp_sync_status = self.erp_sync_status or "Not Required"

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
