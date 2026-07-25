import frappe

from omc_app.api import mobile

PROFILE_FIELD_LIMITS = {
    "full_name": 140,
    "name": 140,
    "phone": 40,
    "mobile": 40,
    "cnic": 40,
    "ntn": 40,
    "company_name": 140,
    "company": 140,
}


def _bounded_kwargs(kwargs):
    data = dict(kwargs or {})
    if "email" in data:
        frappe.throw(
            "Account email cannot be changed from profile settings.",
            frappe.ValidationError,
        )

    for fieldname, max_length in PROFILE_FIELD_LIMITS.items():
        if fieldname not in data:
            continue
        value = data.get(fieldname)
        if value is not None and not isinstance(value, (str, int, float)):
            frappe.throw(f"{fieldname} must be text", frappe.ValidationError)
        text = str(value or "").strip()
        if len(text) > max_length:
            frappe.throw(
                f"{fieldname} must be {max_length} characters or fewer",
                frappe.ValidationError,
            )
        data[fieldname] = text
    return data


@frappe.whitelist()
def update_profile(**kwargs):
    return mobile.update_profile(**_bounded_kwargs(kwargs))


@frappe.whitelist()
def update_contact_info(**kwargs):
    return mobile.update_contact_info(**_bounded_kwargs(kwargs))
