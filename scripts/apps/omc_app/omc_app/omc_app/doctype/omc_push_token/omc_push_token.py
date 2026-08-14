import frappe
from frappe.model.document import Document


class OMCPushToken(Document):
    def validate(self):
        self.token = (self.token or "").strip()
        self.platform = (self.platform or "unknown").strip().lower()

        if self.platform not in {"android", "ios", "web", "unknown"}:
            self.platform = "unknown"

        if not self.token:
            frappe.throw("Token is required")
