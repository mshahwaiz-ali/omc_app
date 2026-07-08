import frappe

from omc_app.api import mobile


EXPENSE_TYPES = {"Income", "Expense"}
DEFAULT_EXPENSE_CATEGORIES = [
    {"name": "Salary", "title": "Salary", "transaction_type": "Income", "sort_order": 1},
    {"name": "Business Income", "title": "Business Income", "transaction_type": "Income", "sort_order": 2},
    {"name": "Food", "title": "Food", "transaction_type": "Expense", "sort_order": 10},
    {"name": "Transport", "title": "Transport", "transaction_type": "Expense", "sort_order": 20},
    {"name": "Bills", "title": "Bills", "transaction_type": "Expense", "sort_order": 30},
    {"name": "Tax", "title": "Tax", "transaction_type": "Expense", "sort_order": 40},
    {"name": "Other", "title": "Other", "transaction_type": "Expense", "sort_order": 999},
]


def _has_doctype(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _profile():
    profile = mobile._assert_approved_customer()
    if not profile:
        frappe.throw("Login is required", frappe.PermissionError)
    return profile


def _clean_text(value, fallback=""):
    text = (value or "").strip()
    return text or fallback


def _normalise_type(value):
    text = _clean_text(value, "Expense").replace("_", " ").title()
    if text not in EXPENSE_TYPES:
        frappe.throw("transaction_type must be Income or Expense")
    return text


def _entry_to_dict(entry):
    return {
        "id": entry.name,
        "name": entry.name,
        "type": (entry.transaction_type or "Expense").lower(),
        "transaction_type": entry.transaction_type or "Expense",
        "amount": entry.amount or 0,
        "category": entry.category or "Uncategorized",
        "date": str(entry.transaction_date) if entry.transaction_date else "",
        "account": entry.account or "Cash",
        "paymentMethod": entry.payment_method or "Cash",
        "payment_method": entry.payment_method or "Cash",
        "note": entry.note or "",
        "created_at": str(entry.creation) if entry.creation else "",
        "updated_at": str(entry.modified) if entry.modified else "",
    }


def _assert_entry_access(entry_name, profile=None):
    profile = profile or _profile()
    if not frappe.db.exists("OMC Expense Entry", entry_name):
        frappe.throw("Expense entry not found", frappe.DoesNotExistError)

    entry = frappe.get_doc("OMC Expense Entry", entry_name)
    if entry.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this expense entry", frappe.PermissionError)
    return entry


@frappe.whitelist()
def get_expense_categories():
    if not _has_doctype("OMC Expense Category"):
        return {"categories": DEFAULT_EXPENSE_CATEGORIES, "fallback": True}

    rows = frappe.get_all(
        "OMC Expense Category",
        filters={"is_active": 1},
        fields=["name", "title", "transaction_type", "sort_order"],
        order_by="sort_order asc, title asc",
    )

    return {
        "categories": [
            {
                "name": row.name,
                "title": row.title or row.name,
                "transaction_type": row.transaction_type or "Expense",
                "sort_order": row.sort_order or 0,
            }
            for row in rows
        ] or DEFAULT_EXPENSE_CATEGORIES,
        "fallback": not bool(rows),
    }


@frappe.whitelist()
def get_expense_entries():
    profile = _profile()

    if not _has_doctype("OMC Expense Entry"):
        return {"entries": [], "summary": _summary([]), "fallback": True}

    rows = frappe.get_all(
        "OMC Expense Entry",
        filters={"customer_profile": profile.name},
        fields=[
            "name",
            "transaction_type",
            "amount",
            "category",
            "transaction_date",
            "account",
            "payment_method",
            "note",
            "creation",
            "modified",
        ],
        order_by="transaction_date desc, creation desc",
    )

    entries = [_entry_to_dict(row) for row in rows]
    return {"entries": entries, "summary": _summary(entries), "fallback": False}


@frappe.whitelist()
def create_expense_entry(**kwargs):
    profile = _profile()

    if not _has_doctype("OMC Expense Entry"):
        frappe.throw("Expense sync is not enabled on this backend yet.")

    amount = float(kwargs.get("amount") or 0)
    if amount <= 0:
        frappe.throw("amount must be greater than zero")

    entry = frappe.new_doc("OMC Expense Entry")
    entry.customer_profile = profile.name
    entry.transaction_type = _normalise_type(kwargs.get("transaction_type") or kwargs.get("type"))
    entry.amount = amount
    entry.category = _clean_text(kwargs.get("category"), "Uncategorized")
    entry.transaction_date = kwargs.get("transaction_date") or kwargs.get("date") or frappe.utils.today()
    entry.account = _clean_text(kwargs.get("account"), "Cash")
    entry.payment_method = _clean_text(kwargs.get("payment_method") or kwargs.get("paymentMethod"), "Cash")
    entry.note = _clean_text(kwargs.get("note"))
    entry.insert(ignore_permissions=True)
    frappe.db.commit()

    return {"created": True, "entry": _entry_to_dict(entry)}


@frappe.whitelist()
def update_expense_entry(entry_id=None, name=None, **kwargs):
    profile = _profile()
    entry = _assert_entry_access(entry_id or name, profile=profile)

    if "amount" in kwargs:
        amount = float(kwargs.get("amount") or 0)
        if amount <= 0:
            frappe.throw("amount must be greater than zero")
        entry.amount = amount

    if "transaction_type" in kwargs or "type" in kwargs:
        entry.transaction_type = _normalise_type(kwargs.get("transaction_type") or kwargs.get("type"))

    field_map = {
        "category": "category",
        "transaction_date": "transaction_date",
        "date": "transaction_date",
        "account": "account",
        "payment_method": "payment_method",
        "paymentMethod": "payment_method",
        "note": "note",
    }

    for incoming, target in field_map.items():
        if incoming in kwargs:
            entry.set(target, kwargs.get(incoming))

    entry.save(ignore_permissions=True)
    frappe.db.commit()

    return {"updated": True, "entry": _entry_to_dict(entry)}


@frappe.whitelist()
def delete_expense_entry(entry_id=None, name=None):
    profile = _profile()
    entry = _assert_entry_access(entry_id or name, profile=profile)
    deleted_name = entry.name
    frappe.delete_doc("OMC Expense Entry", entry.name, ignore_permissions=True)
    frappe.db.commit()

    return {"deleted": True, "name": deleted_name}


@frappe.whitelist()
def get_expense_summary():
    response = get_expense_entries()
    return response.get("summary") or _summary([])


def _summary(entries):
    income = 0.0
    expenses = 0.0

    for entry in entries:
        amount = float(entry.get("amount") or 0)
        transaction_type = (entry.get("transaction_type") or entry.get("type") or "").lower()
        if transaction_type == "income":
            income += amount
        else:
            expenses += amount

    return {
        "income": income,
        "expenses": expenses,
        "balance": income - expenses,
        "transaction_count": len(entries),
    }
