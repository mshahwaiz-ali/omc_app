from __future__ import annotations

import re
from dataclasses import dataclass


MANIFEST_VERSION = 2

AUTHORITATIVE_COMPANY = "Omc House"
CURRENCY = "PKR"
ACTIVATION_POLICY = "Full Settlement"
DEFAULT_ASSIGNMENT_ROLE = "Employee"

EXPECTED_CATEGORY_COUNT = 9
EXPECTED_SERVICE_COUNT = 31
EXPECTED_ACTIVE_SERVICE_COUNT = 17

PRICE_SOURCES = {
    "client",
    "current_omc",
    "current_omc_fallback",
    "unknown",
}

CONFIDENCE_CLASSES = {"A", "B", "C"}

ALLOWED_ICONS = {
    "business_setup",
    "company_registration",
    "tax_filing",
    "tax_registration",
    "gst",
    "accounting",
    "audit",
    "documents",
    "certificate",
    "legal",
    "visa",
    "payroll",
    "payments",
    "compliance",
    "consultation",
    "licensing",
    "trademark",
    "bookkeeping",
    "banking",
    "general_service",
}


@dataclass(frozen=True)
class CategorySpec:
    category_name: str
    title: str
    description: str
    icon: str
    accent_color: str
    sort_order: int


@dataclass(frozen=True)
class ServiceSpec:
    service_id: str
    erp_task_type: str
    title: str
    category: str
    base_price: float
    completion_time: str
    is_active: bool
    price_source: str
    confidence: str
    review_required: bool
    short_description: str = ""
    description: str = ""
    support_message: str = ""
    default_assignment_role: str = DEFAULT_ASSIGNMENT_ROLE
    review_notes: str = ""
    icon: str | None = None
    sort_order: int = 0


CATEGORIES = (
    CategorySpec(
        category_name="income-tax",
        title="Income Tax & Returns",
        description="Income tax return filing and related individual or business tax services.",
        icon="tax_filing",
        accent_color="#7C3AED",
        sort_order=10,
    ),
    CategorySpec(
        category_name="sales-tax-gst",
        title="Sales Tax & GST",
        description="GST, SRB and periodic sales-tax registration and filing services.",
        icon="gst",
        accent_color="#4F46E5",
        sort_order=20,
    ),
    CategorySpec(
        category_name="registrations",
        title="Registrations & Certificates",
        description="Tax, business and statutory registration or certificate services.",
        icon="tax_registration",
        accent_color="#0F766E",
        sort_order=30,
    ),
    CategorySpec(
        category_name="corporate-secp",
        title="Corporate & SECP",
        description="Company registration and SECP corporate services.",
        icon="company_registration",
        accent_color="#1E3A8A",
        sort_order=40,
    ),
    CategorySpec(
        category_name="compliance-filing",
        title="Compliance & Periodic Filing",
        description="Recurring statutory, withholding and compliance filing services.",
        icon="compliance",
        accent_color="#15803D",
        sort_order=50,
    ),
    CategorySpec(
        category_name="pos-digital",
        title="POS & Digital Services",
        description="FBR POS and related digital registration or integration services.",
        icon="payments",
        accent_color="#EA580C",
        sort_order=60,
    ),
    CategorySpec(
        category_name="accounting-financials",
        title="Accounting & Financials",
        description="Financial statement and accounting-related services.",
        icon="accounting",
        accent_color="#2563EB",
        sort_order=70,
    ),
    CategorySpec(
        category_name="audit-assurance",
        title="Audit & Assurance",
        description="Stock audit and assurance-related professional services.",
        icon="audit",
        accent_color="#D97706",
        sort_order=80,
    ),
    CategorySpec(
        category_name="other-services",
        title="Advisory & Other Services",
        description="Advisory, advocacy and other OMC professional services.",
        icon="consultation",
        accent_color="#881337",
        sort_order=90,
    ),
)


# Customer-facing copy is source-controlled with the catalogue manifest. It is
# deliberately factual and service-specific: no outcome guarantees, invented
# deadlines, legal threats, or commercial promises beyond the approved service
# data. Inactive/review-required services are fully prepared for later activation.
SERVICE_COPY: dict[str, dict[str, str]] = {
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


def _service_spec(**values) -> ServiceSpec:
    service_id = str(values.get("service_id") or "")
    copy = SERVICE_COPY.get(service_id, {})
    return ServiceSpec(
        **values,
        short_description=str(copy.get("short_description") or ""),
        description=str(copy.get("description") or ""),
        support_message=str(copy.get("support_message") or ""),
        default_assignment_role=DEFAULT_ASSIGNMENT_ROLE,
    )


SERVICES = (
    _service_spec(
        service_id="7e-exemption-certificate",
        erp_task_type="7E Exemption Certificate",
        title="7E Exemption Certificate",
        category="income-tax",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Requirements and turnaround are inferred and require operator review before publishing.",
        sort_order=10,
    ),
    _service_spec(
        service_id="advocacy-service-hearing-with-commissioner",
        erp_task_type="Advocacy Service - Hearing with Commissioner",
        title="Commissioner Hearing & Advocacy",
        category="other-services",
        base_price=50000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="B",
        review_required=True,
        review_notes="Case scope and hearing requirements require confirmation before publishing.",
        icon="legal",
        sort_order=20,
    ),
    _service_spec(
        service_id="aop-filling",
        erp_task_type="AOP Filling",
        title="AOP Tax Return Filing",
        category="income-tax",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Requirements and turnaround are inferred and require review.",
        sort_order=30,
    ),
    _service_spec(
        service_id="aop-firm-registration-service",
        erp_task_type="AOP Firm Registration Service",
        title="AOP / Partnership Firm Registration",
        category="registrations",
        base_price=50000,
        completion_time="4–5 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=40,
    ),
    _service_spec(
        service_id="business-tax-filing",
        erp_task_type="Business Tax Filing",
        title="Business Tax Return Filing",
        category="income-tax",
        base_price=10000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=50,
    ),
    _service_spec(
        service_id="family-contribute",
        erp_task_type="Family contribute",
        title="Family Contribution Tax Filing",
        category="income-tax",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=60,
    ),
    _service_spec(
        service_id="fbr-pos-challan",
        erp_task_type="FBR POS Challan",
        title="FBR POS Challan",
        category="pos-digital",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=70,
    ),
    _service_spec(
        service_id="financials",
        erp_task_type="Financials",
        title="Financial Statements / Financials",
        category="accounting-financials",
        base_price=10000,
        completion_time="1–2 days",
        is_active=False,
        price_source="client",
        confidence="B",
        review_required=True,
        review_notes="Client material indicates PKR 10,000 per year; pricing model should be reviewed before publishing.",
        sort_order=80,
    ),
    _service_spec(
        service_id="gst-registration",
        erp_task_type="GST Registration",
        title="GST Registration",
        category="sales-tax-gst",
        base_price=10000,
        completion_time="4–5 days",
        is_active=True,
        price_source="client",
        confidence="B",
        review_required=True,
        review_notes="Kept active. Bank certificate/IBAN and biometric processing details require careful reconciliation with the existing service.",
        sort_order=90,
    ),
    _service_spec(
        service_id="house-wife-filing",
        erp_task_type="House Wife Filing",
        title="Housewife Tax Filing",
        category="income-tax",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=100,
    ),
    _service_spec(
        service_id="monthly-gst-filing",
        erp_task_type="Monthly GST Filing",
        title="Monthly GST Filing",
        category="sales-tax-gst",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Periodic filing requirements and turnaround are inferred.",
        sort_order=110,
    ),
    _service_spec(
        service_id="monthly-services",
        erp_task_type="Monthly Services",
        title="Monthly Services",
        category="compliance-filing",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Scope is undefined. Do not assume this represents the POS recurring fee.",
        sort_order=120,
    ),
    _service_spec(
        service_id="monthly-srb-filing",
        erp_task_type="Monthly SRB Filing",
        title="Monthly SRB Filing",
        category="sales-tax-gst",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Periodic SRB filing requirements and turnaround are inferred.",
        sort_order=130,
    ),
    _service_spec(
        service_id="nrp-tax-return-filing",
        erp_task_type="NRP Tax Return Filing",
        title="Non-Resident Pakistani Tax Return Filing",
        category="income-tax",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=140,
    ),
    _service_spec(
        service_id="ntn-modification",
        erp_task_type="NTN  MODIFICATION",
        title="NTN Modification",
        category="registrations",
        base_price=2000,
        completion_time="1 day",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=150,
    ),
    _service_spec(
        service_id="ntn-registration",
        erp_task_type="NTN Registration",
        title="NTN Registration",
        category="registrations",
        base_price=5000,
        completion_time="1–3 days",
        is_active=True,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Existing verified OMC service; preserve active status and reconcile without destructive replacement.",
        sort_order=160,
    ),
    _service_spec(
        service_id="other-services",
        erp_task_type="Other Services",
        title="Other Services",
        category="other-services",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=170,
    ),
    _service_spec(
        service_id="other-sources",
        erp_task_type="other sources",
        title="Other Sources",
        category="income-tax",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=180,
    ),
    _service_spec(
        service_id="p-s-w-registration-service",
        erp_task_type="P S W Registration Service",
        title="Pakistan Single Window (PSW) Registration",
        category="registrations",
        base_price=10000,
        completion_time="4–5 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=190,
    ),
    _service_spec(
        service_id="password-reset",
        erp_task_type="Password Reset",
        title="FBR / IRIS Password Reset Assistance",
        category="registrations",
        base_price=1000,
        completion_time="Within 1 day",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=200,
    ),
    _service_spec(
        service_id="pensioner-filing",
        erp_task_type="Pensioner Filing",
        title="Pensioner Tax Filing",
        category="income-tax",
        base_price=3000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=210,
    ),
    _service_spec(
        service_id="pos-intergation",
        erp_task_type="POS intergation",
        title="POS Integration",
        category="pos-digital",
        base_price=10000,
        completion_time="1–2 days",
        is_active=False,
        price_source="client",
        confidence="B",
        review_required=True,
        review_notes="Client material states PKR 10,000 integration plus PKR 5,000 monthly. Current base-price model cannot safely represent the recurring component.",
        sort_order=220,
    ),
    _service_spec(
        service_id="pvt-registration-services",
        erp_task_type="PVT Registration Services",
        title="Private Limited Company Registration",
        category="corporate-secp",
        base_price=50000,
        completion_time="6–7 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=230,
    ),
    _service_spec(
        service_id="quarterly-wht-filing",
        erp_task_type="Quarterly WHT Filing",
        title="Quarterly WHT Filing",
        category="compliance-filing",
        base_price=10000,
        completion_time="1–2 days",
        is_active=False,
        price_source="current_omc_fallback",
        confidence="B",
        review_required=True,
        review_notes="Client price was not supplied; PKR 10,000 is retained only as the current OMC fallback.",
        sort_order=240,
    ),
    _service_spec(
        service_id="registration-of-kcci",
        erp_task_type="Registration of KCCI",
        title="KCCI Registration",
        category="registrations",
        base_price=16000,
        completion_time="4–5 days",
        is_active=False,
        price_source="client",
        confidence="B",
        review_required=True,
        review_notes="Client requirement wording for Company/Firm documents is incomplete and requires review.",
        sort_order=250,
    ),
    _service_spec(
        service_id="salaried-tax-filing",
        erp_task_type="Salaried Tax Filing",
        title="Income Tax Return Filing — Salaried Individuals",
        category="income-tax",
        base_price=5000,
        completion_time="1–2 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=260,
    ),
    _service_spec(
        service_id="secp-compliance",
        erp_task_type="SECP Compliance",
        title="SECP Compliance",
        category="corporate-secp",
        base_price=10000,
        completion_time="",
        is_active=False,
        price_source="current_omc_fallback",
        confidence="B",
        review_required=True,
        review_notes="Scope and client price require confirmation before publishing.",
        sort_order=270,
    ),
    _service_spec(
        service_id="srb-registration",
        erp_task_type="SRB Registration",
        title="SRB / PRA / BRA / KEPRA Registration",
        category="registrations",
        base_price=10000,
        completion_time="4–5 days",
        is_active=True,
        price_source="client",
        confidence="A",
        review_required=False,
        sort_order=280,
    ),
    _service_spec(
        service_id="stock-audit",
        erp_task_type="Stock Audit",
        title="Stock Audit",
        category="audit-assurance",
        base_price=50000,
        completion_time="",
        is_active=False,
        price_source="current_omc",
        confidence="C",
        review_required=True,
        review_notes="Audit scope, evidence requirements and turnaround are inferred.",
        sort_order=290,
    ),
    _service_spec(
        service_id="tax-club",
        erp_task_type="TAX Club",
        title="TAX Club",
        category="other-services",
        base_price=0,
        completion_time="",
        is_active=False,
        price_source="unknown",
        confidence="C",
        review_required=True,
        review_notes="Price and service scope are unknown. Zero is a placeholder and must never be interpreted as a free service.",
        sort_order=300,
    ),
    _service_spec(
        service_id="ubl-lead",
        erp_task_type="UBL Lead",
        title="UBL Lead",
        category="other-services",
        base_price=0,
        completion_time="",
        is_active=False,
        price_source="unknown",
        confidence="C",
        review_required=True,
        review_notes="Price, customer-facing scope and requirements are undefined.",
        sort_order=310,
    ),
)


EXPECTED_TASK_TYPES = (
    "7E Exemption Certificate",
    "Advocacy Service - Hearing with Commissioner",
    "AOP Filling",
    "AOP Firm Registration Service",
    "Business Tax Filing",
    "Family contribute",
    "FBR POS Challan",
    "Financials",
    "GST Registration",
    "House Wife Filing",
    "Monthly GST Filing",
    "Monthly Services",
    "Monthly SRB Filing",
    "NRP Tax Return Filing",
    "NTN  MODIFICATION",
    "NTN Registration",
    "Other Services",
    "other sources",
    "P S W Registration Service",
    "Password Reset",
    "Pensioner Filing",
    "POS intergation",
    "PVT Registration Services",
    "Quarterly WHT Filing",
    "Registration of KCCI",
    "Salaried Tax Filing",
    "SECP Compliance",
    "SRB Registration",
    "Stock Audit",
    "TAX Club",
    "UBL Lead",
)


def category_by_name() -> dict[str, CategorySpec]:
    return {item.category_name: item for item in CATEGORIES}


def service_by_id() -> dict[str, ServiceSpec]:
    return {item.service_id: item for item in SERVICES}


def validate_manifest() -> dict[str, object]:
    errors: list[str] = []

    if len(CATEGORIES) != EXPECTED_CATEGORY_COUNT:
        errors.append(
            f"expected {EXPECTED_CATEGORY_COUNT} categories, found {len(CATEGORIES)}"
        )

    if len(SERVICES) != EXPECTED_SERVICE_COUNT:
        errors.append(
            f"expected {EXPECTED_SERVICE_COUNT} services, found {len(SERVICES)}"
        )

    category_names = [item.category_name for item in CATEGORIES]
    if len(category_names) != len(set(category_names)):
        errors.append("duplicate category_name values")

    service_ids = [item.service_id for item in SERVICES]
    if len(service_ids) != len(set(service_ids)):
        errors.append("duplicate service_id values")

    copy_ids = set(SERVICE_COPY)
    service_id_set = set(service_ids)
    missing_copy = sorted(service_id_set - copy_ids)
    extra_copy = sorted(copy_ids - service_id_set)
    if missing_copy:
        errors.append(f"missing service copy: {', '.join(missing_copy)}")
    if extra_copy:
        errors.append(f"unknown service copy: {', '.join(extra_copy)}")

    task_types = [item.erp_task_type for item in SERVICES]
    if len(task_types) != len(set(task_types)):
        errors.append("duplicate ERP Task Type mappings")

    if tuple(task_types) != EXPECTED_TASK_TYPES:
        errors.append(
            "ERP Task Type identities/order differ from the approved 31-item baseline"
        )

    category_map = category_by_name()

    for category in CATEGORIES:
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", category.category_name):
            errors.append(
                f"invalid category_name: {category.category_name!r}"
            )

        if category.icon not in ALLOWED_ICONS:
            errors.append(
                f"{category.category_name}: unsupported icon {category.icon!r}"
            )

        if not re.fullmatch(r"#[0-9A-F]{6}", category.accent_color):
            errors.append(
                f"{category.category_name}: invalid accent colour "
                f"{category.accent_color!r}"
            )

    active_count = 0

    for service in SERVICES:
        if not re.fullmatch(
            r"[a-z0-9]+(?:-[a-z0-9]+)*",
            service.service_id,
        ):
            errors.append(
                f"invalid service_id: {service.service_id!r}"
            )

        if service.category not in category_map:
            errors.append(
                f"{service.service_id}: unknown category {service.category!r}"
            )

        resolved_icon = service.icon or category_map[service.category].icon
        if resolved_icon not in ALLOWED_ICONS:
            errors.append(
                f"{service.service_id}: unsupported icon {resolved_icon!r}"
            )

        if service.price_source not in PRICE_SOURCES:
            errors.append(
                f"{service.service_id}: invalid price_source "
                f"{service.price_source!r}"
            )

        if service.confidence not in CONFIDENCE_CLASSES:
            errors.append(
                f"{service.service_id}: invalid confidence "
                f"{service.confidence!r}"
            )

        for fieldname in ("short_description", "description", "support_message"):
            if not str(getattr(service, fieldname, "") or "").strip():
                errors.append(f"{service.service_id}: {fieldname} is required")

        if len(service.short_description.strip()) > 240:
            errors.append(f"{service.service_id}: short_description is too long")
        if len(service.support_message.strip()) > 240:
            errors.append(f"{service.service_id}: support_message is too long")
        if service.default_assignment_role != DEFAULT_ASSIGNMENT_ROLE:
            errors.append(
                f"{service.service_id}: default_assignment_role must be "
                f"{DEFAULT_ASSIGNMENT_ROLE!r}"
            )

        if service.base_price < 0:
            errors.append(
                f"{service.service_id}: base price cannot be negative"
            )

        if service.is_active:
            active_count += 1
            if service.base_price <= 0:
                errors.append(
                    f"{service.service_id}: active service requires "
                    "a positive base price"
                )

        if service.price_source == "unknown":
            if service.is_active:
                errors.append(
                    f"{service.service_id}: unknown-price service "
                    "must remain inactive"
                )
            if service.base_price != 0:
                errors.append(
                    f"{service.service_id}: unknown price should use "
                    "zero only as an inactive placeholder"
                )

        if service.review_required and not service.review_notes.strip():
            errors.append(
                f"{service.service_id}: review_required without notes"
            )

        if (
            service.confidence == "C"
            and service.is_active
            and service.service_id != "ntn-registration"
        ):
            errors.append(
                f"{service.service_id}: inferred service must remain "
                "inactive unless explicitly approved as an exception"
            )

    if active_count != EXPECTED_ACTIVE_SERVICE_COUNT:
        errors.append(
            f"expected {EXPECTED_ACTIVE_SERVICE_COUNT} active services, "
            f"found {active_count}"
        )

    if errors:
        raise ValueError(
            "Invalid OMC service catalogue manifest:\n- "
            + "\n- ".join(errors)
        )

    return {
        "ok": True,
        "manifest_version": MANIFEST_VERSION,
        "company": AUTHORITATIVE_COMPANY,
        "currency": CURRENCY,
        "activation_policy": ACTIVATION_POLICY,
        "default_assignment_role": DEFAULT_ASSIGNMENT_ROLE,
        "categories": len(CATEGORIES),
        "services": len(SERVICES),
        "active_services": active_count,
        "inactive_services": len(SERVICES) - active_count,
    }
