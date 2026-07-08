from frappe.model.document import Document


class OMCMobileQuickAction(Document):
    def before_save(self):
        if self.icon_key:
            self.icon_key = self.icon_key.strip().lower().replace("_", "-")
        if self.target_value:
            self.target_value = self.target_value.strip()
        if not self.target_type:
            self.target_type = "Route"
        if not self.access_level:
            self.access_level = "Public"
        if not self.badge_type:
            self.badge_type = "None"
        if not self.style:
            self.style = "Normal"
