import frappe
from frappe.model.document import Document


class OMCCommissionSettlement(Document):
    def validate(self):
        if self.period_start and self.period_end and self.period_start > self.period_end:
            frappe.throw("Settlement period start cannot be after period end.")
        if not self.earnings:
            frappe.throw("At least one commission earning is required.")

        seen = set()
        total = 0
        for row in self.earnings:
            if row.earning in seen:
                frappe.throw(f"Commission earning {row.earning} is duplicated.")
            seen.add(row.earning)
            earning = frappe.get_doc("OMC Referral Commission", row.earning)
            if earning.referrer_user != self.referrer_user:
                frappe.throw(f"Commission earning {row.earning} belongs to another referrer.")
            if earning.currency != self.currency:
                frappe.throw(f"Commission earning {row.earning} uses another currency.")
            if earning.earning_status != "Earned":
                frappe.throw(f"Commission earning {row.earning} is not payable.")
            row.customer_profile = earning.customer_profile
            row.service_request = earning.service_request
            row.amount = earning.commission_amount
            total += frappe.utils.flt(earning.commission_amount)
        self.total_amount = total

    def on_submit(self):
        from omc_app.api import mobile

        settled_on = frappe.utils.now_datetime()
        for row in self.earnings:
            earning = frappe.get_doc("OMC Referral Commission", row.earning)
            if earning.earning_status != "Earned" or earning.settlement_reference:
                frappe.throw(f"Commission earning {earning.name} is no longer payable.")
            earning.earning_status = "Settled"
            earning.settlement_reference = self.name
            earning.settled_on = settled_on
            earning.flags.allow_commission_status_transition = True
            earning.save(ignore_permissions=True)
            mobile._create_customer_notification(
                recipient_user=earning.referrer_user,
                title="Referral commission settled",
                message=f"Commission {earning.name} was included in settlement {self.name}.",
                notification_type="Commission",
                reference_doctype="OMC Referral Commission",
                reference_name=earning.name,
                mobile_route=f"/my-commissions/{earning.name}",
                event_key=f"commission.settled:{earning.name}:{self.name}",
            )
        self.db_set("settlement_status", "Settled", update_modified=False)
        self.db_set("settled_on", settled_on, update_modified=False)

    def before_cancel(self):
        frappe.throw(
            "Submitted commission settlements cannot be cancelled. Reverse individual earnings with an audit reason.",
            frappe.ValidationError,
        )

    def on_trash(self):
        if self.docstatus:
            frappe.throw("Submitted commission settlements cannot be deleted.")
