import frappe
from frappe.model.document import Document


IMMUTABLE_FIELDS = {
    "referrer_user", "referral_record", "customer_profile", "service_request",
    "service", "qualifying_payment", "qualifying_erp_invoice", "basis_amount",
    "commission_percent_snapshot", "commission_amount", "currency", "earned_on",
    "period_month", "unique_event_key",
}
CONTROLLED_HISTORY_FIELDS = {
    "earning_status", "settlement_reference", "settled_on", "reversed_on",
    "reversal_reason",
}


class OMCReferralCommission(Document):
    def validate(self):
        if frappe.utils.flt(self.basis_amount) <= 0:
            frappe.throw("Commission basis amount must be greater than zero.")
        rate = frappe.utils.flt(self.commission_percent_snapshot, 4)
        if rate <= 0 or rate > 100:
            frappe.throw("Commission percent snapshot must be greater than 0 and at most 100.")
        if frappe.utils.flt(self.commission_amount) <= 0:
            frappe.throw("Commission amount must be greater than zero.")
        if self.earning_status not in {"Earned", "Settled", "Reversed"}:
            frappe.throw("Unsupported commission earning status.")

        previous = self.get_doc_before_save()
        if previous:
            changed = [field for field in IMMUTABLE_FIELDS if self.get(field) != previous.get(field)]
            if changed:
                frappe.throw(
                    "Commission financial snapshots are immutable: " + ", ".join(sorted(changed)),
                    frappe.ValidationError,
                )
            history_changed = [
                field for field in CONTROLLED_HISTORY_FIELDS
                if self.get(field) != previous.get(field)
            ]
            if history_changed and not self.flags.get("allow_commission_status_transition"):
                frappe.throw(
                    "Commission settlement and reversal history may change only through controlled workflows.",
                    frappe.ValidationError,
                )

    def on_trash(self):
        frappe.throw(
            "Referral commission history cannot be deleted. Reverse the earning instead.",
            frappe.ValidationError,
        )
