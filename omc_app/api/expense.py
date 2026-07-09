import json

import frappe

from omc_app.api import mobile


EXPENSE_TYPES = {"Income", "Expense"}
DEFAULT_GUEST_LIMIT = 30

DEFAULT_EXPENSE_CATEGORIES = [
    {"name": "Food", "title": "Food", "transaction_type": "Expense", "icon": "restaurant", "sort_order": 10},
    {"name": "Fuel", "title": "Fuel", "transaction_type": "Expense", "icon": "local_gas_station", "sort_order": 20},
    {"name": "Bills", "title": "Bills", "transaction_type": "Expense", "icon": "receipt", "sort_order": 30},
    {"name": "Rent", "title": "Rent", "transaction_type": "Expense", "icon": "home", "sort_order": 40},
    {"name": "Shopping", "title": "Shopping", "transaction_type": "Expense", "icon": "shopping_bag", "sort_order": 50},
    {"name": "Transport", "title": "Transport", "transaction_type": "Expense", "icon": "directions_car", "sort_order": 60},
    {"name": "Health", "title": "Health", "transaction_type": "Expense", "icon": "health_and_safety", "is_tax_relevant": 1, "sort_order": 70},
    {"name": "Education", "title": "Education", "transaction_type": "Expense", "icon": "school", "is_tax_relevant": 1, "sort_order": 80},
    {"name": "Business", "title": "Business", "transaction_type": "Expense", "icon": "business_center", "business_default": 1, "sort_order": 90},
    {"name": "Tax / Legal", "title": "Tax / Legal", "transaction_type": "Expense", "icon": "gavel", "is_tax_relevant": 1, "sort_order": 100},
    {"name": "Utilities", "title": "Utilities", "transaction_type": "Expense", "icon": "bolt", "sort_order": 110},
    {"name": "Other", "title": "Other", "transaction_type": "Expense", "icon": "category", "sort_order": 999},
    {"name": "Salary", "title": "Salary", "transaction_type": "Income", "icon": "payments", "sort_order": 10},
    {"name": "Business Income", "title": "Business Income", "transaction_type": "Income", "icon": "storefront", "sort_order": 20},
    {"name": "Freelance", "title": "Freelance", "transaction_type": "Income", "icon": "laptop", "sort_order": 30},
    {"name": "Rental Income", "title": "Rental Income", "transaction_type": "Income", "icon": "apartment", "sort_order": 40},
    {"name": "Investment", "title": "Investment", "transaction_type": "Income", "icon": "trending_up", "sort_order": 50},
    {"name": "Other Income", "title": "Other Income", "transaction_type": "Income", "icon": "add_card", "sort_order": 999},
]


def _has_doctype(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _profile():
    profile = mobile._assert_approved_customer()
    if not profile:
        frappe.throw("Approved customer login is required", frappe.PermissionError)
    return profile


def _profile_optional():
    if frappe.session.user == "Guest":
        return None
    try:
        return mobile._assert_approved_customer()
    except Exception:
        return None


def _clean_text(value, fallback=""):
    text = (value or "").strip()
    return text or fallback


def _bool(value):
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (int, float)):
        return 1 if value else 0
    return 1 if str(value or "").strip().lower() in {"1", "true", "yes", "on"} else 0


def _normalise_type(value):
    text = _clean_text(value, "Expense").replace("_", " ").title()
    if text not in EXPENSE_TYPES:
        frappe.throw("transaction_type must be Income or Expense")
    return text


def _parse_entries(entries):
    if isinstance(entries, str):
        try:
            entries = json.loads(entries)
        except Exception:
            frappe.throw("entries must be valid JSON")
    if entries is None:
        return []
    if not isinstance(entries, list):
        frappe.throw("entries must be a list")
    return entries


def _category_to_dict(row):
    return {
        "name": row.get("name"),
        "title": row.get("title") or row.get("category_name") or row.get("name"),
        "transaction_type": row.get("transaction_type") or row.get("type") or "Expense",
        "type": row.get("transaction_type") or row.get("type") or "Expense",
        "icon": row.get("icon") or "category",
        "color": row.get("color") or "",
        "is_tax_relevant": row.get("is_tax_relevant") or 0,
        "business_default": row.get("business_default") or 0,
        "sort_order": row.get("sort_order") or 0,
    }


def _seed_default_categories():
    if not _has_doctype("OMC Expense Category"):
        return

    for category in DEFAULT_EXPENSE_CATEGORIES:
        title = category["title"]
        if frappe.db.exists("OMC Expense Category", title):
            continue
        doc = frappe.new_doc("OMC Expense Category")
        doc.title = title
        doc.transaction_type = category["transaction_type"]
        doc.icon = category.get("icon") or "category"
        doc.color = category.get("color") or ""
        doc.is_default = 1
        doc.is_tax_relevant = category.get("is_tax_relevant") or 0
        doc.business_default = category.get("business_default") or 0
        doc.sort_order = category.get("sort_order") or 0
        doc.enabled = 1
        doc.insert(ignore_permissions=True)


def _ensure_category(title, transaction_type):
    title = _clean_text(title, "Uncategorized")
    if not _has_doctype("OMC Expense Category"):
        return title
    if frappe.db.exists("OMC Expense Category", title):
        return title

    doc = frappe.new_doc("OMC Expense Category")
    doc.title = title
    doc.transaction_type = transaction_type
    doc.icon = "category"
    doc.enabled = 1
    doc.sort_order = 999
    doc.insert(ignore_permissions=True)
    return doc.name


def _entry_to_dict(entry):
    return {
        "id": entry.name,
        "name": entry.name,
        "sync_id": entry.get("sync_id") or entry.name,
        "type": (entry.transaction_type or "Expense").lower(),
        "transaction_type": entry.transaction_type or "Expense",
        "amount": entry.amount or 0,
        "category": entry.category or "Uncategorized",
        "date": str(entry.transaction_date) if entry.transaction_date else "",
        "transaction_date": str(entry.transaction_date) if entry.transaction_date else "",
        "account": entry.account or "Cash",
        "paymentMethod": entry.payment_method or "Cash",
        "payment_method": entry.payment_method or "Cash",
        "merchant": entry.get("merchant") or "",
        "note": entry.note or "",
        "tax_relevant": entry.get("tax_relevant") or 0,
        "business_related": entry.get("business_related") or 0,
        "recurring": entry.get("recurring") or 0,
        "reimbursable": entry.get("reimbursable") or 0,
        "receipt_file": entry.get("receipt_file") or "",
        "source": entry.get("source") or "Mobile",
        "status": entry.get("status") or "Active",
        "created_from_guest": entry.get("created_from_guest") or 0,
        "created_at": str(entry.creation) if entry.creation else "",
        "updated_at": str(entry.modified) if entry.modified else "",
        "synced": True,
    }


def _assert_entry_access(entry_name, profile=None):
    profile = profile or _profile()
    if not entry_name or not frappe.db.exists("OMC Expense Entry", entry_name):
        frappe.throw("Expense entry not found", frappe.DoesNotExistError)

    entry = frappe.get_doc("OMC Expense Entry", entry_name)
    if entry.customer_profile != profile.name and entry.user != frappe.session.user:
        frappe.throw("You do not have permission to access this expense entry", frappe.PermissionError)
    return entry


@frappe.whitelist(allow_guest=True)
def get_expense_config():
    profile = _profile_optional()
    categories = get_expense_categories().get("categories")
    sync_available = bool(profile)
    return {
        "guest_limit": DEFAULT_GUEST_LIMIT,
        "sync_available": sync_available,
        "receipt_upload_available": sync_available,
        "report_available": sync_available,
        "budget_available": sync_available,
        "consultant_sharing_available": sync_available,
        "categories": categories,
    }


@frappe.whitelist(allow_guest=True)
def get_expense_categories():
    if not _has_doctype("OMC Expense Category"):
        return {"categories": DEFAULT_EXPENSE_CATEGORIES, "fallback": True}

    _seed_default_categories()
    rows = frappe.get_all(
        "OMC Expense Category",
        filters={"enabled": 1},
        fields=["name", "title", "transaction_type", "icon", "color", "is_tax_relevant", "business_default", "sort_order"],
        order_by="sort_order asc, title asc",
    )
    frappe.db.commit()

    return {
        "categories": [_category_to_dict(row) for row in rows] or DEFAULT_EXPENSE_CATEGORIES,
        "fallback": not bool(rows),
    }


@frappe.whitelist()
def get_expense_entries(month=None, limit=200, start=0):
    profile = _profile()

    if not _has_doctype("OMC Expense Entry"):
        return {"entries": [], "summary": _summary([]), "fallback": True}

    filters = {"customer_profile": profile.name, "status": ["!=", "Archived"]}
    if month:
        month_start = frappe.utils.get_first_day(month)
        month_end = frappe.utils.get_last_day(month_start)
        filters["transaction_date"] = ["between", [month_start, month_end]]

    rows = frappe.get_all(
        "OMC Expense Entry",
        filters=filters,
        fields=[
            "name",
            "sync_id",
            "user",
            "customer_profile",
            "transaction_type",
            "amount",
            "category",
            "transaction_date",
            "account",
            "payment_method",
            "merchant",
            "note",
            "tax_relevant",
            "business_related",
            "recurring",
            "reimbursable",
            "receipt_file",
            "source",
            "status",
            "created_from_guest",
            "creation",
            "modified",
        ],
        order_by="transaction_date desc, creation desc",
        limit_start=int(start or 0),
        limit_page_length=int(limit or 200),
    )

    entries = [_entry_to_dict(row) for row in rows]
    return {"entries": entries, "summary": _summary(entries), "fallback": False}


@frappe.whitelist()
def create_expense_entry(**kwargs):
    profile = _profile()
    entry = _upsert_entry(kwargs, profile=profile)
    frappe.db.commit()
    return {"created": True, "entry": _entry_to_dict(entry)}


@frappe.whitelist()
def bulk_sync_expense_entries(entries=None, **kwargs):
    profile = _profile()
    entries = _parse_entries(entries or kwargs.get("entries"))
    synced = []
    for payload in entries:
        if isinstance(payload, dict):
            synced.append(_entry_to_dict(_upsert_entry(payload, profile=profile)))
    frappe.db.commit()
    return {"synced": len(synced), "entries": synced, "summary": _summary(synced)}


def _upsert_entry(payload, profile):
    if not _has_doctype("OMC Expense Entry"):
        frappe.throw("Expense sync is not enabled on this backend yet.")

    amount = float(payload.get("amount") or 0)
    if amount <= 0:
        frappe.throw("amount must be greater than zero")

    transaction_type = _normalise_type(payload.get("transaction_type") or payload.get("type"))
    sync_id = _clean_text(payload.get("sync_id") or payload.get("id"))
    existing_name = None
    if sync_id:
        existing_name = frappe.db.get_value(
            "OMC Expense Entry",
            {"customer_profile": profile.name, "sync_id": sync_id},
            "name",
        )

    entry = frappe.get_doc("OMC Expense Entry", existing_name) if existing_name else frappe.new_doc("OMC Expense Entry")
    entry.user = frappe.session.user
    entry.customer_profile = profile.name
    entry.transaction_type = transaction_type
    entry.amount = amount
    entry.category = _ensure_category(payload.get("category"), transaction_type)
    entry.transaction_date = payload.get("transaction_date") or payload.get("date") or frappe.utils.today()
    entry.account = _clean_text(payload.get("account"), "Cash")
    entry.payment_method = _clean_text(payload.get("payment_method") or payload.get("paymentMethod"), "Cash")
    entry.merchant = _clean_text(payload.get("merchant"))
    entry.note = _clean_text(payload.get("note"))
    entry.tax_relevant = _bool(payload.get("tax_relevant"))
    entry.business_related = _bool(payload.get("business_related"))
    entry.recurring = _bool(payload.get("recurring"))
    entry.reimbursable = _bool(payload.get("reimbursable"))
    entry.receipt_file = _clean_text(payload.get("receipt_file") or payload.get("receiptFile"))
    entry.source = _clean_text(payload.get("source"), "Mobile")
    entry.sync_id = sync_id
    entry.status = _clean_text(payload.get("status"), "Active")
    entry.created_from_guest = _bool(payload.get("created_from_guest"))

    if existing_name:
        entry.save(ignore_permissions=True)
    else:
        entry.insert(ignore_permissions=True)
    return entry


@frappe.whitelist()
def update_expense_entry(entry_id=None, name=None, **kwargs):
    profile = _profile()
    entry = _assert_entry_access(entry_id or name, profile=profile)
    payload = {"sync_id": entry.sync_id or entry.name, **kwargs}

    if "amount" in payload:
        amount = float(payload.get("amount") or 0)
        if amount <= 0:
            frappe.throw("amount must be greater than zero")
        entry.amount = amount

    if "transaction_type" in payload or "type" in payload:
        entry.transaction_type = _normalise_type(payload.get("transaction_type") or payload.get("type"))

    if "category" in payload:
        entry.category = _ensure_category(payload.get("category"), entry.transaction_type)

    field_map = {
        "transaction_date": "transaction_date",
        "date": "transaction_date",
        "account": "account",
        "payment_method": "payment_method",
        "paymentMethod": "payment_method",
        "merchant": "merchant",
        "note": "note",
        "tax_relevant": "tax_relevant",
        "business_related": "business_related",
        "recurring": "recurring",
        "reimbursable": "reimbursable",
        "receipt_file": "receipt_file",
        "receiptFile": "receipt_file",
        "source": "source",
        "status": "status",
        "created_from_guest": "created_from_guest",
    }

    check_fields = {"tax_relevant", "business_related", "recurring", "reimbursable", "created_from_guest"}
    for incoming, target in field_map.items():
        if incoming in payload:
            entry.set(target, _bool(payload.get(incoming)) if target in check_fields else payload.get(incoming))

    entry.save(ignore_permissions=True)
    frappe.db.commit()
    return {"updated": True, "entry": _entry_to_dict(entry)}


@frappe.whitelist()
def delete_expense_entry(entry_id=None, name=None):
    profile = _profile()
    entry = _assert_entry_access(entry_id or name, profile=profile)
    entry.status = "Archived"
    entry.save(ignore_permissions=True)
    frappe.db.commit()
    return {"deleted": True, "archived": True, "name": entry.name}


@frappe.whitelist()
def upload_expense_receipt(entry_id=None, file_url=None):
    profile = _profile()
    entry = _assert_entry_access(entry_id, profile=profile)
    if file_url:
        entry.receipt_file = file_url
    elif frappe.request and frappe.request.files:
        uploaded = frappe.request.files.get("file")
        if not uploaded:
            frappe.throw("Missing receipt file")
        saved = frappe.get_doc(
            {
                "doctype": "File",
                "file_name": uploaded.filename,
                "attached_to_doctype": "OMC Expense Entry",
                "attached_to_name": entry.name,
                "content": uploaded.stream.read(),
                "is_private": 1,
            }
        ).insert(ignore_permissions=True)
        entry.receipt_file = saved.file_url
    else:
        frappe.throw("file_url or uploaded receipt file is required")

    entry.save(ignore_permissions=True)
    frappe.db.commit()
    return {"uploaded": True, "entry": _entry_to_dict(entry)}


@frappe.whitelist()
def get_expense_summary(month=None):
    response = get_expense_entries(month=month)
    return response.get("summary") or _summary([])


@frappe.whitelist()
def get_expense_budgets(month=None):
    profile = _profile()
    if not _has_doctype("OMC Expense Budget"):
        return {"budgets": [], "fallback": True}

    filters = {"customer_profile": profile.name, "active": 1}
    if month:
        filters["month"] = frappe.utils.get_first_day(month)

    rows = frappe.get_all(
        "OMC Expense Budget",
        filters=filters,
        fields=["name", "category", "month", "limit_amount", "alert_threshold", "active"],
        order_by="month desc, category asc",
    )
    return {"budgets": rows, "fallback": False}


@frappe.whitelist()
def save_expense_budget(**kwargs):
    profile = _profile()
    if not _has_doctype("OMC Expense Budget"):
        frappe.throw("Expense budgets are not enabled on this backend yet.")

    name = kwargs.get("name")
    budget = frappe.get_doc("OMC Expense Budget", name) if name else frappe.new_doc("OMC Expense Budget")
    if name and budget.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this budget", frappe.PermissionError)

    budget.user = frappe.session.user
    budget.customer_profile = profile.name
    budget.category = kwargs.get("category") or None
    budget.month = frappe.utils.get_first_day(kwargs.get("month") or frappe.utils.today())
    budget.limit_amount = float(kwargs.get("limit_amount") or 0)
    budget.alert_threshold = float(kwargs.get("alert_threshold") or 80)
    budget.active = _bool(kwargs.get("active", 1))

    if name:
        budget.save(ignore_permissions=True)
    else:
        budget.insert(ignore_permissions=True)
    frappe.db.commit()
    return {"saved": True, "budget": budget.as_dict()}


@frappe.whitelist()
def generate_expense_report(month=None):
    profile = _profile()
    summary = get_expense_summary(month=month)
    return {
        "generated": True,
        "status": "Generated",
        "month": str(frappe.utils.get_first_day(month or frappe.utils.today())),
        "customer_profile": profile.name,
        "summary": summary,
        "message": "PDF report generation hook is ready; attach print/PDF workflow in the next report phase.",
    }


@frappe.whitelist()
def share_expense_report_with_consultant(month=None, note=None):
    profile = _profile()
    summary = get_expense_summary(month=month)
    return {
        "shared": True,
        "customer_profile": profile.name,
        "month": str(frappe.utils.get_first_day(month or frappe.utils.today())),
        "note": note or "",
        "summary": summary,
        "message": "Expense summary marked ready for consultant review.",
    }


def _summary(entries):
    income = 0.0
    expenses = 0.0
    tax_relevant_total = 0.0
    business_expense_total = 0.0
    receipts_attached = 0
    recurring_count = 0
    category_totals = {}
    payment_method_totals = {}

    for entry in entries:
        amount = float(entry.get("amount") or 0)
        transaction_type = (entry.get("transaction_type") or entry.get("type") or "").lower()
        if transaction_type == "income":
            income += amount
        else:
            expenses += amount
            category = entry.get("category") or "Uncategorized"
            category_totals[category] = category_totals.get(category, 0) + amount
            if _bool(entry.get("tax_relevant")):
                tax_relevant_total += amount
            if _bool(entry.get("business_related")):
                business_expense_total += amount
        payment_method = entry.get("payment_method") or entry.get("paymentMethod") or "Cash"
        payment_method_totals[payment_method] = payment_method_totals.get(payment_method, 0) + amount
        if entry.get("receipt_file"):
            receipts_attached += 1
        if _bool(entry.get("recurring")):
            recurring_count += 1

    readiness_score = 0
    if entries:
        readiness_score = 20
        if tax_relevant_total:
            readiness_score += 25
        if business_expense_total:
            readiness_score += 15
        if receipts_attached:
            readiness_score += 20
        if income:
            readiness_score += 10
        if recurring_count:
            readiness_score += 10

    readiness_score = min(readiness_score, 100)

    return {
        "income": income,
        "expenses": expenses,
        "balance": income - expenses,
        "transaction_count": len(entries),
        "tax_relevant_total": tax_relevant_total,
        "business_expense_total": business_expense_total,
        "receipts_attached": receipts_attached,
        "recurring_count": recurring_count,
        "readiness_score": readiness_score,
        "readiness_label": _readiness_label(readiness_score),
        "category_totals": category_totals,
        "payment_method_totals": payment_method_totals,
    }


def _readiness_label(score):
    if score >= 80:
        return "Ready for review"
    if score >= 60:
        return "Good"
    if score >= 35:
        return "Improving"
    return "Low"
