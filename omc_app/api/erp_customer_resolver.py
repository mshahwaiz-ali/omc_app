"""Canonical ERP Customer resolver for approved OMC customer profiles."""

from __future__ import annotations

import re
from typing import Any

import frappe
from frappe.utils import validate_email_address


def _text(value: Any) -> str:
    return str(value or "").strip()


def _profile_user(profile) -> str:
    return _text(
        getattr(profile, "linked_app_user", None)
        or getattr(profile, "user", None)
    )


def _valid_link(profile) -> str:
    customer = _text(getattr(profile, "linked_erpnext_customer", None))
    if customer and frappe.db.exists("Customer", customer):
        return customer
    return ""


def _normalise_email(value: Any) -> str:
    email = _text(value).lower()
    if not email or "," in email or ";" in email:
        return ""

    try:
        valid = validate_email_address(email, throw=False)
    except Exception:
        return ""

    return email if valid else ""


def _normalise_phone(value: Any) -> str:
    digits = re.sub(r"\D", "", _text(value))
    if not digits:
        return ""

    if digits.startswith("92"):
        local = digits[2:]
    elif digits.startswith("0"):
        local = digits[1:]
    else:
        local = digits

    if len(local) != 10 or not local.startswith("3"):
        return ""

    return f"+92{local}"


def _normalise_tax_id(value: Any) -> str:
    """Canonicalise only safe numeric CNIC/NTN-style identities."""
    value = _text(value)

    if not value or not re.fullmatch(r"[0-9 -]+", value):
        return ""

    digits = re.sub(r"[^0-9]", "", value)

    if len(digits) not in {7, 13}:
        return ""

    return digits


def _normalise_cnic(value: Any) -> str:
    value = _normalise_tax_id(value)
    return value if len(value) == 13 else ""


def _normalise_ntn(value: Any) -> str:
    value = _normalise_tax_id(value)
    return value if len(value) == 7 else ""


def _chunks(values, size=500):
    for start in range(0, len(values), size):
        yield values[start:start + size]


def _customer_identity_rows() -> list[dict[str, Any]]:
    """Build deterministic ERP Customer identities without using user_link.

    Historical client data uses Customer custom fields plus referenced Lead
    identity data. Standard ERP fields are also included for Customers created
    through the current OMC integration.

    A phone is only considered an identity when all available phone sources
    for that Customer agree. Conflicting Customer/Lead phones are deliberately
    excluded from automatic claiming.
    """
    customer_meta = frappe.get_meta("Customer")

    desired_customer_fields = (
        "name",
        "tax_id",
        "email_id",
        "mobile_no",
        "custom_email_address",
        "contact_no",
        "custom_reference_lead",
    )

    customer_fields = [
        fieldname
        for fieldname in desired_customer_fields
        if fieldname == "name" or customer_meta.get_field(fieldname)
    ]

    customers = frappe.get_all(
        "Customer",
        fields=customer_fields,
        order_by="name asc",
        limit_page_length=0,
    )

    lead_names = sorted({
        _text(customer.get("custom_reference_lead"))
        for customer in customers
        if _text(customer.get("custom_reference_lead"))
    })

    leads = {}

    if lead_names:
        lead_meta = frappe.get_meta("Lead")

        desired_lead_fields = (
            "name",
            "mobile_no",
            "custom_cnic",
        )

        lead_fields = [
            fieldname
            for fieldname in desired_lead_fields
            if fieldname == "name" or lead_meta.get_field(fieldname)
        ]

        for batch in _chunks(lead_names):
            for lead in frappe.get_all(
                "Lead",
                filters={"name": ["in", batch]},
                fields=lead_fields,
                limit_page_length=0,
            ):
                leads[lead.name] = lead

    result = []

    for customer in customers:
        lead_name = _text(
            customer.get("custom_reference_lead")
        )
        lead = leads.get(lead_name) or {}

        emails = set()

        for raw_email in (
            customer.get("custom_email_address"),
            customer.get("email_id"),
        ):
            email = _normalise_email(raw_email)
            if email:
                emails.add(email)

        customer_phones = set()

        for raw_phone in (
            customer.get("contact_no"),
            customer.get("mobile_no"),
        ):
            phone = _normalise_phone(raw_phone)
            if phone:
                customer_phones.add(phone)

        lead_phone = _normalise_phone(
            lead.get("mobile_no")
        )

        all_phones = set(customer_phones)

        if lead_phone:
            all_phones.add(lead_phone)

        # A historical phone conflict is not safe ownership evidence.
        safe_phones = (
            all_phones
            if len(all_phones) <= 1
            else set()
        )

        tax_ids = set()

        customer_tax = _normalise_tax_id(
            customer.get("tax_id")
        )
        if customer_tax:
            tax_ids.add(customer_tax)

        lead_cnic = _normalise_cnic(
            lead.get("custom_cnic")
        )
        if lead_cnic:
            tax_ids.add(lead_cnic)

        result.append({
            "customer": customer.name,
            "emails": emails,
            "phones": safe_phones,
            "tax_ids": tax_ids,
        })

    return result


def _customer_matches(profile, user: str) -> list[str]:
    """Return deterministic ERP Customer ownership candidates.

    `user` is intentionally not an ERP Customer identity. The restored client
    database proves Customer.user_link is predominantly shared staff ownership,
    so it must never be used to claim a customer account.

    Rules:
    - one unique identity signal may resolve the Customer;
    - multiple unique signals agreeing on one Customer resolve it;
    - unique signals pointing to different Customers are ambiguous;
    - duplicate/non-unique signals never override a unique signal;
    - if there is no unique signal, all matching duplicates remain ambiguous.
    """
    del user  # Explicitly prevent Customer.user_link identity matching.

    rows = _customer_identity_rows()

    email = _normalise_email(
        getattr(profile, "email", None)
    )
    phone = _normalise_phone(
        getattr(profile, "phone", None)
    )
    cnic = _normalise_cnic(
        getattr(profile, "cnic", None)
    )
    ntn = _normalise_ntn(
        getattr(profile, "ntn", None)
    )

    signal_matches = []

    if email:
        signal_matches.append({
            row["customer"]
            for row in rows
            if email in row["emails"]
        })

    if cnic:
        signal_matches.append({
            row["customer"]
            for row in rows
            if cnic in row["tax_ids"]
        })

    if ntn:
        signal_matches.append({
            row["customer"]
            for row in rows
            if ntn in row["tax_ids"]
        })

    if phone:
        signal_matches.append({
            row["customer"]
            for row in rows
            if phone in row["phones"]
        })

    unique_targets = {
        next(iter(matches))
        for matches in signal_matches
        if len(matches) == 1
    }

    if unique_targets:
        # One deterministic target wins over merely duplicated weak signals.
        # Different deterministic targets must never be guessed between.
        return sorted(unique_targets)

    duplicate_candidates = set()

    for matches in signal_matches:
        duplicate_candidates.update(matches)

    return sorted(duplicate_candidates)


def _default_value(fieldname: str) -> str:
    return _text(frappe.db.get_single_value("Selling Settings", fieldname))


def _set_if_field(doc, fieldname: str, value: Any) -> None:
    if value not in (None, "") and doc.meta.get_field(fieldname):
        doc.set(fieldname, value)


def _set_customer_identity(customer, profile) -> None:
    """Map only safe canonical OMC CNIC/NTN into ERP identity fields."""
    ntn = _normalise_ntn(
        getattr(profile, "ntn", None)
    )
    cnic = _normalise_cnic(
        getattr(profile, "cnic", None)
    )
    identity = ntn or cnic

    if not identity:
        return

    # Standard ERPNext identity field.
    _set_if_field(customer, "tax_id", identity)

    # Support client-specific Customer fields without modifying ERPNext.
    known_fields = {
        "cnic",
        "ntn",
        "cnic_ntn",
        "custom_cnic",
        "custom_ntn",
        "custom_cnic_ntn",
    }

    for field in customer.meta.fields:
        fieldname = _text(getattr(field, "fieldname", None))
        label = _text(getattr(field, "label", None)).lower()
        fieldtype = _text(getattr(field, "fieldtype", None))

        if not fieldname or fieldtype not in {"Data", "Small Text"}:
            continue

        normalized_label = label.replace(" ", "").replace("-", "").replace("_", "")
        identity_label = (
            "cnic" in normalized_label
            or "ntn" in normalized_label
        )

        if fieldname in known_fields or identity_label:
            if not _text(customer.get(fieldname)):
                customer.set(fieldname, identity)


def _link_profile(profile, customer: str) -> None:
    profile.set("linked_erpnext_customer", customer)
    frappe.db.set_value(
        profile.doctype,
        profile.name,
        "linked_erpnext_customer",
        customer,
        update_modified=False,
    )


def _create_customer(profile, user: str):
    full_name = _text(getattr(profile, "full_name", None))
    if not full_name:
        return None, "customer profile has no full name"

    customer_group = _default_value("customer_group")
    territory = _default_value("territory")
    if not customer_group or not territory:
        return None, "ERP Selling Settings require customer group and territory"

    customer = frappe.new_doc("Customer")
    customer.customer_name = full_name
    customer.customer_type = "Individual"
    customer.customer_group = customer_group
    customer.territory = territory

    _set_if_field(customer, "user_link", user)
    _set_if_field(customer, "mobile_no", getattr(profile, "phone", None))
    _set_if_field(customer, "email_id", getattr(profile, "email", None))
    _set_customer_identity(customer, profile)

    customer.insert(ignore_permissions=True)
    return customer, ""


def resolve_profile_customer(
    profile,
    *,
    create_if_missing: bool = True,
    resolution_mode: str | None = None,
) -> dict[str, Any]:
    if not profile:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is required",
        }

    linked = _valid_link(profile)
    if linked:
        return {
            "status": "Resolved",
            "customer": linked,
            "created": False,
            "reason": "",
        }

    if _text(getattr(profile, "approval_status", None)) != "Approved":
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is not approved",
        }

    if not int(getattr(profile, "is_active", 0) or 0):
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is inactive",
        }

    user = _profile_user(profile)
    is_trusted_walk_in = (
        _text(getattr(profile, "customer_origin", None)) == "Walk-in"
        and _text(getattr(profile, "approval_status", None)) == "Approved"
        and int(getattr(profile, "is_active", 0) or 0)
    )

    if not user and not is_trusted_walk_in:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile has no linked app user",
        }

    mode = _text(resolution_mode).lower()

    if mode not in {"", "claim_existing", "new_customer"}:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "unsupported ERP Customer resolution mode",
        }

    matches = _customer_matches(profile, user)

    # Existing-customer claim:
    # - exactly one deterministic ERP Customer may be linked;
    # - ambiguity is never guessed;
    # - absence of a match must never create a new ERP Customer.
    if mode == "claim_existing":
        if len(matches) > 1:
            return {
                "status": "Ambiguous",
                "customer": "",
                "created": False,
                "reason": (
                    "multiple ERP Customers match this customer identity"
                ),
            }

        if len(matches) == 1:
            _link_profile(profile, matches[0])
            return {
                "status": "Resolved",
                "customer": matches[0],
                "created": False,
                "reason": "",
            }

        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": (
                "no existing ERP Customer matches this customer identity"
            ),
        }

    # Genuinely new customer:
    # any historical ERP identity collision blocks automatic creation.
    # The record must be reviewed/reclassified instead of silently linking
    # an old customer or creating a duplicate.
    if mode == "new_customer" and matches:
        return {
            "status": "Existing Customer Detected",
            "customer": "",
            "created": False,
            "reason": (
                "an existing ERP Customer matches this customer identity"
            ),
        }

    # Backward-compatible/default behavior for existing callers.
    if len(matches) > 1:
        return {
            "status": "Ambiguous",
            "customer": "",
            "created": False,
            "reason": "multiple ERP Customers match this customer identity",
        }

    if len(matches) == 1:
        _link_profile(profile, matches[0])
        return {
            "status": "Resolved",
            "customer": matches[0],
            "created": False,
            "reason": "",
        }

    if mode != "new_customer" and not create_if_missing:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "no ERP Customer is linked to this profile",
        }

    customer, error = _create_customer(profile, user)
    if not customer:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": error,
        }

    _link_profile(profile, customer.name)
    return {
        "status": "Created",
        "customer": customer.name,
        "created": True,
        "reason": "",
    }
