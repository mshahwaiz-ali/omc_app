from __future__ import annotations

import hashlib
import re
from collections import Counter, defaultdict

import frappe
from frappe.utils import validate_email_address


CUSTOMER_FIELDS = (
    "name",
    "customer_name",
    "tax_id",
    "custom_email_address",
    "contact_no",
    "custom_reference_lead",
)

LEAD_FIELDS = (
    "name",
    "mobile_no",
    "custom_cnic",
)


def _text(value) -> str:
    return str(value or "").strip()


def _normalise_email(value) -> str:
    email = _text(value).lower()
    if not email:
        return ""

    # Customer identity must contain one real email address, not a list.
    if "," in email or ";" in email:
        return ""

    try:
        valid = validate_email_address(email, throw=False)
    except Exception:
        return ""

    return email if valid else ""


def _normalise_phone(value) -> str:
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


def _normalise_cnic(value) -> str:
    digits = re.sub(r"\D", "", _text(value))
    return digits if len(digits) == 13 else ""


def _normalise_tax_id(value) -> str:
    """Return only supported numeric CNIC/NTN-style ERP tax identities."""
    value = _text(value)
    if not value or not re.fullmatch(r"[0-9 -]+", value):
        return ""

    digits = re.sub(r"[^0-9]", "", value)
    return digits if len(digits) in {7, 13} else ""


def _chunks(values, size=500):
    for start in range(0, len(values), size):
        yield values[start:start + size]


def _load_customers():
    return frappe.get_all(
        "Customer",
        fields=list(CUSTOMER_FIELDS),
        order_by="name asc",
        limit_page_length=0,
    )


def _load_leads(customers):
    lead_names = sorted({
        _text(row.get("custom_reference_lead"))
        for row in customers
        if _text(row.get("custom_reference_lead"))
    })

    result = {}

    for batch in _chunks(lead_names):
        for row in frappe.get_all(
            "Lead",
            filters={"name": ["in", batch]},
            fields=list(LEAD_FIELDS),
            limit_page_length=0,
        ):
            result[row.name] = row

    return result


def _identity_rows():
    customers = _load_customers()
    leads = _load_leads(customers)

    rows = []

    for customer in customers:
        lead_name = _text(customer.get("custom_reference_lead"))
        lead = leads.get(lead_name) or {}

        email = _normalise_email(
            customer.get("custom_email_address")
        )

        customer_phone = _normalise_phone(
            customer.get("contact_no")
        )

        lead_phone = _normalise_phone(
            lead.get("mobile_no")
        )

        cnic = _normalise_cnic(
            lead.get("custom_cnic")
        )

        tax_id = _normalise_tax_id(
            customer.get("tax_id")
        )

        phone_conflict = bool(
            customer_phone
            and lead_phone
            and customer_phone != lead_phone
        )

        resolved_phone = customer_phone or lead_phone

        rows.append({
            "customer": customer.name,
            "customer_name": _text(customer.get("customer_name")),
            "lead": lead_name,
            "email": email,
            "cnic": cnic,
            "tax_id": tax_id,
            "customer_phone": customer_phone,
            "lead_phone": lead_phone,
            "resolved_phone": resolved_phone,
            "phone_source": (
                "customer"
                if customer_phone
                else "lead"
                if lead_phone
                else ""
            ),
            "phone_conflict": phone_conflict,
        })

    return rows


def _classify():
    rows = _identity_rows()

    email_counts = Counter(
        row["email"] for row in rows if row["email"]
    )
    cnic_counts = Counter(
        row["cnic"] for row in rows if row["cnic"]
    )
    phone_counts = Counter(
        row["resolved_phone"]
        for row in rows
        if row["resolved_phone"]
    )
    tax_counts = Counter(
        row.get("tax_id", "")
        for row in rows
        if row.get("tax_id")
    )

    for row in rows:
        email = row["email"]
        cnic = row["cnic"]
        phone = row["resolved_phone"]
        tax_id = row.get("tax_id", "")

        # Preserve existing identity priority. Customer.tax_id is deliberately
        # the final deterministic fallback, never a replacement for the
        # established email/CNIC/phone rules.
        if email and email_counts[email] == 1:
            row["classification"] = "unique_email"
            row["review_reason"] = ""
            continue

        if cnic and cnic_counts[cnic] == 1:
            row["classification"] = "unique_cnic"
            row["review_reason"] = ""
            continue

        if (
            phone
            and phone_counts[phone] == 1
            and not row["phone_conflict"]
        ):
            row["classification"] = "unique_safe_phone"
            row["review_reason"] = ""
            continue

        if tax_id and tax_counts[tax_id] == 1:
            row["classification"] = "unique_tax_id"
            row["review_reason"] = ""
            continue

        row["classification"] = "identity_review"

        if not email and not cnic and not phone and not tax_id:
            row["review_reason"] = "no_identity"
            continue

        reasons = []

        if email and email_counts[email] > 1:
            reasons.append("duplicate_email")

        if cnic and cnic_counts[cnic] > 1:
            reasons.append("duplicate_cnic")

        if phone and phone_counts[phone] > 1:
            reasons.append("duplicate_phone")

        if row["phone_conflict"]:
            reasons.append("customer_lead_phone_conflict")

        if tax_id and tax_counts[tax_id] > 1:
            reasons.append("duplicate_tax_id")

        row["review_reason"] = (
            "+".join(reasons)
            if reasons
            else "unresolved_identity_conflict"
        )

    # Keep the historical four-value contract so existing callers do not
    # require a broad migration API change.
    return rows, email_counts, cnic_counts, phone_counts


def dry_run():
    """Read-only customer migration identity analysis.

    This function intentionally performs no inserts, updates, deletes,
    commits, password changes, activation creation, or profile creation.
    """
    rows, email_counts, cnic_counts, phone_counts = _classify()

    tax_counts = Counter(
        row.get("tax_id", "")
        for row in rows
        if row.get("tax_id")
    )

    classifications = Counter(
        row["classification"] for row in rows
    )

    review_rows = [
        row for row in rows
        if row["classification"] == "identity_review"
    ]

    review_reasons = Counter(
        row["review_reason"] for row in review_rows
    )

    safely_identifiable = (
        classifications["unique_email"]
        + classifications["unique_cnic"]
        + classifications["unique_safe_phone"]
        + classifications["unique_tax_id"]
    )
    activation_ready_import = classifications["unique_email"]
    deferred_claim_on_signup = (
        classifications["unique_cnic"]
        + classifications["unique_safe_phone"]
        + classifications["unique_tax_id"]
    )

    return {
        "read_only": True,
        "total_customers": len(rows),

        # Backward-compatible broad identity-discovery count.
        # This does NOT mean every row will receive an OMC profile.
        "auto_migratable": safely_identifiable,
        "safely_identifiable": safely_identifiable,

        # Only customers with one unique real legacy email are safe for
        # pre-created Imported Existing profiles + email activation.
        "activation_ready_import": activation_ready_import,

        # Deterministic CNIC/phone/tax-only identities remain in ERP and
        # are claimed later through verified signup + reviewed resolution.
        "deferred_claim_on_signup": deferred_claim_on_signup,

        "identity_review": classifications["identity_review"],

        "classification": {
            "unique_email": classifications["unique_email"],
            "unique_cnic_fallback": classifications["unique_cnic"],
            "unique_safe_phone": classifications["unique_safe_phone"],
            "unique_tax_id_fallback": classifications["unique_tax_id"],
            "identity_review": classifications["identity_review"],
        },

        "identity_diagnostics": {
            "valid_email_customers": sum(
                1 for row in rows if row["email"]
            ),
            "unique_email_identity_customers": sum(
                1
                for row in rows
                if row["email"]
                and email_counts[row["email"]] == 1
            ),
            "customers_on_duplicate_valid_email": sum(
                1
                for row in rows
                if row["email"]
                and email_counts[row["email"]] > 1
            ),
            "distinct_duplicate_valid_emails": sum(
                1 for count in email_counts.values() if count > 1
            ),

            "valid_cnic_customers": sum(
                1 for row in rows if row["cnic"]
            ),
            "unique_cnic_identity_customers": sum(
                1
                for row in rows
                if row["cnic"]
                and cnic_counts[row["cnic"]] == 1
            ),
            "customers_on_duplicate_cnic": sum(
                1
                for row in rows
                if row["cnic"]
                and cnic_counts[row["cnic"]] > 1
            ),

            "valid_tax_id_customers": sum(
                1 for row in rows if row.get("tax_id")
            ),
            "unique_tax_id_identity_customers": sum(
                1
                for row in rows
                if row.get("tax_id")
                and tax_counts[row["tax_id"]] == 1
            ),
            "customers_on_duplicate_tax_id": sum(
                1
                for row in rows
                if row.get("tax_id")
                and tax_counts[row["tax_id"]] > 1
            ),

            "valid_phone_customers": sum(
                1 for row in rows if row["resolved_phone"]
            ),
            "unique_phone_identity_customers": sum(
                1
                for row in rows
                if row["resolved_phone"]
                and phone_counts[row["resolved_phone"]] == 1
            ),
            "customers_on_duplicate_phone": sum(
                1
                for row in rows
                if row["resolved_phone"]
                and phone_counts[row["resolved_phone"]] > 1
            ),

            "lead_phone_fallback_customers": sum(
                1
                for row in rows
                if not row["customer_phone"] and row["lead_phone"]
            ),
            "customer_lead_phone_conflicts": sum(
                1 for row in rows if row["phone_conflict"]
            ),

            "no_usable_identity": sum(
                1
                for row in rows
                if not row["email"]
                and not row["cnic"]
                and not row["resolved_phone"]
                and not row.get("tax_id")
            ),
        },

        "review_reason_counts": dict(
            sorted(review_reasons.items())
        ),

        # Names/reasons only; don't dump customer PII into normal dry-run output.
        "review_samples": [
            {
                "customer": row["customer"],
                "lead": row["lead"],
                "reason": row["review_reason"],
            }
            for row in review_rows[:20]
        ],
    }



def _synthetic_user_email(customer: str) -> str:
    digest = hashlib.sha256(
        f"omc-customer:{_text(customer)}".encode("utf-8")
    ).hexdigest()[:24]

    return f"omc-import-{digest}@customer.invalid"


def preflight():
    """Read-only profile-only customer migration preflight."""
    rows, _, _, _ = _classify()
    context = _build_apply_context()

    result = {
        "read_only": True,
        "mode": "profile_only",
        "total_customers": len(rows),
        "auto_migratable": 0,
        "safely_identifiable": 0,
        "activation_ready_import": 0,
        "deferred_claim_on_signup": 0,
        "identity_review": 0,
        "profile_only_migratable": 0,
        "create_customer_profile": 0,
        "reuse_customer_profile": 0,
        "user_accounts_to_create": 0,
        "blocker_counts": Counter(),
        "warning_counts": Counter(),
        "blocked_samples": [],
    }

    for row in rows:
        if row["classification"] == "identity_review":
            result["identity_review"] += 1
            continue

        result["auto_migratable"] += 1
        result["safely_identifiable"] += 1

        # CNIC/phone/tax-only historical identities must not receive an
        # email-less profile. They are claimed through the explicit
        # Existing Customer Claim signup path instead.
        if row["classification"] != "unique_email":
            result["deferred_claim_on_signup"] += 1
            continue

        result["activation_ready_import"] += 1
        plan = _plan_apply_row(row, context)

        for warning in plan["warnings"]:
            result["warning_counts"][warning] += 1

        if plan["blockers"]:
            for blocker in plan["blockers"]:
                result["blocker_counts"][blocker] += 1

            if len(result["blocked_samples"]) < 25:
                result["blocked_samples"].append({
                    "customer": row["customer"],
                    "classification": row["classification"],
                    "blockers": plan["blockers"],
                })

            continue

        result["profile_only_migratable"] += 1

        if plan["existing_profile"]:
            result["reuse_customer_profile"] += 1
        else:
            result["create_customer_profile"] += 1

    result["blocker_counts"] = dict(
        sorted(result["blocker_counts"].items())
    )
    result["warning_counts"] = dict(
        sorted(result["warning_counts"].items())
    )

    return result

def blocker_details():
    """Read-only detail report for auto-migration collision cases."""
    from collections import defaultdict
    from omc_app.setup.roles import ACTIVE_STAFF_ROLES, SYSTEM_ROLE

    rows, _, _, _ = _classify()
    auto_rows = [
        row for row in rows
        if row["classification"] != "identity_review"
    ]

    users = frappe.get_all(
        "User",
        fields=["name", "email", "enabled", "user_type", "mobile_no"],
        limit_page_length=0,
    )
    users_by_name = {row.name: row for row in users}

    roles_by_user = defaultdict(set)
    for assignment in frappe.get_all(
        "Has Role",
        fields=["parent", "role"],
        limit_page_length=0,
    ):
        roles_by_user[assignment.parent].add(assignment.role)

    internal_roles = set(ACTIVE_STAFF_ROLES) | {SYSTEM_ROLE}

    users_by_identity = defaultdict(set)
    users_by_phone = defaultdict(set)

    for user in users:
        for value in (user.name, user.get("email")):
            key = _text(value).lower()
            if key:
                users_by_identity[key].add(user.name)

        phone = _normalise_phone(user.get("mobile_no"))
        if phone:
            users_by_phone[phone].add(user.name)

    profiles = frappe.get_all(
        "OMC Customer Profile",
        fields=[
            "name",
            "user",
            "linked_app_user",
            "email",
            "phone",
            "cnic",
            "linked_erpnext_customer",
        ],
        limit_page_length=0,
    )
    profiles_by_name = {row.name: row for row in profiles}

    profiles_by_customer = defaultdict(set)
    profiles_by_identity = defaultdict(set)
    profiles_by_cnic = defaultdict(set)
    profiles_by_phone = defaultdict(set)

    for profile in profiles:
        customer = _text(profile.get("linked_erpnext_customer"))
        if customer:
            profiles_by_customer[customer].add(profile.name)

        for value in (
            profile.get("user"),
            profile.get("linked_app_user"),
            profile.get("email"),
        ):
            key = _text(value).lower()
            if key:
                profiles_by_identity[key].add(profile.name)

        cnic = _normalise_cnic(profile.get("cnic"))
        if cnic:
            profiles_by_cnic[cnic].add(profile.name)

        phone = _normalise_phone(profile.get("phone"))
        if phone:
            profiles_by_phone[phone].add(profile.name)

    blocked = []

    for row in auto_rows:
        target_email = (
            row["email"]
            if row["classification"] == "unique_email"
            else _synthetic_user_email(row["customer"])
        )
        target_key = target_email.lower()

        matching_users = sorted(
            users_by_identity.get(target_key, set())
        )

        phone_users = sorted(
            users_by_phone.get(row["resolved_phone"], set())
            if row["resolved_phone"]
            else []
        )

        candidate_profiles = set(
            profiles_by_customer.get(row["customer"], set())
        )
        candidate_profiles.update(
            profiles_by_identity.get(target_key, set())
        )

        if row["cnic"]:
            candidate_profiles.update(
                profiles_by_cnic.get(row["cnic"], set())
            )

        if row["resolved_phone"]:
            candidate_profiles.update(
                profiles_by_phone.get(row["resolved_phone"], set())
            )

        unlinked_profiles = sorted(
            name
            for name in candidate_profiles
            if not _text(
                profiles_by_name[name].get("linked_erpnext_customer")
            )
        )

        internal_users = sorted(
            name
            for name in matching_users
            if (
                users_by_name[name].user_type == "System User"
                or roles_by_user[name].intersection(internal_roles)
            )
        )

        reasons = []
        if internal_users:
            reasons.append("internal_user_identity")
        if phone_users:
            reasons.append("mobile_collision")
        if unlinked_profiles:
            reasons.append("unlinked_profile")

        if not reasons:
            continue

        blocked.append({
            "customer": row["customer"],
            "classification": row["classification"],
            "reasons": reasons,
            "matching_users": [
                {
                    "user": name,
                    "enabled": int(users_by_name[name].enabled or 0),
                    "user_type": users_by_name[name].user_type,
                    "roles": sorted(roles_by_user[name]),
                }
                for name in matching_users
            ],
            "phone_collision_users": [
                {
                    "user": name,
                    "enabled": int(users_by_name[name].enabled or 0),
                    "user_type": users_by_name[name].user_type,
                    "roles": sorted(roles_by_user[name]),
                }
                for name in phone_users
            ],
            "unlinked_profiles": unlinked_profiles,
        })

    return {
        "read_only": True,
        "blocked_auto_customers": len(blocked),
        "records": blocked,
    }



APPLY_CONFIRMATION = "APPLY_CUSTOMER_MIGRATION"


def _target_user_email(row) -> str:
    if row["classification"] == "unique_email":
        return row["email"]
    return _synthetic_user_email(row["customer"])


def _build_apply_context():
    from omc_app.setup.roles import ACTIVE_STAFF_ROLES, SYSTEM_ROLE

    users = frappe.get_all(
        "User",
        fields=["name", "email", "enabled", "user_type", "mobile_no"],
        limit_page_length=0,
    )
    users_by_name = {row.name: row for row in users}

    roles_by_user = defaultdict(set)
    for assignment in frappe.get_all(
        "Has Role",
        fields=["parent", "role"],
        limit_page_length=0,
    ):
        roles_by_user[assignment.parent].add(assignment.role)

    users_by_identity = defaultdict(set)
    users_by_phone = defaultdict(set)

    for user in users:
        for value in (user.name, user.get("email")):
            key = _text(value).lower()
            if key:
                users_by_identity[key].add(user.name)

        phone = _normalise_phone(user.get("mobile_no"))
        if phone:
            users_by_phone[phone].add(user.name)

    profiles = frappe.get_all(
        "OMC Customer Profile",
        fields=[
            "name",
            "user",
            "linked_app_user",
            "email",
            "phone",
            "cnic",
            "linked_erpnext_customer",
            "customer_status",
            "approval_status",
            "is_active",
        ],
        limit_page_length=0,
    )

    profiles_by_name = {row.name: row for row in profiles}
    profiles_by_customer = defaultdict(set)
    profiles_by_identity = defaultdict(set)
    profiles_by_cnic = defaultdict(set)
    profiles_by_phone = defaultdict(set)

    for profile in profiles:
        customer = _text(profile.get("linked_erpnext_customer"))
        if customer:
            profiles_by_customer[customer].add(profile.name)

        for value in (
            profile.get("user"),
            profile.get("linked_app_user"),
            profile.get("email"),
        ):
            key = _text(value).lower()
            if key:
                profiles_by_identity[key].add(profile.name)

        cnic = _normalise_cnic(profile.get("cnic"))
        if cnic:
            profiles_by_cnic[cnic].add(profile.name)

        phone = _normalise_phone(profile.get("phone"))
        if phone:
            profiles_by_phone[phone].add(profile.name)

    return {
        "users_by_name": users_by_name,
        "roles_by_user": roles_by_user,
        "users_by_identity": users_by_identity,
        "users_by_phone": users_by_phone,
        "profiles_by_name": profiles_by_name,
        "profiles_by_customer": profiles_by_customer,
        "profiles_by_identity": profiles_by_identity,
        "profiles_by_cnic": profiles_by_cnic,
        "profiles_by_phone": profiles_by_phone,
        "internal_roles": set(ACTIVE_STAFF_ROLES) | {SYSTEM_ROLE},
    }


def _canonical_profile_candidates(row, target_email, context):
    if row["classification"] == "unique_email":
        return set(
            context["profiles_by_identity"].get(
                target_email.lower(),
                set(),
            )
        )

    if row["classification"] == "unique_cnic":
        return set(
            context["profiles_by_cnic"].get(
                row["cnic"],
                set(),
            )
        )

    if row["classification"] == "unique_safe_phone":
        return set(
            context["profiles_by_phone"].get(
                row["resolved_phone"],
                set(),
            )
        )

    return set()


def _plan_apply_row(row, context):
    target_email = _target_user_email(row)
    target_key = target_email.lower()

    blockers = []
    warnings = []

    # User identities are activation-time concerns only.
    # Bulk ERP migration must never create, convert, or mutate Users.
    candidate_users = set(
        context["users_by_identity"].get(target_key, set())
    )

    existing_user = (
        next(iter(candidate_users))
        if len(candidate_users) == 1
        else None
    )

    if len(candidate_users) > 1:
        warnings.append("activation_multiple_users_for_identity")

    elif existing_user:
        user_row = context["users_by_name"][existing_user]
        roles = context["roles_by_user"].get(existing_user, set())

        if (
            user_row.user_type == "System User"
            or roles.intersection(context["internal_roles"])
        ):
            blockers.append(
                "activation_existing_internal_user_identity"
            )
        else:
            warnings.append(
                "activation_existing_user_identity"
            )

    direct_profiles = set(
        context["profiles_by_customer"].get(
            row["customer"],
            set(),
        )
    )

    canonical_profiles = _canonical_profile_candidates(
        row,
        target_email,
        context,
    )

    exact_linked = {
        name
        for name in direct_profiles
        if _text(
            context["profiles_by_name"][name].get(
                "linked_erpnext_customer"
            )
        ) == row["customer"]
    }

    other_identity_profiles = canonical_profiles - exact_linked

    conflicting_linked = {
        name
        for name in other_identity_profiles
        if _text(
            context["profiles_by_name"][name].get(
                "linked_erpnext_customer"
            )
        )
        and _text(
            context["profiles_by_name"][name].get(
                "linked_erpnext_customer"
            )
        ) != row["customer"]
    }

    unlinked_identity_profiles = {
        name
        for name in other_identity_profiles
        if not _text(
            context["profiles_by_name"][name].get(
                "linked_erpnext_customer"
            )
        )
    }

    if len(exact_linked) > 1:
        blockers.append("multiple_profiles_for_customer")

    if conflicting_linked:
        blockers.append(
            "profile_identity_linked_to_other_customer"
        )

    if unlinked_identity_profiles:
        blockers.append(
            "existing_unlinked_profile_identity"
        )

    existing_profile = (
        next(iter(exact_linked))
        if len(exact_linked) == 1
        else None
    )

    if row["resolved_phone"]:
        phone_users = set(
            context["users_by_phone"].get(
                row["resolved_phone"],
                set(),
            )
        )

        if existing_user:
            phone_users.discard(existing_user)

        if phone_users:
            warnings.append(
                "activation_existing_user_mobile_collision"
            )

    # Only a UNIQUE real ERP email is eligible for bulk profile import.
    # CNIC/phone/tax-only rows are deferred to claim-on-signup and should
    # never normally reach this planning function.
    profile_email = (
        target_email
        if row["classification"] == "unique_email"
        else ""
    )

    return {
        "target_email": target_email,
        "profile_email": profile_email,
        "existing_user": existing_user,
        "existing_profile": existing_profile,
        "blockers": sorted(set(blockers)),
        "warnings": sorted(set(warnings)),
    }

def _create_or_reuse_user(*args, **kwargs):
    """Bulk customer migration must never create or mutate Frappe Users."""
    frappe.throw(
        "Customer migration is profile-only. "
        "Frappe User creation belongs to the secure activation flow.",
        frappe.ValidationError,
    )

def _create_or_reuse_profile(row, plan):
    existing_profile = plan["existing_profile"]

    if existing_profile:
        profile = frappe.get_doc(
            "OMC Customer Profile",
            existing_profile,
        )

        changed = False

        safe_fill = {
            "email": plan.get("profile_email") or "",
            "full_name": row["customer_name"] or row["customer"],
            "phone": row["resolved_phone"],
            "cnic": row["cnic"],
            "onboarding_mode": "Imported Existing",
        }

        for fieldname, value in safe_fill.items():
            if not value or not profile.meta.has_field(fieldname):
                continue

            # Existing application/profile information always wins.
            if _text(profile.get(fieldname)):
                continue

            profile.set(fieldname, value)
            changed = True

        if not profile.linked_erpnext_customer:
            profile.linked_erpnext_customer = row["customer"]
            changed = True

        # Never clear or replace an existing User/app link and never
        # downgrade an already-active customer profile.
        if changed:
            profile.save(ignore_permissions=True)

        return profile, "reused"

    profile = frappe.new_doc("OMC Customer Profile")

    profile.full_name = row["customer_name"] or row["customer"]
    profile.email = plan.get("profile_email") or ""
    profile.linked_erpnext_customer = row["customer"]

    # Authentication identity is deliberately absent until activation.
    if profile.meta.has_field("user"):
        profile.user = None

    if profile.meta.has_field("linked_app_user"):
        profile.linked_app_user = None

    if row["resolved_phone"]:
        profile.phone = row["resolved_phone"]

    if row["cnic"]:
        profile.cnic = row["cnic"]

    if profile.meta.has_field("register_as"):
        profile.register_as = "Customer"

    if profile.meta.has_field("customer_type"):
        profile.customer_type = "Customer"

    if profile.meta.has_field("customer_origin"):
        profile.customer_origin = "Imported"

    if profile.meta.has_field("onboarding_mode"):
        profile.onboarding_mode = "Imported Existing"

    if profile.meta.has_field("acquisition_source"):
        profile.acquisition_source = "Existing"

    if profile.meta.has_field("manual_customer_status"):
        profile.manual_customer_status = "Unregistered"

    # Existing ERP customers are already trusted business customers.
    # Authentication/app activation remains a separate lifecycle.
    profile.customer_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1

    profile.insert(ignore_permissions=True)

    return profile, "created"

def apply(
    confirm=None,
    limit=0,
    batch_size=100,
    commit=True,
):
    """Idempotently migrate safely-resolved ERP Customers to profiles.

    Safety rules:
    - Identity-review customers are never mutated.
    - No Frappe User is created, enabled, disabled, converted, or modified.
    - No password is created or changed.
    - Ambiguous/conflicting Customer Profiles are never guessed.
    - Existing linked profile/app identity always wins.
    - New imported profiles are Active + Approved business records.
    - App User creation/linking is deferred to secure customer activation.
    """

    if str(confirm or "") != APPLY_CONFIRMATION:
        frappe.throw(
            "Explicit customer migration confirmation is required.",
            frappe.ValidationError,
        )

    try:
        limit = max(0, int(limit or 0))
        batch_size = max(1, int(batch_size or 100))
    except (TypeError, ValueError):
        frappe.throw(
            "limit and batch_size must be integers.",
            frappe.ValidationError,
        )

    if isinstance(commit, str):
        commit = commit.strip().lower() not in {
            "0",
            "false",
            "no",
            "off",
        }
    else:
        commit = bool(commit)

    rows, _, _, _ = _classify()
    context = _build_apply_context()

    result = {
        "confirmation": APPLY_CONFIRMATION,
        "commit": commit,
        "mode": "profile_only",
        "total_customers": len(rows),
        "safely_identifiable": 0,
        "activation_ready_import": 0,
        "deferred_claim_on_signup_skipped": 0,
        "identity_review_skipped": 0,
        "safe_rows_migrated": 0,
        "user_accounts_created": 0,
        "profiles_created": 0,
        "profiles_reused": 0,
        "blocker_counts": Counter(),
        "warning_counts": Counter(),
        "blocked_samples": [],
        "change_samples": [],
    }

    migrated_since_commit = 0

    for row in rows:
        if row["classification"] == "identity_review":
            result["identity_review_skipped"] += 1
            continue

        result["safely_identifiable"] += 1

        # This is the critical fail-closed boundary:
        # only unique-email customers may ever enter the bulk profile
        # creation path. Other deterministic identities are deferred.
        if row["classification"] != "unique_email":
            result["deferred_claim_on_signup_skipped"] += 1
            continue

        result["activation_ready_import"] += 1
        plan = _plan_apply_row(row, context)

        if plan["blockers"]:
            for reason in plan["blockers"]:
                result["blocker_counts"][reason] += 1

            if len(result["blocked_samples"]) < 25:
                result["blocked_samples"].append({
                    "customer": row["customer"],
                    "classification": row["classification"],
                    "blockers": plan["blockers"],
                })

            continue

        if limit and result["safe_rows_migrated"] >= limit:
            break

        for warning in plan["warnings"]:
            result["warning_counts"][warning] += 1

        profile, profile_action = _create_or_reuse_profile(
            row,
            plan,
        )

        result[f"profiles_{profile_action}"] += 1
        result["safe_rows_migrated"] += 1
        migrated_since_commit += 1

        if len(result["change_samples"]) < 20:
            result["change_samples"].append({
                "customer": row["customer"],
                "classification": row["classification"],
                "profile": profile.name,
                "profile_action": profile_action,
                "profile_email": profile.email or "",
                "user": profile.user or "",
                "linked_app_user": (
                    profile.get("linked_app_user") or ""
                ),
                "warnings": plan["warnings"],
            })

        if commit and migrated_since_commit >= batch_size:
            frappe.db.commit()
            migrated_since_commit = 0

    if commit and migrated_since_commit:
        frappe.db.commit()

    result["blocker_counts"] = dict(
        sorted(result["blocker_counts"].items())
    )
    result["warning_counts"] = dict(
        sorted(result["warning_counts"].items())
    )

    return result

