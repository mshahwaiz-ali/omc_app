from __future__ import annotations

import re
from dataclasses import dataclass

from omc_app.setup.service_catalogue.manifest import (
    SERVICES,
    validate_manifest,
)


@dataclass(frozen=True)
class DocumentSpec:
    document_key: str
    title: str
    document_type: str
    is_required: bool
    instructions: str = ""
    allowed_extensions: str = "pdf,jpg,jpeg,png"
    max_size_mb: int = 10


@dataclass(frozen=True)
class FormFieldSpec:
    fieldname: str
    label: str
    fieldtype: str = "Data"
    is_required: bool = False
    options: str = ""
    placeholder: str = ""
    description: str = ""
    default_value: str = ""


def D(
    key: str,
    title: str,
    document_type: str,
    *,
    required: bool = True,
    instructions: str = "",
) -> DocumentSpec:
    return DocumentSpec(
        document_key=key,
        title=title,
        document_type=document_type,
        is_required=required,
        instructions=instructions,
    )


def F(
    fieldname: str,
    label: str,
    *,
    fieldtype: str = "Data",
    required: bool = False,
    options: str = "",
    placeholder: str = "",
    description: str = "",
) -> FormFieldSpec:
    return FormFieldSpec(
        fieldname=fieldname,
        label=label,
        fieldtype=fieldtype,
        is_required=required,
        options=options,
        placeholder=placeholder,
        description=description,
    )


# GST and NTN deliberately reflect the currently deployed live template sets.
# Their active/in-flight requests make structural template replacement unsafe.
PRESERVED_LIVE_SERVICE_IDS = {
    "gst-registration",
    "ntn-registration",
}


DOCUMENTS_BY_SERVICE: dict[str, tuple[DocumentSpec, ...]] = {
    "7e-exemption-certificate": (
        D("cnic_copy", "CNIC Copy", "CNIC"),
        D(
            "property_ownership_proof",
            "Property Ownership / Supporting Documents",
            "Property",
        ),
        D(
            "other_tax_property_evidence",
            "Other Tax / Property Evidence",
            "Evidence",
            required=False,
        ),
    ),
    "advocacy-service-hearing-with-commissioner": (
        D("hearing_notice", "Hearing Notice / Order", "Legal"),
        D("case_documents", "Relevant Case Documents", "Legal"),
        D(
            "supporting_evidence",
            "Supporting Correspondence / Evidence",
            "Evidence",
            required=False,
        ),
    ),
    "aop-filling": (
        D(
            "business_bank_statement",
            "AOP / Business Bank Statement",
            "Financial",
        ),
        D(
            "financial_accounts_records",
            "Financial / Accounts Records",
            "Financial",
        ),
        D(
            "withholding_tax_evidence",
            "Withholding / Tax Evidence",
            "Tax",
            required=False,
        ),
    ),
    "aop-firm-registration-service": (
        D(
            "cnic_copy",
            "CNIC Copies - All Partners",
            "CNIC",
        ),
        D(
            "partnership_deed",
            "Partnership Deed",
            "Legal",
        ),
        D(
            "utility_bill",
            "Utility Bill",
            "Utility Bill",
        ),
    ),
    "business-tax-filing": (
        D(
            "business_bank_statement",
            "Business Bank Statement",
            "Financial",
        ),
        D(
            "personal_bank_statement",
            "Personal Bank Statement",
            "Financial",
        ),
        D(
            "utility_bill",
            "Utility Bill",
            "Utility Bill",
        ),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "family-contribute": (
        D("bank_statement", "Bank Statement", "Financial"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "fbr-pos-challan": (
        D("cnic_copy", "CNIC Copy", "CNIC"),
    ),
    "financials": (
        D("tax_return", "Tax Return", "Tax"),
        D("bank_statement", "Bank Statement", "Financial"),
    ),

    # Current live GST structure is preserved while in-flight requests exist.
    "gst-registration": (
        D(
            "cnic_copy",
            "CNIC front and back",
            "CNIC",
        ),
        D(
            "ntn_certificate",
            "NTN certificate",
            "Tax",
            required=False,
        ),
        D(
            "business_address_proof",
            "Business address proof",
            "Business",
        ),
        D(
            "utility_bill",
            "Electricity or gas bill",
            "Utility Bill",
        ),
        D(
            "bank_account_proof",
            "Bank account proof",
            "Financial",
        ),
    ),
    "house-wife-filing": (
        D("bank_statement", "Bank Statement", "Financial"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "monthly-gst-filing": (
        D(
            "sales_data",
            "Sales Data / Invoices",
            "Financial",
        ),
        D(
            "purchase_data",
            "Purchase Data / Invoices",
            "Financial",
        ),
        D(
            "tax_challan_evidence",
            "Tax Challans / Supporting Evidence",
            "Tax",
            required=False,
        ),
    ),
    "monthly-services": (),
    "monthly-srb-filing": (
        D(
            "sales_data",
            "Service / Sales Data",
            "Financial",
        ),
        D(
            "tax_challan_evidence",
            "Tax Challans",
            "Tax",
            required=False,
        ),
        D(
            "withholding_tax_evidence",
            "Withholding Tax Evidence",
            "Tax",
            required=False,
        ),
    ),
    "nrp-tax-return-filing": (
        D("bank_statement", "Bank Statement", "Financial"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "ntn-modification": (),

    # Exact currently deployed NTN template set.
    "ntn-registration": (
        D(
            "cnic_front_image",
            "CNIC front image",
            "CNIC",
        ),
        D(
            "cnic_back_image",
            "CNIC back image",
            "CNIC",
        ),
    ),
    "other-services": (
        D("bank_statement", "Bank Statement", "Financial"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "other-sources": (
        D("bank_statement", "Bank Statement", "Financial"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "p-s-w-registration-service": (
        D(
            "bank_maintenance_certificate",
            "Bank Account Maintenance Certificate",
            "Financial",
        ),
        D(
            "company_firm_registration_documents",
            "Company / Firm Registration Documents",
            "Company",
        ),
        D(
            "ntn_certificate",
            "NTN Certificate",
            "Tax",
        ),
    ),
    "password-reset": (
        D("cnic_copy", "CNIC Copy", "CNIC"),
    ),
    "pensioner-filing": (
        D("pension_slip", "Pension Slip", "Financial"),
        D(
            "bank_statement",
            "Bank Statement",
            "Financial",
            instructions="Provide the statement relevant to the applicable tax / fiscal year.",
        ),
        D(
            "wealth_information",
            "Wealth Information",
            "Financial",
        ),
    ),
    "pos-intergation": (),
    "pvt-registration-services": (
        D(
            "cnic_copy",
            "CNIC Copies - All Directors",
            "CNIC",
        ),
        D(
            "office_electricity_bill",
            "Office Electricity Bill",
            "Utility Bill",
        ),
        D(
            "foreign_director_passport",
            "Passport - Foreign Director",
            "Identity",
            required=False,
        ),
    ),
    "quarterly-wht-filing": (
        D(
            "quarterly_purchase_data",
            "Quarterly Purchase Data",
            "Financial",
        ),
    ),
    "registration-of-kcci": (
        D("cnic_copy", "CNIC Copy", "CNIC"),
        D("ntn_certificate", "NTN Certificate", "Tax"),
        D(
            "business_letterhead",
            "Business Letterhead",
            "Business",
        ),
        D(
            "passport_size_photographs",
            "Passport Size Photographs",
            "Identity",
        ),
        D(
            "bank_certificate",
            "Bank Certificate",
            "Financial",
        ),
        D(
            "company_firm_registration_documents",
            "Company / Firm Registration Documents",
            "Company",
            required=False,
        ),
    ),
    "salaried-tax-filing": (
        D(
            "salary_certificate",
            "Salary Slips / Salary Certificate",
            "Financial",
        ),
        D(
            "bank_statement",
            "Bank Statement",
            "Financial",
            instructions="Provide the statement relevant to the applicable fiscal year.",
        ),
        D(
            "utility_bill",
            "Utility Bills",
            "Utility Bill",
        ),
        D(
            "investment_details",
            "Investment Details",
            "Financial",
            required=False,
        ),
        D(
            "property_details",
            "Property Details",
            "Property",
            required=False,
        ),
        D(
            "vehicle_details",
            "Vehicle Details",
            "Asset",
            required=False,
        ),
    ),
    "secp-compliance": (
        D(
            "company_firm_registration_documents",
            "Current SECP / Company Documents",
            "Company",
            required=False,
        ),
        D(
            "prior_compliance_evidence",
            "Prior Filing / AGM Evidence",
            "Compliance",
            required=False,
        ),
    ),
    "srb-registration": (
        D("cnic_copy", "CNIC Copy", "CNIC"),
        D("ntn_certificate", "NTN Certificate", "Tax"),
        D("utility_bill", "Utility Bill", "Utility Bill"),
        D(
            "rent_or_ownership_proof",
            "Rent Agreement / Ownership Proof",
            "Business",
        ),
        D(
            "business_letterhead",
            "Business Letterhead",
            "Business",
        ),
        D(
            "company_firm_registration_documents",
            "Company / Firm Registration Documents",
            "Company",
            required=False,
        ),
    ),
    "stock-audit": (
        D(
            "inventory_listing",
            "Stock / Inventory Listing",
            "Inventory",
        ),
        D(
            "inventory_records",
            "Stock Records / Valuation Support",
            "Inventory",
        ),
        D(
            "warehouse_location_records",
            "Warehouse / Location Records",
            "Audit",
            required=False,
        ),
    ),
    "tax-club": (),
    "ubl-lead": (),
}


FORM_FIELDS_BY_SERVICE: dict[str, tuple[FormFieldSpec, ...]] = {
    "7e-exemption-certificate": (
        F("tax_year", "Tax Year", required=True),
        F(
            "property_details",
            "Property Details",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "exemption_basis",
            "Exemption Basis / Case Details",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "advocacy-service-hearing-with-commissioner": (
        F(
            "matter_case_summary",
            "Matter / Case Summary",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "hearing_date",
            "Hearing Date",
            fieldtype="Date",
        ),
    ),
    "aop-filling": (
        F("tax_year", "Tax Year", required=True),
        F(
            "business_activity",
            "Business Activity",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "aop-firm-registration-service": (
        F(
            "partners_mobile_numbers",
            "Partners' Mobile Numbers",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "partners_email_addresses",
            "Partners' Email Addresses",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "business_address",
            "Business Address",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "nature_of_business",
            "Nature of Business",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "partnership_ratio",
            "Partnership Ratio",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "business-tax-filing": (
        F(
            "mobile_number",
            "Active Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Active Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "family-contribute": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "fbr-pos-challan": (
        F(
            "email_address",
            "Email Registered Against CNIC",
            fieldtype="Email",
            required=True,
        ),
        F(
            "mobile_number",
            "Mobile Registered Against CNIC",
            fieldtype="Phone",
            required=True,
        ),
    ),
    "financials": (),

    # Current live GST form is preserved.
    "gst-registration": (
        F(
            "business_activity_details",
            "Business activity details",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "house-wife-filing": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "monthly-gst-filing": (
        F(
            "filing_period",
            "Filing Month / Period",
            required=True,
        ),
    ),
    "monthly-services": (
        F(
            "requested_monthly_service",
            "Requested Monthly Service / Scope",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "service_period",
            "Service Period",
            required=True,
        ),
    ),
    "monthly-srb-filing": (
        F(
            "filing_period",
            "Filing Month / Period",
            required=True,
        ),
    ),
    "nrp-tax-return-filing": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "ntn-modification": (
        F(
            "business_name",
            "Business Name",
            required=True,
        ),
        F(
            "business_address",
            "Business Address",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "business_activity",
            "Business Activity",
            fieldtype="Small Text",
            required=True,
        ),
    ),

    # Exact currently deployed NTN fieldnames.
    "ntn-registration": (
        F(
            "active_mobile_number",
            "Active mobile number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "active_email_address",
            "Active email address",
            fieldtype="Email",
            required=True,
        ),
        F(
            "residential_address",
            "Residential address",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "other-services": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "other-sources": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
    ),
    "p-s-w-registration-service": (
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
        F(
            "authorized_person_details",
            "Authorized Person Details",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "password-reset": (
        F(
            "email_address",
            "Email Registered Against CNIC",
            fieldtype="Email",
            required=True,
        ),
        F(
            "mobile_number",
            "Mobile Registered Against CNIC",
            fieldtype="Phone",
            required=True,
        ),
    ),
    "pensioner-filing": (
        F(
            "retirement_date",
            "Retirement Date",
            fieldtype="Date",
            required=True,
        ),
    ),
    "pos-intergation": (
        F(
            "iris_login_id",
            "IRIS Login ID",
            required=True,
            description="Provide the login ID only. Never enter an IRIS password.",
        ),
    ),
    "pvt-registration-services": (
        F(
            "directors_mobile_numbers",
            "Directors' Mobile Numbers",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "directors_email_addresses",
            "Directors' Email Addresses",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "proposed_company_name",
            "Proposed Company Name",
            required=True,
        ),
        F(
            "business_address",
            "Business Address",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "nature_of_business",
            "Nature of Business",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "shareholding_details",
            "Shareholding Percentage / Details",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "quarterly-wht-filing": (
        F(
            "filing_period",
            "Filing Quarter / Period",
            required=True,
        ),
    ),
    "registration-of-kcci": (
        F(
            "business_address",
            "Business Address",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "salaried-tax-filing": (),
    "secp-compliance": (
        F(
            "compliance_scope",
            "Compliance Scope",
            fieldtype="Select",
            required=True,
            options="Auditor Appointment\nAGM\nBoth",
        ),
    ),
    "srb-registration": (
        F(
            "business_address",
            "Business Address",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "mobile_number",
            "Mobile Number",
            fieldtype="Phone",
            required=True,
        ),
        F(
            "email_address",
            "Email Address",
            fieldtype="Email",
            required=True,
        ),
        F(
            "bank_account_details",
            "Bank Account Details",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "nature_of_services",
            "Nature of Services",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "stock-audit": (
        F(
            "audit_period",
            "Audit Period",
            required=True,
        ),
        F(
            "business_site_address",
            "Business / Site Address",
            fieldtype="Small Text",
            required=True,
        ),
        F(
            "inventory_system_audit_notes",
            "Inventory System / Audit Notes",
            fieldtype="Small Text",
        ),
    ),
    "tax-club": (
        F(
            "tax_club_request",
            "TAX Club Request / Membership Details",
            fieldtype="Small Text",
            required=True,
        ),
    ),
    "ubl-lead": (),
}


ALLOWED_FIELD_TYPES = {
    "Data",
    "Small Text",
    "Text",
    "Select",
    "Check",
    "Date",
    "Datetime",
    "Currency",
    "Int",
    "Float",
    "Phone",
    "Email",
    "Attach",
}


def validate_requirements() -> dict[str, object]:
    validate_manifest()

    errors: list[str] = []

    service_ids = {
        service.service_id
        for service in SERVICES
    }

    document_services = set(DOCUMENTS_BY_SERVICE)
    field_services = set(FORM_FIELDS_BY_SERVICE)

    if document_services != service_ids:
        errors.append(
            "document manifest service coverage differs from "
            "the 31-service manifest"
        )

    if field_services != service_ids:
        errors.append(
            "form-field manifest service coverage differs from "
            "the 31-service manifest"
        )

    document_count = 0
    required_document_count = 0
    form_field_count = 0

    for service_id in sorted(service_ids):
        documents = DOCUMENTS_BY_SERVICE.get(
            service_id,
            (),
        )

        keys = [
            document.document_key
            for document in documents
        ]

        if len(keys) != len(set(keys)):
            errors.append(
                f"{service_id}: duplicate document_key"
            )

        for document in documents:
            document_count += 1

            if document.is_required:
                required_document_count += 1

            if not re.fullmatch(
                r"[a-z0-9]+(?:_[a-z0-9]+)*",
                document.document_key,
            ):
                errors.append(
                    f"{service_id}: invalid document_key "
                    f"{document.document_key!r}"
                )

            if not document.title.strip():
                errors.append(
                    f"{service_id}: document title is empty"
                )

            if not document.document_type.strip():
                errors.append(
                    f"{service_id}: document type is empty"
                )

            if document.max_size_mb <= 0:
                errors.append(
                    f"{service_id}: invalid max document size"
                )

        fields = FORM_FIELDS_BY_SERVICE.get(
            service_id,
            (),
        )

        fieldnames = [
            field.fieldname
            for field in fields
        ]

        if len(fieldnames) != len(set(fieldnames)):
            errors.append(
                f"{service_id}: duplicate form fieldname"
            )

        for field in fields:
            form_field_count += 1

            if not re.fullmatch(
                r"[a-z0-9]+(?:_[a-z0-9]+)*",
                field.fieldname,
            ):
                errors.append(
                    f"{service_id}: invalid fieldname "
                    f"{field.fieldname!r}"
                )

            if not field.label.strip():
                errors.append(
                    f"{service_id}: form label is empty"
                )

            if field.fieldtype not in ALLOWED_FIELD_TYPES:
                errors.append(
                    f"{service_id}: unsupported fieldtype "
                    f"{field.fieldtype!r}"
                )

            searchable = (
                f"{field.fieldname} "
                f"{field.label}"
            ).lower()

            # Customer-upload/forms must never solicit authentication secrets.
            for forbidden in (
                "password",
                "passcode",
                "otp",
                "one_time_password",
                "secret_key",
            ):
                if forbidden in searchable:
                    errors.append(
                        f"{service_id}: forbidden credential "
                        f"field {field.fieldname!r}"
                    )

    # Exact live NTN baseline.
    ntn_documents = DOCUMENTS_BY_SERVICE[
        "ntn-registration"
    ]
    if [
        (
            item.document_key,
            item.title,
            item.document_type,
            item.is_required,
        )
        for item in ntn_documents
    ] != [
        (
            "cnic_front_image",
            "CNIC front image",
            "CNIC",
            True,
        ),
        (
            "cnic_back_image",
            "CNIC back image",
            "CNIC",
            True,
        ),
    ]:
        errors.append(
            "ntn-registration live document baseline changed"
        )

    ntn_fields = FORM_FIELDS_BY_SERVICE[
        "ntn-registration"
    ]
    if [
        item.fieldname
        for item in ntn_fields
    ] != [
        "active_mobile_number",
        "active_email_address",
        "residential_address",
    ]:
        errors.append(
            "ntn-registration live form baseline changed"
        )

    # Exact live GST baseline.
    gst_documents = DOCUMENTS_BY_SERVICE[
        "gst-registration"
    ]
    if [
        (
            item.title,
            item.document_type,
            item.is_required,
        )
        for item in gst_documents
    ] != [
        ("CNIC front and back", "CNIC", True),
        ("NTN certificate", "Tax", False),
        ("Business address proof", "Business", True),
        ("Electricity or gas bill", "Utility Bill", True),
        ("Bank account proof", "Financial", True),
    ]:
        errors.append(
            "gst-registration live document baseline changed"
        )

    gst_fields = FORM_FIELDS_BY_SERVICE[
        "gst-registration"
    ]
    if [
        item.fieldname
        for item in gst_fields
    ] != [
        "business_activity_details",
    ]:
        errors.append(
            "gst-registration live form baseline changed"
        )

    if errors:
        raise ValueError(
            "Invalid OMC catalogue requirements:\n- "
            + "\n- ".join(errors)
        )

    return {
        "ok": True,
        "services": len(service_ids),
        "document_templates": document_count,
        "required_document_templates": (
            required_document_count
        ),
        "form_fields": form_field_count,
        "preserved_live_services": sorted(
            PRESERVED_LIVE_SERVICE_IDS
        ),
    }
