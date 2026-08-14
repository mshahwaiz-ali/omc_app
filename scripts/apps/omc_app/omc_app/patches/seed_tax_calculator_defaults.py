import json

import frappe


DEFAULT_FIELDS = [
    {
        "field_key": "bonus_income",
        "label": "Bonus / additional annual income",
        "input_type": "Number",
        "income_type": "Salary",
        "mode": "Advanced",
        "help_text": "Add annual bonus or one-time salary income if applicable.",
        "sort_order": 10,
    },
    {
        "field_key": "tax_already_deducted",
        "label": "Tax already deducted",
        "input_type": "Number",
        "income_type": "Salary",
        "mode": "Advanced",
        "help_text": "Add annual salary tax already deducted by employer.",
        "sort_order": 20,
    },
    {
        "field_key": "other_income",
        "label": "Other income",
        "input_type": "Number",
        "income_type": "All",
        "mode": "Advanced",
        "help_text": "Freelance, profit, side income, or other taxable income.",
        "sort_order": 30,
    },
    {
        "field_key": "approved_deductions",
        "label": "Zakat / donation / approved deductions",
        "input_type": "Number",
        "income_type": "All",
        "mode": "Advanced",
        "help_text": "Only add deductions allowed by the relevant tax rules.",
        "sort_order": 40,
    },
    {
        "field_key": "business_turnover",
        "label": "Business turnover",
        "input_type": "Number",
        "income_type": "Business",
        "mode": "Advanced",
        "help_text": "Annual turnover before deductible business expenses.",
        "sort_order": 50,
    },
    {
        "field_key": "deductible_expenses",
        "label": "Deductible expenses",
        "input_type": "Number",
        "income_type": "Business",
        "mode": "Advanced",
        "help_text": "Business or rental expenses that can be deducted.",
        "sort_order": 60,
    },
    {
        "field_key": "withholding_tax_paid",
        "label": "Withholding tax paid",
        "input_type": "Number",
        "income_type": "All",
        "mode": "Advanced",
        "help_text": "WHT already paid that should reduce final payable tax.",
        "sort_order": 70,
    },
    {
        "field_key": "rental_annual_income",
        "label": "Rental annual income",
        "input_type": "Number",
        "income_type": "Rental",
        "mode": "Advanced",
        "help_text": "Annual rental income if different from the main amount.",
        "sort_order": 80,
    },
    {
        "field_key": "province_city",
        "label": "Province / city",
        "input_type": "Text",
        "income_type": "All",
        "mode": "Advanced",
        "help_text": "Useful for future provincial or city-specific handling.",
        "sort_order": 90,
    },
]


def execute():
    if not frappe.db.exists("DocType", "OMC Tax Calculator Settings"):
        return

    settings = frappe.get_single("OMC Tax Calculator Settings")
    settings.calculator_enabled = 1
    settings.allow_guest_calculation = 1
    settings.show_advanced_mode = 1
    settings.show_breakdown = 1
    settings.show_filer_comparison = 1
    settings.show_tax_health_score = 1
    settings.save_logged_in_calculations = 1
    settings.result_disclaimer = "Estimate only. Final filing may require document review."
    settings.verified_badge_label = "Verified slabs"
    settings.guest_cta_title = "Create account to save this estimate"
    settings.guest_cta_button = "Create Account"
    settings.customer_cta_title = "Need OMC to verify and file this?"
    settings.customer_cta_button = "Start Tax Filing Service"
    settings.recommended_next_steps = json.dumps([
        "Verify your filer status.",
        "Keep salary certificate, bank statement, or income proof ready.",
        "Start OMC Tax Filing service before the deadline.",
    ], indent=2)
    settings.required_documents_json = json.dumps([
        "CNIC",
        "NTN or filer status proof",
        "Salary certificate or bank statement",
        "Tax deduction / WHT certificate if available",
    ], indent=2)
    settings.save(ignore_permissions=True)

    if not frappe.db.exists("DocType", "OMC Tax Input Field"):
        return

    for row in DEFAULT_FIELDS:
        if frappe.db.exists("OMC Tax Input Field", row["field_key"]):
            continue
        doc = frappe.get_doc({
            "doctype": "OMC Tax Input Field",
            "is_active": 1,
            "is_required": 0,
            "default_value": "",
            "options_json": "[]",
            **row,
        })
        doc.insert(ignore_permissions=True)
