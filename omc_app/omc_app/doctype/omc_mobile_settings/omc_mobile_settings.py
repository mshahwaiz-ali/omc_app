import frappe
from frappe.model.document import Document


class OMCMobileSettings(Document):
    def validate(self):
        from omc_app.api.mobile_release_controls import validate_release_controls

        try:
            controls = validate_release_controls(
                self.get("minimum_app_version"),
                self.get("force_update"),
                self.get("maintenance_mode"),
            )
        except ValueError as error:
            frappe.throw(str(error), frappe.ValidationError)

        self.minimum_app_version = controls["minimum_app_version"]
