from __future__ import annotations

import re
from dataclasses import dataclass


ALLOWED_AUDIENCES = {
    "Public",
    "Customer",
    "Internal",
    "All",
}

ALLOWED_ICON_KEYS = {
    "services",
    "documents",
    "track",
    "payments",
    "support",
    "tax",
    "secure",
    "notifications",
}


@dataclass(frozen=True)
class OnboardingSlideSpec:
    slide_id: str
    title: str
    subtitle: str
    description: str
    icon_key: str
    accent_color: str
    benefits: tuple[str, ...]
    sort_order: int
    audience: str = "Public"
    enabled: int = 1
    image: str = ""
    primary_cta_label: str = ""
    primary_cta_route: str = ""
    secondary_cta_label: str = ""
    secondary_cta_route: str = ""

    @property
    def benefits_text(self) -> str:
        return "\n".join(self.benefits)


ONBOARDING_SLIDES = (
    OnboardingSlideSpec(
        slide_id="omc-onboarding-services",
        title="Start with the right OMC service",
        subtitle=(
            "Explore tax, registration, compliance, "
            "accounting and advisory services in one place."
        ),
        description=(
            "Review service information, requirements "
            "and next steps before you begin."
        ),
        icon_key="services",
        accent_color="#C81D32",
        benefits=(
            "Service catalogue",
            "Clear requirements",
            "Practical next steps",
        ),
        primary_cta_label="Create Account",
        primary_cta_route="/signup",
        secondary_cta_label="Login",
        secondary_cta_route="/login",
        sort_order=10,
    ),
    OnboardingSlideSpec(
        slide_id="omc-onboarding-documents",
        title="Know what you need before you submit",
        subtitle=(
            "See required documents and service-specific "
            "information before moving ahead."
        ),
        description=(
            "Prepare the right records and keep submitted "
            "documents linked to your service request."
        ),
        icon_key="documents",
        accent_color="#2563EB",
        benefits=(
            "Required document checklist",
            "Guided uploads",
            "Fewer missing items",
        ),
        primary_cta_label="Explore Services",
        primary_cta_route="/services",
        sort_order=20,
    ),
    OnboardingSlideSpec(
        slide_id="omc-onboarding-progress",
        title="Track documents, payments and progress",
        subtitle=(
            "Follow your request from submission through "
            "review, payment and service progress."
        ),
        description=(
            "See what has been received, what needs "
            "attention and where your request currently stands."
        ),
        icon_key="payments",
        accent_color="#0F766E",
        benefits=(
            "Request progress",
            "Document status",
            "Payment updates",
        ),
        primary_cta_label="Login",
        primary_cta_route="/login",
        sort_order=30,
    ),
    OnboardingSlideSpec(
        slide_id="omc-onboarding-tools",
        title="Keep tax and business records organized",
        subtitle=(
            "Use practical tax, expense and support tools "
            "alongside your OMC services."
        ),
        description=(
            "Keep useful records together and reach OMC "
            "support when you need assistance."
        ),
        icon_key="tax",
        accent_color="#4F46E5",
        benefits=(
            "Tax tools",
            "Expense tracking",
            "Support access",
        ),
        primary_cta_label="Get Started",
        primary_cta_route="/login",
        sort_order=40,
    ),
)


def validate_onboarding_manifest() -> dict:
    errors = []
    seen_ids = set()
    seen_orders = set()
    previous_order = -1

    for slide in ONBOARDING_SLIDES:
        if not slide.slide_id.startswith(
            "omc-onboarding-"
        ):
            errors.append(
                f"Invalid managed slide ID: "
                f"{slide.slide_id}"
            )

        if slide.slide_id in seen_ids:
            errors.append(
                f"Duplicate slide_id: "
                f"{slide.slide_id}"
            )
        seen_ids.add(slide.slide_id)

        if not slide.title.strip():
            errors.append(
                f"Missing title: "
                f"{slide.slide_id}"
            )

        if not slide.subtitle.strip():
            errors.append(
                f"Missing subtitle: "
                f"{slide.slide_id}"
            )

        if not slide.description.strip():
            errors.append(
                f"Missing description: "
                f"{slide.slide_id}"
            )

        if slide.audience not in ALLOWED_AUDIENCES:
            errors.append(
                f"Invalid audience for "
                f"{slide.slide_id}: "
                f"{slide.audience}"
            )

        if slide.icon_key not in ALLOWED_ICON_KEYS:
            errors.append(
                f"Invalid icon_key for "
                f"{slide.slide_id}: "
                f"{slide.icon_key}"
            )

        if not re.fullmatch(
            r"#[0-9A-Fa-f]{6}",
            slide.accent_color,
        ):
            errors.append(
                f"Invalid accent color for "
                f"{slide.slide_id}: "
                f"{slide.accent_color}"
            )

        if not 1 <= len(slide.benefits) <= 4:
            errors.append(
                f"{slide.slide_id} must have "
                f"1 to 4 benefits"
            )

        if any(
            not benefit.strip()
            for benefit in slide.benefits
        ):
            errors.append(
                f"Blank benefit in "
                f"{slide.slide_id}"
            )

        if slide.sort_order in seen_orders:
            errors.append(
                f"Duplicate sort_order: "
                f"{slide.sort_order}"
            )
        seen_orders.add(slide.sort_order)

        if slide.sort_order <= previous_order:
            errors.append(
                "Onboarding slides must have "
                "strictly increasing sort_order"
            )
        previous_order = slide.sort_order

        for label, route in (
            (
                slide.primary_cta_label,
                slide.primary_cta_route,
            ),
            (
                slide.secondary_cta_label,
                slide.secondary_cta_route,
            ),
        ):
            if bool(label.strip()) != bool(route.strip()):
                errors.append(
                    f"CTA label/route mismatch in "
                    f"{slide.slide_id}"
                )

            if route and not route.startswith("/"):
                errors.append(
                    f"Invalid CTA route in "
                    f"{slide.slide_id}: {route}"
                )

    if errors:
        raise ValueError(
            "Invalid onboarding manifest:\n- "
            + "\n- ".join(errors)
        )

    return {
        "slides": len(ONBOARDING_SLIDES),
        "valid": True,
    }
