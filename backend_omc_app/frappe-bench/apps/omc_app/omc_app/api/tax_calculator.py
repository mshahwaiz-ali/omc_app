import json

import frappe
from frappe.utils import flt, now_datetime
from frappe.utils.file_manager import save_file
from frappe.utils.pdf import get_pdf


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
def get_tax_calculation_history(limit=20):
    user = _current_user()
    if user == "Guest":
        frappe.throw("Please login to view calculation history.")

    rows = frappe.get_all(
        "OMC Tax Calculation Log",
        filters={"user": user},
        fields=[
            "name",
            "creation",
            "tax_year",
            "income_type",
            "filer_status",
            "yearly_income",
            "yearly_tax",
            "monthly_tax",
            "effective_tax_rate",
            "linked_service_request",
        ],
        order_by="creation desc",
        limit=flt(limit) or 20,
    )

    return {
        "items": [
            {
                "name": row.name,
                "created_on": str(row.creation or ""),
                "tax_year": row.tax_year or "",
                "income_type": row.income_type or "",
                "filer_status": row.filer_status or "",
                "annual_income": flt(row.yearly_income),
                "estimated_annual_tax": flt(row.yearly_tax),
                "monthly_tax": flt(row.monthly_tax),
                "effective_tax_rate": flt(row.effective_tax_rate),
                "linked_service_request": row.linked_service_request or "",
            }
            for row in rows
        ]
    }


@frappe.whitelist()
def download_tax_estimate_pdf(calculation_log):
    log = _get_owned_calculation_log(calculation_log)
    html = _estimate_pdf_html(log)
    pdf_bytes = get_pdf(html)
    filename = f"{log.name}-tax-estimate.pdf"
    file_doc = save_file(
        filename,
        pdf_bytes,
        "OMC Tax Calculation Log",
        log.name,
        is_private=1,
    )
    return {
        "file_name": file_doc.file_name,
        "file_url": file_doc.file_url,
        "message": "Tax estimate PDF generated successfully.",
    }


@frappe.whitelist()
def share_tax_estimate_with_consultant(calculation_log, note=None):
    log = _get_owned_calculation_log(calculation_log)
    message = note or "Customer shared this tax estimate with OMC consultant from the mobile app."
    comment = _share_comment(log, message)
    log.add_comment("Comment", comment)

    if log.linked_service_request:
        try:
            request = frappe.get_doc("OMC Service Request", log.linked_service_request)
            request.add_comment("Comment", comment)
        except Exception:
            pass

    frappe.db.commit()
    return {
        "message": "Tax estimate shared with OMC consultant.",
        "calculation_log": log.name,
        "linked_service_request": log.linked_service_request or "",
    }


@frappe.whitelist()
def start_service_from_calculation(calculation_log=None, service=None):
    if not calculation_log:
        frappe.throw("Calculation log is required.")

    settings = _get_settings()
    service = service or settings.get("customer_cta_service")
    if not service:
        frappe.throw("No linked tax service is configured.")

    log = _get_owned_calculation_log(calculation_log)
    user = _current_user()

    existing_request = _get_existing_active_service_request(user, service)
    if existing_request:
        if log.linked_service_request != existing_request.name:
            log.linked_service_request = existing_request.name
            log.add_comment("Comment", "Tax estimate linked to existing active tax filing service request.")
            log.save(ignore_permissions=True)
            frappe.db.commit()

        return {
            "service_request": existing_request.name,
            "created_new": False,
            "can_cancel": _can_customer_cancel_service_request(existing_request),
            "message": "Opening your existing tax filing request.",
        }

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
    log.add_comment("Comment", "Tax filing service request created from this calculator estimate.")
    log.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "service_request": request.name,
        "created_new": True,
        "can_cancel": True,
        "message": "Tax filing service request created successfully.",
    }


def _get_existing_active_service_request(user, service):
    if not user or user == "Guest" or not service:
        return None

    closed_statuses = ["Completed", "Closed", "Cancelled", "Rejected", "Expired"]
    rows = frappe.get_all(
        "OMC Service Request",
        filters={
            "requested_by": user,
            "service": service,
            "status": ["not in", closed_statuses],
        },
        fields=["name"],
        order_by="creation desc",
        limit=1,
    )
    return frappe.get_doc("OMC Service Request", rows[0].name) if rows else None


def _can_customer_cancel_service_request(request):
    status = (request.status or "").strip().lower()
    if status not in {"open", "waiting for customer", "waiting for documents"}:
        return False

    if frappe.db.exists("OMC Service Document", {"service_request": request.name, "attachment": ["!=", ""]}):
        return False

    if frappe.db.exists("OMC Service Payment", {"service_request": request.name}):
        return False

    return True


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


def _match_slab(tax_year, income_type, filer_status, taxable_income, allow_fallback=True):
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

    # Safe fallback: if Late Filer / Non-Filer slabs are not configured yet,
    # calculate from Active Filer slabs instead of breaking the customer app.
    if allow_fallback and filer_status != "Active Filer":
        return _match_slab(tax_year, income_type, "Active Filer", taxable_income, allow_fallback=False)

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
    active = _match_slab(tax_year, income_type, "Active Filer", taxable_income, allow_fallback=False)
    non = _match_slab(tax_year, income_type, "Non-Filer", taxable_income, allow_fallback=False)
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


def _get_owned_calculation_log(calculation_log):
    if not calculation_log:
        frappe.throw("Calculation log is required.")
    log = frappe.get_doc("OMC Tax Calculation Log", calculation_log)
    user = _current_user()
    if user != "Administrator" and log.user != user:
        frappe.throw("You cannot access this calculation log.")
    return log


def _get_customer_profile(user):
    if not user or user == "Guest":
        return None
    found = frappe.get_all("OMC Customer Profile", filters={"user": user}, fields=["name"], limit=1)
    return frappe.get_doc("OMC Customer Profile", found[0].name) if found else None


def _service_request_description(log):
    return "Tax estimate submitted from OMC Tax Calculator.\n\nAnnual Income: PKR {0:,.0f}\nEstimated Annual Tax: PKR {1:,.0f}\nMonthly Tax: PKR {2:,.0f}\nEffective Tax Rate: {3:.2f}%".format(
        flt(log.yearly_income), flt(log.yearly_tax), flt(log.monthly_tax), flt(log.effective_tax_rate)
    )


def _share_comment(log, message):
    return "{0}\n\nCalculation Log: {1}\nAnnual Income: PKR {2:,.0f}\nEstimated Annual Tax: PKR {3:,.0f}\nMonthly Tax: PKR {4:,.0f}\nEffective Tax Rate: {5:.2f}%".format(
        message,
        log.name,
        flt(log.yearly_income),
        flt(log.yearly_tax),
        flt(log.monthly_tax),
        flt(log.effective_tax_rate),
    )


def _estimate_pdf_html(log):
    result = _ensure_dict(log.result_json)
    source = _ensure_dict(result.get("source"))
    cta = _ensure_dict(result.get("cta"))
    generated_on = now_datetime().strftime("%Y-%m-%d %H:%M")
    return f"""
    <html>
      <head>
        <style>
          body {{ font-family: Arial, sans-serif; color: #111827; font-size: 13px; }}
          .card {{ border: 1px solid #e5e7eb; border-radius: 12px; padding: 18px; margin-bottom: 14px; }}
          h1 {{ margin: 0 0 8px; font-size: 24px; }}
          h2 {{ margin: 0 0 12px; font-size: 17px; }}
          table {{ width: 100%; border-collapse: collapse; }}
          td {{ padding: 8px 0; border-bottom: 1px solid #f3f4f6; }}
          .label {{ color: #6b7280; }}
          .value {{ text-align: right; font-weight: 700; }}
          .note {{ color: #6b7280; font-size: 12px; line-height: 1.5; }}
        </style>
      </head>
      <body>
        <div class="card">
          <h1>OMC Tax Estimate</h1>
          <div class="note">Generated on {frappe.utils.escape_html(generated_on)} · Estimate only. Final filing may require document review.</div>
        </div>
        <div class="card">
          <h2>Summary</h2>
          <table>
            <tr><td class="label">Tax Year</td><td class="value">{frappe.utils.escape_html(source.get('tax_year') or log.tax_year or '')}</td></tr>
            <tr><td class="label">Income Type</td><td class="value">{frappe.utils.escape_html(log.income_type or '')}</td></tr>
            <tr><td class="label">Filer Status</td><td class="value">{frappe.utils.escape_html(log.filer_status or '')}</td></tr>
            <tr><td class="label">Annual Income</td><td class="value">PKR {flt(log.yearly_income):,.0f}</td></tr>
            <tr><td class="label">Estimated Annual Tax</td><td class="value">PKR {flt(log.yearly_tax):,.0f}</td></tr>
            <tr><td class="label">Monthly Tax</td><td class="value">PKR {flt(log.monthly_tax):,.0f}</td></tr>
            <tr><td class="label">Effective Tax Rate</td><td class="value">{flt(log.effective_tax_rate):.2f}%</td></tr>
          </table>
        </div>
        <div class="card">
          <h2>OMC Guidance</h2>
          <p>{frappe.utils.escape_html(cta.get('title') or 'Need OMC to verify and file this?')}</p>
          <p class="note">This PDF is generated from OMC configured calculator data and is not a final return or legal tax filing document.</p>
        </div>
      </body>
    </html>
    """


def _current_user():
    return (frappe.session.user if getattr(frappe, "session", None) else "Guest") or "Guest"


def _normalize_key(value):
    return (value or "").strip().lower().replace("-", "_").replace(" ", "_")
