import json

import frappe
from frappe.utils import flt


INCOME_TYPES = {
    "salary": "Salary",
    "business": "Business",
    "sole_proprietor": "Business",
    "rental": "Rental",
}

FILER_STATUSES = {
    "active_filer": "Active Filer",
    "late_filer": "Late Filer",
    "non_filer": "Non-Filer",
}


@frappe.whitelist(allow_guest=True)
def get_tax_calculator_config(tax_year=None, income_type=None):
    settings = _get_settings()
    if not settings.get("calculator_enabled"):
        return {"enabled": False, "message": "Tax calculator is currently disabled."}

    user = _current_user()
    if user == "Guest" and not settings.get("allow_guest_calculation"):
        return {"enabled": False, "message": "Please login to use the tax calculator."}

    year = _get_tax_year(tax_year or settings.get("default_tax_year"))
    fields = _get_input_fields(year.name if year else None)

    return {
        "enabled": True,
        "active_tax_year": _tax_year_payload(year),
        "income_types": ["salary", "business", "rental"],
        "filer_status_options": ["active_filer", "late_filer", "non_filer"],
        "simple_fields": [field for field in fields if field.get("mode") == "simple"],
        "advanced_fields": [field for field in fields if field.get("mode") == "advanced"],
        "settings": {
            "show_advanced_mode": bool(settings.get("show_advanced_mode")),
            "show_breakdown": bool(settings.get("show_breakdown")),
            "show_filer_comparison": bool(settings.get("show_filer_comparison")),
            "show_tax_health_score": bool(settings.get("show_tax_health_score")),
            "allow_pdf_for_guest": bool(settings.get("allow_pdf_for_guest")),
            "save_logged_in_calculations": bool(settings.get("save_logged_in_calculations")),
        },
        "disclaimer": settings.get("result_disclaimer") or "Estimate only. Final filing may require document review.",
        "filing_deadline_alert": settings.get("filing_deadline_alert") or "",
        "recommended_next_steps": _parse_json_list(settings.get("recommended_next_steps")),
        "required_documents": _parse_json_list(settings.get("required_documents_json")),
        "cta": _cta_payload(settings, user),
    }


@frappe.whitelist(allow_guest=True)
def calculate_tax(**kwargs):
    data = _extract_payload(kwargs)
    settings = _get_settings()
    if not settings.get("calculator_enabled"):
        frappe.throw("Tax calculator is currently disabled.")

    user = _current_user()
    if user == "Guest" and not settings.get("allow_guest_calculation"):
        frappe.throw("Please login to calculate tax.")

    year = _get_tax_year(data.get("tax_year") or settings.get("default_tax_year"))
    if not year:
        frappe.throw("No published tax year is configured for the calculator.")

    income_type_key = _normalize_key(data.get("income_type") or "salary")
    income_type = INCOME_TYPES.get(income_type_key, "Salary")
    filer_status_key = _normalize_key(data.get("filer_status") or "active_filer")
    filer_status = FILER_STATUSES.get(filer_status_key, "Active Filer")
    income_mode = _normalize_key(data.get("income_mode") or "monthly")
    income_amount = flt(data.get("income_amount") or data.get("monthly_income") or data.get("yearly_income"))

    if income_amount <= 0:
        frappe.throw("Income amount is required.")

    annual_income = income_amount if income_mode == "annual" or data.get("yearly_income") else income_amount * 12
    monthly_income = annual_income / 12
    advanced_inputs = _ensure_dict(data.get("advanced_inputs"))
    adjustments = _apply_adjustments(year.name, income_type, annual_income, advanced_inputs)
    taxable_income = max(0, adjustments["taxable_income"])

    slab = _match_slab(year.name, income_type, filer_status, taxable_income)
    if not slab:
        frappe.throw("No matching tax slab is configured for this income.")

    tax_before_credits = _calculate_slab_tax(taxable_income, slab)
    final_tax = max(0, tax_before_credits - adjustments["credits"])
    monthly_tax = final_tax / 12
    monthly_take_home = monthly_income - monthly_tax
    effective_tax_rate = (final_tax / annual_income * 100) if annual_income else 0

    comparison = None
    if settings.get("show_filer_comparison"):
        comparison = _comparison_payload(year.name, income_type, taxable_income)

    tax_health = None
    if settings.get("show_tax_health_score"):
        tax_health = _tax_health_payload(filer_status, final_tax, advanced_inputs, user)

    insights = _insights_payload(year.name, income_type, filer_status, annual_income)
    result = {
        "annual_income": annual_income,
        "yearly_income": annual_income,
        "monthly_income": monthly_income,
        "taxable_income": taxable_income,
        "estimated_annual_tax": final_tax,
        "yearly_tax": final_tax,
        "monthly_tax": monthly_tax,
        "monthly_take_home": monthly_take_home,
        "monthly_after_tax": monthly_take_home,
        "yearly_after_tax": annual_income - final_tax,
        "effective_tax_rate": effective_tax_rate,
        "breakdown": _breakdown_payload(slab, taxable_income, tax_before_credits, adjustments["credits"], final_tax),
        "comparison": comparison,
        "tax_health": tax_health,
        "insights": insights,
        "recommended_next_steps": _parse_json_list(settings.get("recommended_next_steps")),
        "source": {
            "tax_year": year.title or year.tax_year,
            "verified": bool(year.last_verified_on),
            "last_verified_on": str(year.last_verified_on or ""),
            "public_note": year.public_note or "Based on OMC configured slabs.",
        },
        "cta": _cta_payload(settings, user),
        "is_verified": True,
        "verified": True,
        "note": settings.get("result_disclaimer") or "Estimate only. Final filing may require document review.",
    }

    if user != "Guest" and settings.get("save_logged_in_calculations"):
        result["calculation_log"] = _save_calculation_log(user, year.name, income_type, filer_status, data, result)

    return result


@frappe.whitelist()
def start_service_from_calculation(calculation_log=None, service=None):
    if not calculation_log:
        frappe.throw("Calculation log is required.")

    settings = _get_settings()
    service = service or settings.get("customer_cta_service")
    if not service:
        frappe.throw("No linked tax service is configured.")

    log = frappe.get_doc("OMC Tax Calculation Log", calculation_log)
    user = _current_user()
    if user != "Administrator" and log.user != user:
        frappe.throw("You cannot use this calculation log.")

    profile = _get_customer_profile(user)
    request = frappe.get_doc({
        "doctype": "OMC Service Request",
        "naming_series": "OMC-SR-.YY..MM..DD.-.#####",
        "service": service,
        "title": "Tax Filing Service Request",
        "description": _service_request_description(log),
        "status": "Open",
        "priority": "Medium",
        "customer_profile": profile.name if profile else None,
        "customer_name": profile.full_name if profile else "",
        "requested_by": user,
        "contact_email": profile.email if profile else user,
        "contact_phone": profile.phone if profile else "",
    })
    request.insert(ignore_permissions=True)

    log.linked_service_request = request.name
    log.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "service_request": request.name,
        "message": "Tax filing service request created successfully.",
    }


def _extract_payload(kwargs):
    if len(kwargs) == 1 and isinstance(kwargs.get("data"), (str, dict)):
        return _ensure_dict(kwargs.get("data"))
    return _ensure_dict(kwargs)


def _ensure_dict(value):
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value.strip():
        try:
            return frappe.parse_json(value)
        except Exception:
            try:
                return json.loads(value)
            except Exception:
                return {}
    return {}


def _parse_json_list(value):
    parsed = _ensure_dict(value) if isinstance(value, str) and value.strip().startswith("{") else None
    if parsed and isinstance(parsed.get("items"), list):
        return parsed.get("items")
    if isinstance(value, str) and value.strip().startswith("["):
        try:
            parsed_list = frappe.parse_json(value)
            return parsed_list if isinstance(parsed_list, list) else []
        except Exception:
            return []
    return []


def _get_settings():
    try:
        doc = frappe.get_single("OMC Tax Calculator Settings")
        return doc.as_dict()
    except Exception:
        return {
            "calculator_enabled": 1,
            "allow_guest_calculation": 1,
            "show_advanced_mode": 1,
            "show_breakdown": 1,
            "show_filer_comparison": 1,
            "show_tax_health_score": 1,
            "save_logged_in_calculations": 1,
            "guest_cta_title": "Create account to save this estimate",
            "guest_cta_button": "Create Account",
            "customer_cta_title": "Need OMC to verify and file this?",
            "customer_cta_button": "Start Tax Filing Service",
        }


def _get_tax_year(name=None):
    filters = {"status": "Published", "is_active": 1}
    if name:
        if frappe.db.exists("OMC Tax Year", name):
            doc = frappe.get_doc("OMC Tax Year", name)
            if doc.status == "Published":
                return doc
        filters["tax_year"] = name
    found = frappe.get_all("OMC Tax Year", filters=filters, fields=["name"], order_by="effective_from desc, modified desc", limit=1)
    return frappe.get_doc("OMC Tax Year", found[0].name) if found else None


def _tax_year_payload(year):
    if not year:
        return None
    return {
        "name": year.name,
        "tax_year": year.tax_year,
        "title": year.title or year.tax_year,
        "currency": year.currency or "PKR",
        "verified": bool(year.last_verified_on),
        "last_verified_on": str(year.last_verified_on or ""),
        "public_note": year.public_note or "Based on OMC configured slabs.",
    }


def _get_input_fields(tax_year):
    rows = frappe.get_all(
        "OMC Tax Input Field",
        filters={"is_active": 1},
        fields=["tax_year", "field_key", "label", "input_type", "income_type", "mode", "is_required", "default_value", "options_json", "help_text", "sort_order"],
        order_by="sort_order asc, creation asc",
    )
    fields = []
    for row in rows:
        if tax_year and row.tax_year and row.tax_year != tax_year:
            continue
        fields.append({
            "field_key": row.field_key,
            "label": row.label,
            "input_type": _normalize_key(row.input_type or "number"),
            "income_type": _normalize_key(row.income_type or "all"),
            "mode": _normalize_key(row.mode or "advanced"),
            "is_required": bool(row.is_required),
            "default_value": row.default_value or "",
            "options": _parse_json_list(row.options_json),
            "help_text": row.help_text or "",
            "sort_order": row.sort_order or 0,
        })
    return fields


def _apply_adjustments(tax_year, income_type, annual_income, advanced_inputs):
    taxable_income = annual_income
    credits = 0
    rows = frappe.get_all(
        "OMC Tax Adjustment Rule",
        filters={"tax_year": tax_year, "is_active": 1, "income_type": ["in", [income_type, "All", ""]]},
        fields=["adjustment_key", "adjustment_type", "calculation_type", "max_amount", "rate_percent"],
    )
    for row in rows:
        amount = flt(advanced_inputs.get(row.adjustment_key))
        if row.calculation_type == "Fixed":
            amount = flt(row.max_amount)
        elif row.calculation_type == "Percentage":
            amount = annual_income * flt(row.rate_percent) / 100
        if row.max_amount:
            amount = min(amount, flt(row.max_amount))
        if row.adjustment_type == "Add":
            taxable_income += amount
        elif row.adjustment_type == "Deduct":
            taxable_income -= amount
        elif row.adjustment_type == "Credit":
            credits += amount
    return {"taxable_income": taxable_income, "credits": credits}


def _match_slab(tax_year, income_type, filer_status, taxable_income):
    rows = frappe.get_all(
        "OMC Tax Slab",
        filters={"parent": tax_year, "income_type": income_type, "filer_status": filer_status},
        fields=["name", "from_amount", "to_amount", "fixed_tax", "rate_percent", "amount_over", "label"],
        order_by="sort_order asc, from_amount asc",
    )
    for row in rows:
        from_amount = flt(row.from_amount)
        to_amount = flt(row.to_amount)
        if taxable_income >= from_amount and (not to_amount or taxable_income <= to_amount):
            return row
    return None


def _calculate_slab_tax(taxable_income, slab):
    amount_over = flt(slab.amount_over if slab.amount_over is not None else slab.from_amount)
    return flt(slab.fixed_tax) + max(0, taxable_income - amount_over) * flt(slab.rate_percent) / 100


def _breakdown_payload(slab, taxable_income, tax_before_credits, credits, final_tax):
    return {
        "slab_label": slab.label or f"PKR {flt(slab.from_amount):,.0f} - PKR {flt(slab.to_amount):,.0f}",
        "fixed_tax": flt(slab.fixed_tax),
        "rate_percent": flt(slab.rate_percent),
        "amount_over": flt(slab.amount_over),
        "taxable_income": taxable_income,
        "tax_before_credits": tax_before_credits,
        "credits": credits,
        "final_tax": final_tax,
    }


def _comparison_payload(tax_year, income_type, taxable_income):
    active = _match_slab(tax_year, income_type, "Active Filer", taxable_income)
    non = _match_slab(tax_year, income_type, "Non-Filer", taxable_income)
    if not active or not non:
        return None
    active_tax = _calculate_slab_tax(taxable_income, active)
    non_tax = _calculate_slab_tax(taxable_income, non)
    return {
        "active_filer_tax": active_tax,
        "non_filer_tax": non_tax,
        "possible_difference": max(0, non_tax - active_tax),
    }


def _tax_health_payload(filer_status, final_tax, advanced_inputs, user):
    risk = 0
    reasons = []
    if filer_status != "Active Filer":
        risk += 1
        reasons.append("Filer status should be verified.")
    if final_tax > 0:
        risk += 1
        reasons.append("Estimated tax liability is present.")
    if flt(advanced_inputs.get("tax_already_deducted") or advanced_inputs.get("withholding_tax_paid")) > 0:
        risk += 1
        reasons.append("Keep tax deduction or WHT certificate ready.")
    if user != "Guest":
        profile = _get_customer_profile(user)
        if profile and not getattr(profile, "ntn", None):
            risk += 1
            reasons.append("NTN is missing in customer profile.")
    score = "Low" if risk <= 1 else "Medium" if risk <= 3 else "High"
    return {"score": score, "reason": " ".join(reasons) or "Basic tax readiness looks clear."}


def _insights_payload(tax_year, income_type, filer_status, annual_income):
    rows = frappe.get_all(
        "OMC Tax Result Insight",
        filters={"tax_year": tax_year, "is_active": 1},
        fields=["min_income", "max_income", "filer_status", "income_type", "severity", "title", "message", "action_label", "action_type", "linked_service", "linked_article"],
        order_by="creation asc",
    )
    insights = []
    for row in rows:
        if row.income_type and row.income_type not in (income_type, "All"):
            continue
        if row.filer_status and row.filer_status != filer_status:
            continue
        if row.min_income and annual_income < flt(row.min_income):
            continue
        if row.max_income and annual_income > flt(row.max_income):
            continue
        insights.append({
            "severity": row.severity or "Medium",
            "title": row.title or "Tax guidance",
            "message": row.message or "",
            "action_label": row.action_label or "",
            "action_type": row.action_type or "None",
            "linked_service": row.linked_service or "",
            "linked_article": row.linked_article or "",
        })
    return insights


def _save_calculation_log(user, tax_year, income_type, filer_status, input_data, result):
    profile = _get_customer_profile(user)
    log = frappe.get_doc({
        "doctype": "OMC Tax Calculation Log",
        "user": user,
        "customer": profile.name if profile else None,
        "tax_year": tax_year,
        "income_type": income_type,
        "filer_status": filer_status,
        "input_json": json.dumps(input_data, default=str, indent=2),
        "result_json": json.dumps(result, default=str, indent=2),
        "yearly_income": result.get("annual_income"),
        "yearly_tax": result.get("estimated_annual_tax"),
        "monthly_tax": result.get("monthly_tax"),
        "effective_tax_rate": result.get("effective_tax_rate"),
        "source": "Customer",
        "created_from_app": 1,
    })
    log.insert(ignore_permissions=True)
    return log.name


def _cta_payload(settings, user):
    if user == "Guest":
        return {
            "title": settings.get("guest_cta_title") or "Create account to save this estimate",
            "button": settings.get("guest_cta_button") or "Create Account",
            "linked_service": "",
        }
    return {
        "title": settings.get("customer_cta_title") or "Need OMC to verify and file this?",
        "button": settings.get("customer_cta_button") or "Start Tax Filing Service",
        "linked_service": settings.get("customer_cta_service") or "",
    }


def _get_customer_profile(user):
    if not user or user == "Guest":
        return None
    found = frappe.get_all("OMC Customer Profile", filters={"user": user}, fields=["name"], limit=1)
    return frappe.get_doc("OMC Customer Profile", found[0].name) if found else None


def _service_request_description(log):
    return "Tax estimate submitted from OMC Tax Calculator.\n\nAnnual Income: PKR {0:,.0f}\nEstimated Annual Tax: PKR {1:,.0f}\nMonthly Tax: PKR {2:,.0f}\nEffective Tax Rate: {3:.2f}%".format(
        flt(log.yearly_income), flt(log.yearly_tax), flt(log.monthly_tax), flt(log.effective_tax_rate)
    )


def _current_user():
    return (frappe.session.user if getattr(frappe, "session", None) else "Guest") or "Guest"


def _normalize_key(value):
    return (value or "").strip().lower().replace("-", "_").replace(" ", "_")
