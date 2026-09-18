"""ERP Customer -> OMC Customer Profile authority and projection.

ERP Customer is the canonical business identity.

OMC Customer Profile is the OMC-specific projection that carries referral,
onboarding, acquisition and application metadata. A business Customer does
not require a User or OMC Customer Account to have a valid Profile.

This module deliberately does not synchronize ordinary editable business
fields. ERP-backed profile read/write projection belongs to the later profile
phase.
"""

from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import erp_customer_resolver, reconciliation_queues


PROFILE_DOCTYPE = "OMC Customer Profile"
DOMAIN = "Identity"
REVIEW_CODES = {"customer_profile_ambiguous"}
QUARANTINE_CODES = {"customer_profile_sync_error"}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _profile_doctype_available() -> bool:
    try:
        return bool(frappe.db.exists("DocType", PROFILE_DOCTYPE))
    except Exception:
        return False


def _linked_profile_names(customer: str) -> list[str]:
    return frappe.get_all(
        PROFILE_DOCTYPE,
        filters={"linked_erpnext_customer": customer},
        pluck="name",
        order_by="name asc",
        limit_page_length=3,
    )


def _event_source_profile():
    """Return the OMC profile that explicitly caused ERP Customer creation.

    The transient flag is set by the OMC Profile -> Customer resolver while
    inserting a new ERP Customer. It prevents the Customer hook from creating
    a second Profile during that same transaction.
    """

    name = _text(
        getattr(
            getattr(frappe, "flags", None),
            "omc_customer_profile_source",
            None,
        )
    )

    if not name or not frappe.db.exists(PROFILE_DOCTYPE, name):
        return None

    return frappe.get_doc(PROFILE_DOCTYPE, name)


def _record_value(record, fieldname: str):
    getter = getattr(record, "get", None)

    if callable(getter):
        return getter(fieldname)

    return getattr(record, fieldname, None)


def _customer_prefilter_identity(customer_doc) -> dict[str, set[str]]:
    """Build cheap identity evidence for one ERP Customer only.

    This is only a candidate prefilter. Final ownership still goes through
    the existing deterministic Profile -> ERP Customer resolver.
    """

    emails: set[str] = set()
    phones: set[str] = set()
    tax_ids: set[str] = set()

    for raw_email in (
        _record_value(customer_doc, "custom_email_address"),
        _record_value(customer_doc, "email_id"),
    ):
        value = erp_customer_resolver._normalise_email(raw_email)
        if value:
            emails.add(value)

    for raw_phone in (
        _record_value(customer_doc, "contact_no"),
        _record_value(customer_doc, "mobile_no"),
    ):
        value = erp_customer_resolver._normalise_phone(raw_phone)
        if value:
            phones.add(value)

    value = erp_customer_resolver._normalise_tax_id(
        _record_value(customer_doc, "tax_id")
    )
    if value:
        tax_ids.add(value)

    lead_name = _text(
        _record_value(
            customer_doc,
            "custom_reference_lead",
        )
    )

    if lead_name and frappe.db.exists("Lead", lead_name):
        lead_meta = frappe.get_meta("Lead")

        lead_fields = [
            fieldname
            for fieldname in ("mobile_no", "custom_cnic")
            if lead_meta.get_field(fieldname)
        ]

        lead = (
            frappe.db.get_value(
                "Lead",
                lead_name,
                lead_fields,
                as_dict=True,
            )
            if lead_fields
            else None
        ) or {}

        lead_phone = erp_customer_resolver._normalise_phone(
            lead.get("mobile_no")
        )

        if lead_phone:
            phones.add(lead_phone)

        lead_tax = erp_customer_resolver._normalise_cnic(
            lead.get("custom_cnic")
        )

        if lead_tax:
            tax_ids.add(lead_tax)

    return {
        "emails": emails,
        "phones": phones,
        "tax_ids": tax_ids,
    }


def _profile_intersects_customer_identity(
    profile,
    identity: dict[str, set[str]],
) -> bool:
    email = erp_customer_resolver._normalise_email(
        _record_value(profile, "email")
    )
    phone = erp_customer_resolver._normalise_phone(
        _record_value(profile, "phone")
    )
    cnic = erp_customer_resolver._normalise_cnic(
        _record_value(profile, "cnic")
    )
    ntn = erp_customer_resolver._normalise_ntn(
        _record_value(profile, "ntn")
    )

    return bool(
        (email and email in identity["emails"])
        or (phone and phone in identity["phones"])
        or (cnic and cnic in identity["tax_ids"])
        or (ntn and ntn in identity["tax_ids"])
    )


def _unlinked_profile_resolution(
    customer: str,
    *,
    customer_doc=None,
) -> dict[str, Any]:
    """Find deterministic unlinked Profile candidates efficiently.

    Do not run the full ERP Customer matching scan once per OMC Profile.

    First prefilter against identity from this one ERP Customer. Only Profiles
    with actual identity overlap reach the existing global deterministic
    resolver.
    """

    customer_doc = customer_doc or frappe.get_doc(
        "Customer",
        customer,
    )

    identity = _customer_prefilter_identity(
        customer_doc
    )

    if not any(identity.values()):
        return {
            "status": "Pending Configuration",
            "profile": "",
            "profile_candidates": [],
            "reason": (
                "ERP Customer has no deterministic identity "
                "for an unlinked Profile claim"
            ),
        }

    profiles = frappe.get_all(
        PROFILE_DOCTYPE,
        fields=[
            "name",
            "linked_erpnext_customer",
            "email",
            "phone",
            "cnic",
            "ntn",
        ],
        order_by="name asc",
        limit_page_length=0,
    )

    likely_profiles = []

    for profile in profiles:
        if _text(
            _record_value(
                profile,
                "linked_erpnext_customer",
            )
        ):
            continue

        if _profile_intersects_customer_identity(
            profile,
            identity,
        ):
            likely_profiles.append(profile)

    if not likely_profiles:
        return {
            "status": "Pending Configuration",
            "profile": "",
            "profile_candidates": [],
            "reason": "no linked OMC Customer Profile exists",
        }

    # One ERP Customer identity snapshot is reused for every candidate.
    # This avoids an O(Profile x Customer) database/query pattern.
    identity_rows = (
        erp_customer_resolver
        ._customer_identity_rows()
    )

    deterministic: list[str] = []
    ambiguous: list[str] = []

    for profile in likely_profiles:
        matches = erp_customer_resolver._customer_matches(
            profile,
            "",
            identity_rows=identity_rows,
        )

        if matches == [customer]:
            deterministic.append(profile.name)
        elif customer in matches:
            ambiguous.append(profile.name)

    contenders = sorted(
        set(deterministic + ambiguous)
    )

    if len(deterministic) == 1 and not ambiguous:
        return {
            "status": "Resolved",
            "profile": deterministic[0],
            "profile_candidates": deterministic,
            "reason": "",
        }

    if contenders:
        return {
            "status": "Ambiguous",
            "profile": "",
            "profile_candidates": contenders,
            "reason": (
                "multiple or non-unique OMC Customer Profile "
                "identities may refer to this ERP Customer"
            ),
        }

    return {
        "status": "Pending Configuration",
        "profile": "",
        "profile_candidates": [],
        "reason": "no linked OMC Customer Profile exists",
    }


def _create_business_profile(customer_doc):
    """Create the minimum OMC projection for an ERP business Customer.

    No User, password or Customer Account is created here.

    Full ERP Customer / Contact / Address field projection deliberately
    remains outside Phase 1.
    """

    customer = _text(getattr(customer_doc, "name", None))
    full_name = _text(
        getattr(customer_doc, "customer_name", None)
    ) or customer

    if not customer or not full_name:
        frappe.throw(
            "ERP Customer identity is incomplete.",
            frappe.ValidationError,
        )

    profile = frappe.new_doc(PROFILE_DOCTYPE)
    profile.full_name = full_name
    profile.linked_erpnext_customer = customer

    # Authentication identity intentionally does not exist yet.
    if profile.meta.has_field("user"):
        profile.user = None

    if profile.meta.has_field("linked_app_user"):
        profile.linked_app_user = None

    if profile.meta.has_field("register_as"):
        profile.register_as = "Customer"

    if profile.meta.has_field("customer_type"):
        profile.customer_type = "Customer"

    if profile.meta.has_field("customer_origin"):
        profile.customer_origin = "Staff Created"

    if profile.meta.has_field("onboarding_mode"):
        profile.onboarding_mode = "Imported Existing"

    if profile.meta.has_field("acquisition_source"):
        profile.acquisition_source = "Existing"

    if profile.meta.has_field("manual_customer_status"):
        profile.manual_customer_status = "Unregistered"

    # Existing ERP Customer means a valid business customer. App activation
    # remains an entirely separate lifecycle.
    profile.customer_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1

    profile.insert(ignore_permissions=True)
    return profile


def resolve_for_erp_customer(
    customer: str,
    *,
    create_if_missing: bool = False,
    customer_doc=None,
) -> dict[str, Any]:
    """Resolve the one OMC Profile belonging to an ERP Customer.

    Resolution order:
    1. exact existing ERP Customer link;
    2. explicit OMC source Profile during OMC-created Customer insertion;
    3. deterministic unlinked Profile identity;
    4. optionally create a business-only Profile.

    Ambiguity is never guessed.
    """

    customer = _text(
        customer
        or getattr(customer_doc, "name", None)
    )

    if not customer:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "profile": "",
            "created": False,
            "reason": "ERP Customer is required",
        }

    if not frappe.db.exists("Customer", customer):
        return {
            "status": "Pending Configuration",
            "customer": customer,
            "profile": "",
            "created": False,
            "reason": "ERP Customer does not exist",
        }

    if not _profile_doctype_available():
        return {
            "status": "Pending Configuration",
            "customer": customer,
            "profile": "",
            "created": False,
            "reason": "OMC Customer Profile is not available",
        }

    linked = _linked_profile_names(customer)

    if len(linked) > 1:
        return {
            "status": "Ambiguous",
            "customer": customer,
            "profile": "",
            "created": False,
            "profile_candidates": linked,
            "reason": (
                "multiple OMC Customer Profiles are linked to this ERP Customer"
            ),
        }

    if len(linked) == 1:
        return {
            "status": "Resolved",
            "customer": customer,
            "profile": linked[0],
            "created": False,
            "reason": "",
        }

    source_profile = _event_source_profile()

    if source_profile:
        source_customer = _text(
            getattr(
                source_profile,
                "linked_erpnext_customer",
                None,
            )
        )

        if source_customer and source_customer != customer:
            return {
                "status": "Ambiguous",
                "customer": customer,
                "profile": "",
                "created": False,
                "profile_candidates": [source_profile.name],
                "reason": (
                    "source OMC Customer Profile is already linked "
                    "to another ERP Customer"
                ),
            }

        if not source_customer:
            erp_customer_resolver._link_profile(
                source_profile,
                customer,
            )

        return {
            "status": "Resolved",
            "customer": customer,
            "profile": source_profile.name,
            "created": False,
            "reason": "",
        }

    existing = _unlinked_profile_resolution(
        customer,
        customer_doc=customer_doc,
    )

    if existing["status"] == "Ambiguous":
        return {
            **existing,
            "customer": customer,
            "created": False,
        }

    if existing["status"] == "Resolved":
        profile = frappe.get_doc(
            PROFILE_DOCTYPE,
            existing["profile"],
        )

        erp_customer_resolver._link_profile(
            profile,
            customer,
        )

        return {
            "status": "Resolved",
            "customer": customer,
            "profile": profile.name,
            "created": False,
            "reason": "",
        }

    if not create_if_missing:
        return {
            "status": "Pending Configuration",
            "customer": customer,
            "profile": "",
            "created": False,
            "reason": "no OMC Customer Profile is linked",
        }

    customer_doc = customer_doc or frappe.get_doc(
        "Customer",
        customer,
    )

    profile = _create_business_profile(customer_doc)

    return {
        "status": "Created",
        "customer": customer,
        "profile": profile.name,
        "created": True,
        "reason": "",
    }


def _queue_customer_review(
    *,
    customer: str,
    source_version: str,
    candidate_count: int,
) -> None:
    try:
        reconciliation_queues.open_human_review(
            domain=DOMAIN,
            source_doctype="Customer",
            source_name=customer,
            source_version=source_version,
            reason_code="customer_profile_ambiguous",
            safe_evidence={
                "candidate_count": candidate_count,
            },
        )
    except Exception:
        frappe.log_error(
            frappe.get_traceback(),
            "OMC Customer/Profile review queue failure",
        )


def _queue_customer_quarantine(
    *,
    customer: str,
    source_version: str,
    exception_type: str,
) -> None:
    try:
        reconciliation_queues.open_technical_quarantine(
            domain=DOMAIN,
            source_doctype="Customer",
            source_name=customer,
            source_version=source_version,
            failure_code="customer_profile_sync_error",
            safe_evidence={
                "exception_type": exception_type,
            },
        )
    except Exception:
        frappe.log_error(
            frappe.get_traceback(),
            "OMC Customer/Profile quarantine queue failure",
        )


def sync_from_erp_customer(doc, method=None):
    """Customer doc-event bridge.

    Clean ERP Customers immediately gain an OMC business Profile. App
    activation is deliberately not created here.

    OMC synchronization problems do not corrupt or fabricate ERP Customer
    state. Ambiguous cases fail closed into the reconciliation review queue.
    """

    del method

    customer = _text(getattr(doc, "name", None))
    if not customer:
        return None

    source_version = _text(
        getattr(doc, "modified", None)
    )

    savepoint = "omc_customer_profile_sync"
    frappe.db.savepoint(savepoint)

    try:
        result = resolve_for_erp_customer(
            customer,
            create_if_missing=True,
            customer_doc=doc,
        )
    except Exception as exc:
        frappe.db.rollback(save_point=savepoint)

        frappe.log_error(
            frappe.get_traceback(),
            f"OMC Customer/Profile sync failed: {customer}",
        )

        _queue_customer_quarantine(
            customer=customer,
            source_version=source_version,
            exception_type=type(exc).__name__,
        )

        return {
            "status": "Pending Configuration",
            "customer": customer,
            "profile": "",
            "created": False,
            "reason": "customer/profile synchronization failed",
        }

    if result.get("status") == "Ambiguous":
        _queue_customer_review(
            customer=customer,
            source_version=source_version,
            candidate_count=len(
                result.get("profile_candidates") or []
            ),
        )
        return result

    if result.get("status") in {"Resolved", "Created"}:
        try:
            reconciliation_queues.resolve_source_queues(
                domain=DOMAIN,
                source_doctype="Customer",
                source_name=customer,
                review_reason_codes=REVIEW_CODES,
                quarantine_failure_codes=QUARANTINE_CODES,
                resolution_note=(
                    "ERP Customer and OMC Customer Profile mapping resolved."
                ),
            )
        except Exception:
            frappe.log_error(
                frappe.get_traceback(),
                "OMC Customer/Profile queue cleanup failure",
            )

    return result
