from __future__ import annotations

from dataclasses import dataclass

from omc_app.setup.service_catalogue.manifest import SERVICES


ALLOWED_STAGE_KEYS = {
    "request_received",
    "under_review",
    "awaiting_customer",
    "awaiting_documents",
    "in_progress",
    "submitted",
    "approved",
    "completed",
    "rejected",
    "cancelled",
}


@dataclass(frozen=True)
class StageSpec:
    stage_key: str
    title: str
    description: str
    sort_order: int
    is_customer_visible: bool = True


def S(
    stage_key: str,
    title: str,
    description: str,
    sort_order: int,
) -> StageSpec:
    return StageSpec(
        stage_key=stage_key,
        title=title,
        description=description,
        sort_order=sort_order,
    )


STAGE_PROFILES: dict[str, tuple[StageSpec, ...]] = {
    "tax_filing": (
        S(
            "request_received",
            "Request received",
            "OMC records your request and the service information you submitted.",
            10,
        ),
        S(
            "under_review",
            "Details and documents review",
            "The team reviews the information and required documents. If anything is missing, OMC will ask you for it.",
            20,
        ),
        S(
            "in_progress",
            "Filing preparation",
            "After the required information, documents and payment are in place, OMC prepares the filing or return.",
            30,
        ),
        S(
            "submitted",
            "Submission or processing",
            "The filing is submitted or processed with the relevant authority where the service requires it.",
            40,
        ),
        S(
            "completed",
            "Service completed",
            "OMC closes the service after the required filing work and available outcome evidence are recorded.",
            50,
        ),
    ),
    "periodic_compliance": (
        S(
            "request_received",
            "Request received",
            "OMC records the filing period and information submitted with your request.",
            10,
        ),
        S(
            "under_review",
            "Period records review",
            "The team checks the records and supporting information required for the selected compliance period.",
            20,
        ),
        S(
            "in_progress",
            "Compliance preparation",
            "After the required records and payment are in place, OMC prepares the applicable filing or compliance work.",
            30,
        ),
        S(
            "submitted",
            "Submission or processing",
            "The filing or compliance submission is processed with the relevant authority where applicable.",
            40,
        ),
        S(
            "completed",
            "Service completed",
            "OMC records completion after the required compliance work and available submission evidence are in place.",
            50,
        ),
    ),
    "registration": (
        S(
            "request_received",
            "Request received",
            "OMC records your registration or authority-related service request.",
            10,
        ),
        S(
            "under_review",
            "Requirements review",
            "The team checks the submitted details and supporting documents and identifies any missing information.",
            20,
        ),
        S(
            "in_progress",
            "Application preparation",
            "After the required documents and payment are in place, OMC prepares the application or requested authority process.",
            30,
        ),
        S(
            "submitted",
            "Submitted or under processing",
            "The application or request is submitted or processed with the relevant authority where applicable.",
            40,
        ),
        S(
            "completed",
            "Service completed",
            "OMC closes the service after the required process and available outcome evidence are recorded.",
            50,
        ),
    ),
    "professional_work": (
        S(
            "request_received",
            "Request received",
            "OMC records the scope and information submitted for the service.",
            10,
        ),
        S(
            "under_review",
            "Records review",
            "The team reviews the available records and confirms what is needed to perform the work.",
            20,
        ),
        S(
            "in_progress",
            "Work in progress",
            "After the required records and payment are in place, the assigned team performs the agreed professional work.",
            30,
        ),
        S(
            "completed",
            "Service completed",
            "OMC records completion after the agreed work and available deliverables are finalised.",
            40,
        ),
    ),
    "advisory": (
        S(
            "request_received",
            "Request received",
            "OMC records the matter and information submitted with your request.",
            10,
        ),
        S(
            "under_review",
            "Case review",
            "The team reviews the matter, notices and supporting records relevant to the engagement.",
            20,
        ),
        S(
            "in_progress",
            "Preparation and engagement",
            "After the required information and payment are in place, OMC prepares and handles the agreed advisory or hearing work.",
            30,
        ),
        S(
            "completed",
            "Service completed",
            "OMC closes the engagement after the agreed work and available case outcome information are recorded.",
            40,
        ),
    ),
    "access_support": (
        S(
            "request_received",
            "Request received",
            "OMC records the access-support request and the identity details provided.",
            10,
        ),
        S(
            "under_review",
            "Identity details review",
            "The team checks the information required to handle the access issue safely.",
            20,
        ),
        S(
            "in_progress",
            "Access assistance in progress",
            "After the required verification and payment are in place, OMC handles the agreed access-support process.",
            30,
        ),
        S(
            "completed",
            "Service completed",
            "OMC closes the request after the agreed assistance has been completed.",
            40,
        ),
    ),
    "general": (
        S(
            "request_received",
            "Request received",
            "OMC records your request and the service details you submitted.",
            10,
        ),
        S(
            "under_review",
            "Requirements review",
            "The team reviews your requirement and confirms any information or documents needed before work proceeds.",
            20,
        ),
        S(
            "in_progress",
            "Work in progress",
            "After the agreed requirements and payment are in place, OMC performs the applicable service work.",
            30,
        ),
        S(
            "completed",
            "Service completed",
            "OMC records completion after the agreed service work has been performed.",
            40,
        ),
    ),
}


SERVICE_STAGE_PROFILE: dict[str, str] = {
    # Tax filing
    "aop-filling": "tax_filing",
    "business-tax-filing": "tax_filing",
    "family-contribute": "tax_filing",
    "house-wife-filing": "tax_filing",
    "nrp-tax-return-filing": "tax_filing",
    "other-sources": "tax_filing",
    "pensioner-filing": "tax_filing",
    "salaried-tax-filing": "tax_filing",

    # Periodic compliance
    "monthly-gst-filing": "periodic_compliance",
    "monthly-srb-filing": "periodic_compliance",
    "quarterly-wht-filing": "periodic_compliance",
    "secp-compliance": "periodic_compliance",

    # Registration / authority processes
    "7e-exemption-certificate": "registration",
    "aop-firm-registration-service": "registration",
    "fbr-pos-challan": "registration",
    "gst-registration": "registration",
    "ntn-modification": "registration",
    "ntn-registration": "registration",
    "p-s-w-registration-service": "registration",
    "pos-intergation": "registration",
    "pvt-registration-services": "registration",
    "registration-of-kcci": "registration",
    "srb-registration": "registration",

    # Accounting / audit
    "financials": "professional_work",
    "stock-audit": "professional_work",

    # Advisory / hearing
    "advocacy-service-hearing-with-commissioner": "advisory",

    # Access support
    "password-reset": "access_support",

    # General / custom
    "monthly-services": "general",
    "other-services": "general",
    "tax-club": "general",
    "ubl-lead": "general",
}


def stages_for_service(service_id: str) -> tuple[StageSpec, ...]:
    profile = SERVICE_STAGE_PROFILE.get(service_id)
    if not profile:
        return ()
    return STAGE_PROFILES[profile]


def validate_stage_manifest() -> dict[str, object]:
    service_ids = {service.service_id for service in SERVICES}
    mapped_ids = set(SERVICE_STAGE_PROFILE)

    errors: list[str] = []

    missing = sorted(service_ids - mapped_ids)
    unknown = sorted(mapped_ids - service_ids)

    if missing:
        errors.append(
            "missing stage profile mapping for: " + ", ".join(missing)
        )

    if unknown:
        errors.append(
            "stage profile mapping contains unknown services: "
            + ", ".join(unknown)
        )

    stage_count = 0

    for service_id in sorted(service_ids):
        profile_name = SERVICE_STAGE_PROFILE.get(service_id)

        if profile_name not in STAGE_PROFILES:
            errors.append(
                f"{service_id}: unknown stage profile {profile_name!r}"
            )
            continue

        stages = STAGE_PROFILES[profile_name]
        keys = [stage.stage_key for stage in stages]

        if len(keys) != len(set(keys)):
            errors.append(
                f"{service_id}: duplicate stage keys"
            )

        previous_sort_order = -1

        for stage in stages:
            stage_count += 1

            if stage.stage_key not in ALLOWED_STAGE_KEYS:
                errors.append(
                    f"{service_id}: unsupported stage key "
                    f"{stage.stage_key!r}"
                )

            if not stage.title.strip():
                errors.append(
                    f"{service_id}: stage title is empty"
                )

            if not stage.description.strip():
                errors.append(
                    f"{service_id}: stage description is empty"
                )

            if stage.sort_order <= previous_sort_order:
                errors.append(
                    f"{service_id}: stage sort order must increase"
                )

            previous_sort_order = stage.sort_order

    if errors:
        raise ValueError(
            "Stage manifest validation failed:\n- "
            + "\n- ".join(errors)
        )

    return {
        "services": len(service_ids),
        "profiles": len(STAGE_PROFILES),
        "stage_templates": stage_count,
        "valid": True,
    }
