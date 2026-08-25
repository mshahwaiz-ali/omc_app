from __future__ import annotations

import re
from dataclasses import dataclass


MANIFEST_VERSION = 1

AUTHORITATIVE_COMPANY = "Omc House"
CURRENCY = "PKR"
ACTIVATION_POLICY = "Full Settlement"

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


SERVICES = (
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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
    ServiceSpec(
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

        resolved_icon = (
            service.icon
            or category_map[service.category].icon
        )
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
        "categories": len(CATEGORIES),
        "services": len(SERVICES),
        "active_services": active_count,
        "inactive_services": len(SERVICES) - active_count,
    }
