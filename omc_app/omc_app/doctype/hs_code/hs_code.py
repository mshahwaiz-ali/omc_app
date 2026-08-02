import re

import frappe
from frappe.model.document import Document


class HSCode(Document):
    def autoname(self):
        code = str(self.hs_code or "").strip().upper()
        if not code:
            frappe.throw("HS Code is required.", frappe.ValidationError)
        self.hs_code = code
        self.name = code

    def validate(self):
        self.hs_code = str(self.hs_code or self.name or "").strip().upper()
        if len(self.hs_code) > 32 or not re.fullmatch(r"[A-Z0-9][A-Z0-9.\- ]*", self.hs_code):
            frappe.throw(
                "HS Code may contain letters, numbers, spaces, dots and hyphens only.",
                frappe.ValidationError,
            )

