import frappe
from frappe.model.document import Document

from omc_app.api import profile_location


class OMCCustomerProfile(Document):
    def before_save(self):
        if self.email:
            self.email = self.email.strip().lower()

        if not self.full_name and self.user:
            self.full_name = (
                frappe.db.get_value(
                    "User",
                    self.user,
                    "full_name",
                )
                or self.user
            )

        if not self.email and self.user and self.user != "Guest":
            self.email = self.user

        profile_location.apply_profile_geolocation(self)

        if self.meta.has_field("work_google_maps_url"):
            values = profile_location.profile_values(self)
            if profile_location.has_work_address(values):
                self.work_google_maps_url = profile_location.google_maps_url(
                    values.get("work_latitude"),
                    values.get("work_longitude"),
                )
            else:
                self.work_google_maps_url = ""
