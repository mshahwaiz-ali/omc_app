"""ERP-backed customer business-data projection.

ERP Customer, its primary Contact and the client's existing Customer custom
fields are authoritative for ordinary business data. OMC Customer Profile
remains the workflow/app metadata record and a compatibility projection.

No new ERPNext custom fields are created here.
"""

from __future__ import annotations

import re
from typing import Any

import frappe


PROFILE_DOCTYPE = "OMC Customer Profile"


def _text(value: Any) -> str:
    return str(value or "").strip()


def _has_field(doc, fieldname: str) -> bool:
    return bool(doc and getattr(doc, "meta", None) and doc.meta.has_field(fieldname))


def _field(doc, fieldname: str) -> str:
    if not _has_field(doc, fieldname):
        return ""
    return _text(doc.get(fieldname))


def _normalise_tax(value: Any) -> str:
    return re.sub(r"\D", "", _text(value))


def tax_identity_kind(value: Any) -> str:
    digits = _normalise_tax(value)
    if len(digits) == 13:
        return "cnic"
    if 7 <= len(digits) <= 9:
        return "ntn"
    return ""


def _profile_value(profile, fieldname: str) -> str:
    if not profile or not getattr(profile, "meta", None):
        return ""
    if not profile.meta.has_field(fieldname):
        return ""
    return _text(profile.get(fieldname))


def linked_customer_name(profile) -> str:
    customer = _profile_value(profile, "linked_erpnext_customer")
    if not customer:
        return ""
    if not frappe.db.exists("Customer", customer):
        frappe.throw(
            "OMC Customer Profile is linked to an invalid ERP Customer.",
            frappe.ValidationError,
        )
    return customer


def _contact_is_linked(contact_name: str, customer: str) -> bool:
    return bool(
        contact_name
        and customer
        and frappe.db.exists("Contact", contact_name)
        and frappe.db.exists(
            "Dynamic Link",
            {
                "parenttype": "Contact",
                "parent": contact_name,
                "link_doctype": "Customer",
                "link_name": customer,
            },
        )
    )


def _linked_contact_names(customer: str) -> list[str]:
    if not customer:
        return []
    names = frappe.get_all(
        "Dynamic Link",
        filters={
            "parenttype": "Contact",
            "link_doctype": "Customer",
            "link_name": customer,
        },
        pluck="parent",
        limit_page_length=100,
    )
    return sorted({_text(name) for name in names if _text(name)})


def _primary_contact_name(customer_doc, *, fail_on_ambiguity: bool = False) -> str:
    customer = _text(getattr(customer_doc, "name", None))
    explicit = _field(customer_doc, "customer_primary_contact")
    if explicit:
        if _contact_is_linked(explicit, customer):
            return explicit
        if fail_on_ambiguity:
            frappe.throw(
                "ERP Customer primary Contact is not linked to the Customer.",
                frappe.ValidationError,
            )

    linked = [
        name
        for name in _linked_contact_names(customer)
        if frappe.db.exists("Contact", name)
    ]
    if not linked:
        return ""

    primary = frappe.get_all(
        "Contact",
        filters={
            "name": ["in", linked],
            "is_primary_contact": 1,
        },
        pluck="name",
        limit_page_length=3,
    )
    primary = [_text(name) for name in primary if _text(name)]
    if len(primary) == 1:
        return primary[0]
    if len(primary) > 1:
        if fail_on_ambiguity:
            frappe.throw(
                "ERP Customer has multiple primary Contacts. "
                "Resolve the Contact mapping before editing profile details.",
                frappe.ValidationError,
            )
        return ""

    if len(linked) == 1:
        return linked[0]

    if fail_on_ambiguity:
        frappe.throw(
            "ERP Customer has multiple Contacts but no unique primary Contact.",
            frappe.ValidationError,
        )
    return ""


def _primary_contact(customer_doc):
    name = _primary_contact_name(customer_doc)
    return frappe.get_doc("Contact", name) if name else None


def _primary_address_display(customer_doc) -> str:
    direct = _field(customer_doc, "address")
    if direct:
        return direct

    rendered = _field(customer_doc, "primary_address")
    if rendered:
        return rendered

    address_name = _field(customer_doc, "customer_primary_address")
    if not address_name or not frappe.db.exists("Address", address_name):
        return ""

    address = frappe.get_doc("Address", address_name)
    get_display = getattr(address, "get_display", None)
    if callable(get_display):
        try:
            return _text(get_display())
        except Exception:
            pass

    parts = [
        _field(address, "address_line1"),
        _field(address, "address_line2"),
        _field(address, "city"),
        _field(address, "state"),
        _field(address, "pincode"),
        _field(address, "country"),
    ]
    return ", ".join(part for part in parts if part)


def _tax_display(profile_value: str, canonical_tax: str) -> str:
    if canonical_tax and _normalise_tax(profile_value) == canonical_tax:
        return profile_value
    return canonical_tax


def business_snapshot(profile, *, user: str = "", customer_doc=None) -> dict[str, Any]:
    """Compose live customer business fields from ERP with legacy fallback."""

    customer_name = linked_customer_name(profile)
    if not customer_name:
        return {
            "erp_backed": False,
            "erp_customer": "",
            "erp_customer_type": "",
            "full_name": _profile_value(profile, "full_name"),
            "email": _profile_value(profile, "email") or _text(user),
            "phone": _profile_value(profile, "phone"),
            "address": _profile_value(profile, "address"),
            "company_name": _profile_value(profile, "company_name"),
            "cnic": _profile_value(profile, "cnic"),
            "ntn": _profile_value(profile, "ntn"),
            "tax_id": "",
            "tax_id_kind": "",
        }

    customer = customer_doc or frappe.get_doc("Customer", customer_name)
    contact = _primary_contact(customer)

    contact_email = _field(contact, "email_id") if contact else ""
    contact_mobile = _field(contact, "mobile_no") if contact else ""
    contact_phone = _field(contact, "phone") if contact else ""

    email = (
        contact_email
        or _field(customer, "custom_email_address")
        or _field(customer, "email_id")
        or _profile_value(profile, "email")
        or _text(user)
    )
    phone = (
        contact_mobile
        or _field(customer, "contact_no")
        or _field(customer, "mobile_no")
        or contact_phone
        or _profile_value(profile, "phone")
    )

    tax_id = _normalise_tax(_field(customer, "tax_id"))
    tax_kind = tax_identity_kind(tax_id)

    cnic = _profile_value(profile, "cnic")
    ntn = _profile_value(profile, "ntn")
    if tax_kind == "cnic":
        cnic = _tax_display(cnic, tax_id)
    elif tax_kind == "ntn":
        ntn = _tax_display(ntn, tax_id)

    return {
        "erp_backed": True,
        "erp_customer": customer_name,
        "erp_customer_type": _field(customer, "customer_type"),
        "full_name": _field(customer, "customer_name")
        or _profile_value(profile, "full_name"),
        "email": email,
        "phone": phone,
        "address": _primary_address_display(customer)
        or _profile_value(profile, "address"),
        "company_name": _field(customer, "custom_business_name")
        or _profile_value(profile, "company_name"),
        "cnic": cnic,
        "ntn": ntn,
        "tax_id": tax_id,
        "tax_id_kind": tax_kind,
    }


def _set_profile_projection(profile, values: dict[str, Any]) -> list[str]:
    changed = {}
    for fieldname, value in values.items():
        if not profile.meta.has_field(fieldname):
            continue
        value = _text(value)
        if _text(profile.get(fieldname)) == value:
            continue
        changed[fieldname] = value

    if changed:
        frappe.db.set_value(
            PROFILE_DOCTYPE,
            profile.name,
            changed,
            update_modified=False,
        )
        for fieldname, value in changed.items():
            profile.set(fieldname, value)
    return sorted(changed)


def sync_profile_projection(profile, *, customer_doc=None) -> list[str]:
    """Refresh compatibility fields without touching OMC-only metadata."""

    if isinstance(profile, str):
        profile = frappe.get_doc(PROFILE_DOCTYPE, profile)

    snapshot = business_snapshot(profile, customer_doc=customer_doc)
    if not snapshot["erp_backed"]:
        return []

    values = {
        "full_name": snapshot["full_name"],
        "phone": snapshot["phone"],
        "address": snapshot["address"],
        "company_name": snapshot["company_name"],
    }
    if snapshot["tax_id_kind"] == "cnic":
        values["cnic"] = snapshot["cnic"]
    elif snapshot["tax_id_kind"] == "ntn":
        values["ntn"] = snapshot["ntn"]

    return _set_profile_projection(profile, values)


def _split_name(full_name: str) -> tuple[str, str, str]:
    parts = [part for part in _text(full_name).split() if part]
    if not parts:
        return "Customer", "", ""
    if len(parts) == 1:
        return parts[0], "", ""
    if len(parts) == 2:
        return parts[0], "", parts[1]
    return parts[0], " ".join(parts[1:-1]), parts[-1]


def _set_primary_phone(contact, phone: str) -> bool:
    phone = _text(phone)
    rows = list(contact.get("phone_nos") or [])
    primary_rows = [
        row for row in rows if int(row.get("is_primary_mobile_no") or 0)
    ]

    if not phone:
        changed = False
        for row in primary_rows:
            contact.remove(row)
            changed = True
        return changed

    if primary_rows:
        row = primary_rows[0]
        if _text(row.get("phone")) == phone:
            return False
        row.phone = phone
        return True

    add_phone = getattr(contact, "add_phone", None)
    if callable(add_phone):
        add_phone(phone, is_primary_mobile_no=True)
    else:
        contact.append(
            "phone_nos",
            {"phone": phone, "is_primary_mobile_no": 1},
        )
    return True


def _add_primary_email(contact, email: str) -> None:
    email = _text(email)
    if not email:
        return
    add_email = getattr(contact, "add_email", None)
    if callable(add_email):
        add_email(email, is_primary=True)
    else:
        contact.append("email_ids", {"email_id": email, "is_primary": 1})


def _ensure_phone_contact(customer, *, phone: str, email: str) -> str:
    contact_name = _primary_contact_name(
        customer,
        fail_on_ambiguity=True,
    )
    created = False

    if contact_name:
        contact = frappe.get_doc("Contact", contact_name)
    elif not _text(phone):
        return ""
    else:
        contact = frappe.new_doc("Contact")
        first, middle, last = _split_name(_field(customer, "customer_name"))
        contact.first_name = first
        if contact.meta.has_field("middle_name"):
            contact.middle_name = middle
        if contact.meta.has_field("last_name"):
            contact.last_name = last
        contact.is_primary_contact = 1
        contact.append(
            "links",
            {
                "link_doctype": "Customer",
                "link_name": customer.name,
            },
        )
        _add_primary_email(contact, email)
        created = True

    changed = _set_primary_phone(contact, phone)

    if created:
        contact.insert(ignore_permissions=True)
    elif changed:
        contact.save(ignore_permissions=True)

    if contact.name and _field(customer, "customer_primary_contact") != contact.name:
        frappe.db.set_value(
            "Customer",
            customer.name,
            "customer_primary_contact",
            contact.name,
            update_modified=False,
        )
        customer.customer_primary_contact = contact.name

    return _text(contact.name)


def _apply_tax_identity(customer, payload: dict[str, str]) -> None:
    requested = [
        (fieldname, _normalise_tax(payload.get(fieldname)))
        for fieldname in ("cnic", "ntn")
        if fieldname in payload and _text(payload.get(fieldname))
    ]
    requested = [(fieldname, value) for fieldname, value in requested if value]
    if not requested:
        return

    unique_values = {value for _, value in requested}
    if len(unique_values) > 1:
        frappe.throw(
            "ERP Customer has one Tax ID field; CNIC and NTN cannot both be "
            "changed to different values from self-service.",
            frappe.ValidationError,
        )

    fieldname, requested_value = requested[0]
    expected_kind = fieldname
    if tax_identity_kind(requested_value) != expected_kind:
        frappe.throw("Invalid ERP tax identity format.", frappe.ValidationError)

    current = _normalise_tax(_field(customer, "tax_id"))
    if current and current != requested_value:
        frappe.throw(
            "ERP Customer already has a different Tax ID. "
            "Contact OMC support for a verified correction.",
            frappe.ValidationError,
        )

    if current != requested_value:
        customer.tax_id = requested_value


def update_business_fields(
    profile,
    payload: dict[str, str],
    *,
    user: str = "",
) -> dict[str, Any]:
    """Write app-editable business fields to ERP first.

    Returns erp_backed=False for historical unlinked Profiles so the caller can
    preserve the temporary legacy compatibility path until Phase 10 migration.
    """

    customer_name = linked_customer_name(profile)
    if not customer_name:
        return {"erp_backed": False, "customer": "", "contact": ""}

    customer = frappe.get_doc("Customer", customer_name)
    before = business_snapshot(profile, user=user, customer_doc=customer)

    if "full_name" in payload:
        customer.customer_name = payload["full_name"]

    if "phone" in payload and customer.meta.has_field("contact_no"):
        customer.contact_no = payload["phone"]

    if "address" in payload and customer.meta.has_field("address"):
        customer.address = payload["address"]

    if (
        "company_name" in payload
        and customer.meta.has_field("custom_business_name")
    ):
        customer.custom_business_name = payload["company_name"]

    _apply_tax_identity(customer, payload)

    customer_changed = any(
        _text(before.get(fieldname)) != _text(payload.get(fieldname))
        for fieldname in (
            "full_name",
            "phone",
            "address",
            "company_name",
            "cnic",
            "ntn",
        )
        if fieldname in payload
    )

    if customer_changed:
        customer.save(ignore_permissions=True)

    contact_name = ""
    if "phone" in payload:
        email = (
            _field(customer, "custom_email_address")
            or _field(customer, "email_id")
            or _profile_value(profile, "email")
            or _text(user)
        )
        contact_name = _ensure_phone_contact(
            customer,
            phone=payload["phone"],
            email=email,
        )

    # Refresh after Contact hooks/projections have run.
    customer = frappe.get_doc("Customer", customer_name)
    snapshot = business_snapshot(profile, user=user, customer_doc=customer)

    projection_values = {}
    for fieldname in (
        "full_name",
        "phone",
        "address",
        "company_name",
        "cnic",
        "ntn",
    ):
        if fieldname not in payload:
            continue
        value = snapshot.get(fieldname)
        # When ERP schema cannot represent a second tax identity, keep the
        # legacy value untouched. _apply_tax_identity already prevents an
        # unsafe overwrite.
        if fieldname in {"cnic", "ntn"} and not value:
            value = payload[fieldname]
        projection_values[fieldname] = value

    _set_profile_projection(profile, projection_values)

    return {
        "erp_backed": True,
        "customer": customer_name,
        "contact": contact_name,
        "snapshot": business_snapshot(profile, user=user, customer_doc=customer),
    }
