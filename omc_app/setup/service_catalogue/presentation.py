from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.service_catalogue.manifest import SERVICES


DEFAULT_ASSIGNMENT_ROLE = "Employee"
PRESENTATION_FIELDS = (
    "short_description",
    "description",
    "support_message",
    "default_assignment_role",
)

# Customer-facing copy is deliberately source controlled. It explains the
# service and its value without asserting an outcome, deadline, legal position,
# or commercial term that the underlying service data does not establish.
SERVICE_PRESENTATION: dict[str, dict[str, str]] = {
    "7e-exemption-certificate": {
        "short_description": "Prepare a clear, well-supported 7E exemption request with the right property and tax evidence.",
        "description": "Property-related exemption requests can slow down when ownership records or supporting evidence are incomplete. OMC helps organize the relevant property, tax and supporting documents into a clear submission so avoidable gaps and follow-ups are reduced before the case moves forward.",
        "support_message": "Unsure which property or tax evidence applies? OMC support can help you prepare the right documents before submission.",
    },
    "advocacy-service-hearing-with-commissioner": {
        "short_description": "Get structured preparation and professional support for a Commissioner hearing or tax matter.",
        "description": "A hearing is easier to manage when the facts, notices and supporting records are organized before the appearance. OMC helps structure the case file, identify the documents that matter and prepare the engagement so your position can be presented clearly and professionally.",
        "support_message": "Share the hearing notice and available case documents; OMC support can guide you on the next preparation steps.",
    },
    "aop-filling": {
        "short_description": "Organize and file your AOP tax return with the business records and tax evidence kept in order.",
        "description": "AOP filings often depend on several business and financial records matching each other. OMC helps bring the relevant accounts, bank information and tax evidence together so the return can be prepared consistently and avoid preventable documentation gaps.",
        "support_message": "Need help identifying the records required for your AOP filing? OMC support can guide you before you submit.",
    },
    "aop-firm-registration-service": {
        "short_description": "Set up your AOP or partnership with a guided registration process and properly organized partner information.",
        "description": "Starting a partnership is smoother when partner details, the partnership deed, business address and ownership information are aligned from the beginning. OMC helps organize the registration package so you can move from setup to a properly documented business structure with fewer avoidable delays.",
        "support_message": "Questions about partners, the deed or business-address documents? OMC support can help you prepare the registration pack.",
    },
    "business-tax-filing": {
        "short_description": "File your business tax return with financial, banking and asset information organized in one guided process.",
        "description": "Business tax filing becomes difficult when income, banking, investments, property or other financial information is scattered. OMC helps structure the relevant records and filing information so the return is prepared from a clearer, more complete picture of the business and its tax information.",
        "support_message": "Not sure which business or personal records belong in the filing? OMC support can help you prepare the right information.",
    },
    "family-contribute": {
        "short_description": "Document family contributions clearly so the related tax filing is supported by consistent financial evidence.",
        "description": "Family contributions can create confusion when the source and supporting financial records are not documented clearly. OMC helps organize the relevant banking, asset and supporting information so the filing has a cleaner evidence trail and fewer avoidable questions later.",
        "support_message": "Need help showing the source or supporting records for a family contribution? OMC support can guide you.",
    },
    "fbr-pos-challan": {
        "short_description": "Get assistance preparing the FBR POS challan process with the required identity and contact information.",
        "description": "A missing detail can hold up a POS challan request. OMC keeps the required identity and contact information organized and moves the request through a clear service workflow so you do not have to manage the process through scattered follow-ups.",
        "support_message": "If you are unsure what to provide for the POS challan request, OMC support can confirm the required details.",
    },
    "financials": {
        "short_description": "Turn your financial records into organized statements and supporting financial information for business use.",
        "description": "Reliable financials start with records that are complete, consistent and easy to trace. OMC helps organize the available tax, banking and financial information into a structured workflow, reducing the risk of working from incomplete or disconnected records.",
        "support_message": "Share the financial period and available records; OMC support can help confirm what is needed before work begins.",
    },
    "gst-registration": {
        "short_description": "Get your GST registration prepared with identity, business, banking and address evidence organized correctly.",
        "description": "GST registration involves several pieces of business evidence that need to line up. OMC helps organize identity, NTN, business-address, utility and bank-account information so the registration package is prepared coherently and avoidable document gaps are caught earlier.",
        "support_message": "Questions about GST eligibility, bank proof or business-address evidence? OMC support can help you prepare the required documents.",
    },
    "house-wife-filing": {
        "short_description": "Prepare a clear tax filing for a housewife using the relevant banking, asset and financial information.",
        "description": "A filing still needs a consistent financial picture even when there is no conventional salary or business income. OMC helps organize bank statements, assets, investments and related information so the return can be prepared from documented facts rather than assumptions.",
        "support_message": "Not sure which financial or asset records are relevant? OMC support can help you identify what to prepare.",
    },
    "monthly-gst-filing": {
        "short_description": "Keep monthly GST filing organized around sales, purchases and tax-payment evidence for the period.",
        "description": "Monthly GST work can become difficult when sales, purchases and challan evidence are collected late or do not reconcile. OMC provides a structured filing workflow so period records can be reviewed together and missing information can be identified before submission.",
        "support_message": "Need help organizing sales, purchase or challan records for the month? OMC support can guide you.",
    },
    "monthly-services": {
        "short_description": "Use a structured monthly service workflow for recurring compliance or accounting work agreed with OMC.",
        "description": "Recurring work is easier to manage when the scope, period and supporting records are captured consistently each month. OMC provides a single workflow for agreed monthly work so documents, progress and follow-ups stay organized instead of being spread across informal channels.",
        "support_message": "Tell OMC support which monthly service and period you need so the correct scope can be confirmed before submission.",
    },
    "monthly-srb-filing": {
        "short_description": "Organize monthly SRB filing with sales, tax-payment and withholding evidence kept together for the period.",
        "description": "Periodic SRB filings depend on accurate period data and supporting tax evidence. OMC helps collect the relevant sales, challan and withholding information in one structured workflow so missing records can be identified early and the filing can be prepared more consistently.",
        "support_message": "If you are unsure which SRB records apply to the filing period, OMC support can help you prepare them.",
    },
    "nrp-tax-return-filing": {
        "short_description": "Prepare a Pakistan tax return for a non-resident with relevant banking, assets and local financial information organized clearly.",
        "description": "Non-resident filings can be confusing when Pakistan-based assets, banking and other financial information are spread across different records. OMC helps organize the relevant facts and supporting documents into a clear filing workflow so the return is prepared from consistent information.",
        "support_message": "Not sure which Pakistan-based records are relevant to your NRP filing? OMC support can help you identify them.",
    },
    "ntn-modification": {
        "short_description": "Update NTN-related business details through a guided process that keeps your registration information consistent.",
        "description": "Outdated business names, addresses or activity details can create unnecessary friction in later tax and registration work. OMC helps organize the requested NTN changes and supporting information so your registration details can be updated through a clear, traceable process.",
        "support_message": "Tell OMC support what needs to change on your NTN record and they can guide you on the required information.",
    },
    "ntn-registration": {
        "short_description": "Get NTN registration assistance with identity, contact and address details prepared in a simple guided workflow.",
        "description": "NTN registration is an important first step for many tax and business activities. OMC helps collect and organize the required identity, contact and address information so your registration request starts with a complete, structured set of details instead of repeated back-and-forth.",
        "support_message": "Need help preparing CNIC, contact or address details for NTN registration? OMC support can guide you.",
    },
    "other-services": {
        "short_description": "Request an OMC professional service that does not fit a standard category, with your requirement captured clearly from the start.",
        "description": "Not every tax, registration or advisory requirement fits a fixed service template. This route lets you explain the requirement and provide relevant information in a structured OMC workflow so the team can review the case and confirm the appropriate next steps.",
        "support_message": "Describe what you need and OMC support can help confirm whether this is the right service route before you proceed.",
    },
    "other-sources": {
        "short_description": "Organize tax filing information for income or financial sources that fall outside the standard filing categories.",
        "description": "Non-standard income or financial sources still need a clear supporting trail. OMC helps organize the relevant banking, asset and supporting information so the filing can reflect those sources more consistently and important details are less likely to be missed.",
        "support_message": "Unsure how your other income or financial source should be documented? OMC support can help you identify the relevant records.",
    },
    "p-s-w-registration-service": {
        "short_description": "Prepare Pakistan Single Window registration with business, banking and authorized-person details organized together.",
        "description": "PSW registration connects important business and trade information, so inconsistent company, bank or authorized-person details can create avoidable delays. OMC helps prepare the supporting registration information in one guided workflow for a cleaner submission process.",
        "support_message": "Questions about bank, company or authorized-person documents for PSW? OMC support can help you prepare them.",
    },
    "password-reset": {
        "short_description": "Get structured assistance restoring access to your FBR or IRIS account with the required identity details.",
        "description": "Losing access to a tax account can block filing and follow-up work. OMC provides a clear password-reset assistance workflow so the required identity and contact information is captured properly and the access issue can be handled without sharing credentials through informal channels.",
        "support_message": "If you cannot access FBR or IRIS, OMC support can guide you on the identity details needed for the reset request.",
    },
    "pensioner-filing": {
        "short_description": "Prepare a pensioner tax filing with pension, banking and wealth information organized in one place.",
        "description": "Pension income and the related financial position should be supported by clear records. OMC helps organize pension evidence, banking information and relevant wealth details so the filing can be prepared from a consistent set of documents with fewer avoidable omissions.",
        "support_message": "Not sure which pension, bank or wealth records are needed? OMC support can help you prepare the filing information.",
    },
    "pos-intergation": {
        "short_description": "Plan FBR POS integration through a structured workflow for system access, business details and implementation follow-up.",
        "description": "POS integration touches both business operations and FBR connectivity, so the setup benefits from clear ownership and organized technical information. OMC provides a structured route to capture the required details and coordinate the integration work without losing key steps in informal communication.",
        "support_message": "Share your current POS setup and IRIS access situation; OMC support can help confirm the information needed for integration.",
    },
    "pvt-registration-services": {
        "short_description": "Register a private limited company with director, shareholding, business-address and proposed-name details organized from the start.",
        "description": "Company registration moves more smoothly when director information, proposed names, shareholding and the business address are consistent before filing. OMC helps organize those details and supporting documents in one guided workflow so avoidable corrections and repeated follow-ups are reduced.",
        "support_message": "Need help preparing director, shareholding or proposed-company-name details? OMC support can guide you through the registration requirements.",
    },
    "quarterly-wht-filing": {
        "short_description": "Prepare quarterly withholding-tax filing with the period's purchase and withholding records organized for review.",
        "description": "Quarterly WHT filing depends on period records being complete and consistent. OMC helps collect and organize the relevant purchase and withholding information so the filing can be reviewed from one structured set of data and missing evidence can be identified earlier.",
        "support_message": "Need help identifying the records for the quarter? OMC support can guide you on the purchase and withholding information to prepare.",
    },
    "registration-of-kcci": {
        "short_description": "Prepare a KCCI registration package with identity, tax, banking and business-registration documents organized together.",
        "description": "KCCI registration requires several business and identity records to be presented consistently. OMC helps organize the CNIC, NTN, banking, letterhead and company or firm documents into one guided workflow so missing pieces can be identified before submission.",
        "support_message": "Unsure which KCCI documents apply to your business type? OMC support can help you prepare the registration pack.",
    },
    "salaried-tax-filing": {
        "short_description": "File your salaried tax return with salary, banking, asset and investment information organized clearly.",
        "description": "A salaried return can involve more than the salary certificate alone. OMC helps bring salary evidence together with relevant banking, property, vehicle and investment information so the filing is prepared from a fuller financial picture and avoidable omissions are reduced.",
        "support_message": "Not sure which bank, asset or investment records belong with your salary filing? OMC support can guide you.",
    },
    "secp-compliance": {
        "short_description": "Keep SECP compliance work organized with the company records and prior compliance evidence needed for the task.",
        "description": "Corporate compliance is easier to manage when company records and prior filings are available in one place. OMC helps structure the required information and supporting documents so the compliance task can be reviewed clearly and unnecessary back-and-forth is reduced.",
        "support_message": "Tell OMC support which SECP compliance matter you need help with so the correct records can be identified.",
    },
    "srb-registration": {
        "short_description": "Prepare provincial revenue registration with identity, tax, banking and business-location details organized correctly.",
        "description": "SRB, PRA, BRA or KEPRA registration can require multiple business, banking and location records to align. OMC helps organize the relevant identity, NTN, utility, premises and bank information so the registration package is clearer and avoidable document gaps are caught earlier.",
        "support_message": "Unsure which provincial registration or business documents apply? OMC support can help you prepare the right information.",
    },
    "stock-audit": {
        "short_description": "Prepare for a stock audit with inventory listings, records, locations and system information organized for review.",
        "description": "A useful stock audit depends on inventory records that can be traced to locations and the systems used to manage them. OMC helps structure the available stock data and supporting records so the audit scope is clearer and evidence gaps can be identified before fieldwork progresses.",
        "support_message": "Share the audit period and available inventory records; OMC support can help confirm what should be prepared for review.",
    },
    "tax-club": {
        "short_description": "A dedicated OMC tax-support service route for customers whose requirements fall within the TAX Club scope.",
        "description": "TAX Club is retained as a controlled OMC service route while its final commercial scope is reviewed. When activated, the service provides a structured way to capture the customer's tax-support requirement, supporting information and follow-up within the OMC workflow without inventing an unapproved commercial promise.",
        "support_message": "Contact OMC support to confirm the current TAX Club scope and eligibility before submitting a request.",
    },
    "ubl-lead": {
        "short_description": "A controlled OMC service route for UBL-originated client cases that require structured follow-up and handling.",
        "description": "UBL Lead is retained as a controlled service route for cases originating through the UBL channel while its final customer-facing scope is reviewed. It keeps the case inside the OMC workflow so ownership, supporting information and follow-up can be handled consistently when the route is enabled.",
        "support_message": "If your case originated through UBL, contact OMC support to confirm the correct service route before proceeding.",
    },
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def validate_presentation_source() -> dict[str, Any]:
    expected = {spec.service_id for spec in SERVICES}
    actual = set(SERVICE_PRESENTATION)
    errors: list[str] = []

    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        errors.append(f"missing service presentation copy: {', '.join(missing)}")
    if extra:
        errors.append(f"unknown service presentation copy: {', '.join(extra)}")

    for service_id in sorted(expected & actual):
        row = SERVICE_PRESENTATION[service_id]
        for fieldname in ("short_description", "description", "support_message"):
            if not _text(row.get(fieldname)):
                errors.append(f"{service_id}.{fieldname} is empty")
        if len(_text(row.get("short_description"))) > 240:
            errors.append(f"{service_id}.short_description is too long")
        if len(_text(row.get("support_message"))) > 240:
            errors.append(f"{service_id}.support_message is too long")

    return {
        "ok": not errors,
        "expected_services": len(expected),
        "configured_services": len(actual),
        "errors": errors,
    }


def desired_presentation(service_id: str) -> dict[str, str]:
    source = validate_presentation_source()
    if not source["ok"]:
        frappe.throw("; ".join(source["errors"]), frappe.ValidationError)

    copy = SERVICE_PRESENTATION[service_id]
    return {
        "short_description": copy["short_description"],
        "description": copy["description"],
        "support_message": copy["support_message"],
        "default_assignment_role": DEFAULT_ASSIGNMENT_ROLE,
    }


def _service_rows() -> dict[str, dict[str, Any]]:
    rows = frappe.get_all(
        "OMC Service",
        fields=["name", "service_id", *PRESENTATION_FIELDS],
        limit_page_length=1000,
    )
    return {
        _text(row.service_id): dict(row)
        for row in rows
        if _text(row.service_id)
    }


def preview_service_presentation() -> dict[str, Any]:
    source = validate_presentation_source()
    if not source["ok"]:
        return {
            "ok": False,
            "read_only": True,
            "operation": "preview_service_presentation",
            "ready_to_sync": False,
            "updated": 0,
            "unchanged": 0,
            "missing_services": [],
            "errors": source["errors"],
        }

    existing = _service_rows()
    updated: list[str] = []
    unchanged: list[str] = []
    missing: list[str] = []

    for spec in SERVICES:
        current = existing.get(spec.service_id)
        if not current:
            missing.append(spec.service_id)
            continue
        desired = desired_presentation(spec.service_id)
        if any(
            _text(current.get(fieldname)) != _text(value)
            for fieldname, value in desired.items()
        ):
            updated.append(spec.service_id)
        else:
            unchanged.append(spec.service_id)

    return {
        "ok": True,
        "read_only": True,
        "operation": "preview_service_presentation",
        "ready_to_sync": not missing,
        "updated": len(updated),
        "unchanged": len(unchanged),
        "missing_services": missing,
        "update_services": updated,
        "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
        "errors": [],
    }


def validate_service_presentation() -> dict[str, Any]:
    preview = preview_service_presentation()
    valid = bool(
        preview.get("ok")
        and not preview.get("missing_services")
        and int(preview.get("updated") or 0) == 0
    )
    return {
        **preview,
        "operation": "validate_service_presentation",
        "valid": valid,
    }


def sync_service_presentation(*, commit: bool = True) -> dict[str, Any]:
    source = validate_presentation_source()
    if not source["ok"]:
        frappe.throw("; ".join(source["errors"]), frappe.ValidationError)

    savepoint = "omc_service_presentation_sync"
    frappe.db.savepoint(savepoint)
    changed = 0
    unchanged = 0

    try:
        existing = _service_rows()
        for spec in SERVICES:
            current = existing.get(spec.service_id)
            if not current:
                frappe.throw(
                    f"Managed OMC Service is missing after catalogue sync: {spec.service_id}",
                    frappe.ValidationError,
                )

            desired = desired_presentation(spec.service_id)
            changes = {
                fieldname: value
                for fieldname, value in desired.items()
                if _text(current.get(fieldname)) != _text(value)
            }
            if not changes:
                unchanged += 1
                continue

            frappe.db.set_value(
                "OMC Service",
                current["name"],
                changes,
                update_modified=False,
            )
            changed += 1

        validation = validate_service_presentation()
        if not validation["valid"]:
            frappe.throw(
                "Service presentation validation failed after synchronization.",
                frappe.ValidationError,
            )

        if commit:
            frappe.db.commit()

        return {
            "ok": True,
            "operation": "sync_service_presentation",
            "committed": bool(commit),
            "updated": changed,
            "unchanged": unchanged,
            "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
            "validation": validation,
        }
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise
