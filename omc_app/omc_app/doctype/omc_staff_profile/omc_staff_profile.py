from frappe.model.document import Document


class OMCStaffProfile(Document):
    def on_update(self):
        from omc_app import referral_automation

        if self.user:
            referral_automation.ensure_referral_code_for_user(
                self.user
            )
