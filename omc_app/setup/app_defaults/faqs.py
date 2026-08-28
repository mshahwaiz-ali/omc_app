from __future__ import annotations

from dataclasses import dataclass


ALLOWED_STATUSES = {
    "Draft",
    "Published",
    "Archived",
}

ALLOWED_CATEGORIES = {
    "Getting Started",
    "Services",
    "Documents",
    "Payments",
    "Tracking",
    "Account",
    "Support",
    "Tax & Tools",
}


@dataclass(frozen=True)
class FAQSpec:
    faq_id: str
    question: str
    answer: str
    category: str
    sort_order: int
    status: str = "Published"


FAQS = (
    FAQSpec(
        faq_id="omc-faq-what-can-i-do",
        question="What can I do in the OMC app?",
        answer=(
            "You can explore OMC services, review service requirements, "
            "manage eligible service requests, upload documents, follow "
            "payment and request progress, access support, and use available "
            "tax and expense tools from one place."
        ),
        category="Getting Started",
        sort_order=10,
    ),
    FAQSpec(
        faq_id="omc-faq-browse-before-account",
        question="Can I explore services before creating an account?",
        answer=(
            "Yes. Public service information and public app content can be "
            "viewed before you become an approved customer. Actions such as "
            "creating and managing your own service requests require the "
            "appropriate customer access."
        ),
        category="Getting Started",
        sort_order=20,
    ),
    FAQSpec(
        faq_id="omc-faq-account-approval",
        question="Why does my customer account need approval?",
        answer=(
            "Customer approval helps OMC confirm that the account is ready "
            "for protected customer actions. Until approval is complete, "
            "some features such as creating service requests, uploading "
            "request documents, payments, and customer-specific tracking "
            "may remain unavailable."
        ),
        category="Account",
        sort_order=30,
    ),
    FAQSpec(
        faq_id="omc-faq-existing-customer",
        question="I am already an OMC customer. Do I need a new account?",
        answer=(
            "Not necessarily. Existing customers may be able to activate or "
            "link their existing OMC customer identity instead of creating "
            "a duplicate customer relationship. Use the existing-account "
            "activation option when it applies to you."
        ),
        category="Account",
        sort_order=40,
    ),
    FAQSpec(
        faq_id="omc-faq-choose-service",
        question="How do I know which service to choose?",
        answer=(
            "Open the service details to review its description, requirements, "
            "fees or pricing information where available, and the expected "
            "process. If your situation does not clearly match a service, "
            "contact OMC support before submitting a request."
        ),
        category="Services",
        sort_order=50,
    ),
    FAQSpec(
        faq_id="omc-faq-service-requirements",
        question="Where can I see the documents required for a service?",
        answer=(
            "Required documents are linked to the relevant service and are "
            "shown as part of the service request workflow. Requirements can "
            "differ between services, so always review the checklist for the "
            "specific service you are requesting."
        ),
        category="Documents",
        sort_order=60,
    ),
    FAQSpec(
        faq_id="omc-faq-document-formats",
        question="Are there rules for document uploads?",
        answer=(
            "Yes. A document requirement can specify permitted file types, "
            "size limits, instructions, and whether the document is required "
            "or optional. Follow the instructions shown for that specific "
            "document before uploading it."
        ),
        category="Documents",
        sort_order=70,
    ),
    FAQSpec(
        faq_id="omc-faq-replace-document",
        question="What should I do if a submitted document needs correction?",
        answer=(
            "Check the request or document status for any action required. "
            "If a corrected or replacement document is requested, upload the "
            "appropriate file through the service workflow or follow the "
            "instructions provided by OMC."
        ),
        category="Documents",
        sort_order=80,
    ),
    FAQSpec(
        faq_id="omc-faq-payment-process",
        question="How does payment work for a service request?",
        answer=(
            "When payment is required, the request workflow provides the "
            "relevant payment step and available instructions. Payment must "
            "be verified by the backend process before a payment-dependent "
            "service is activated."
        ),
        category="Payments",
        sort_order=90,
    ),
    FAQSpec(
        faq_id="omc-faq-receipt-not-verification",
        question="Does uploading a payment receipt mean my payment is approved?",
        answer=(
            "No. Uploading a receipt records payment evidence, but it does "
            "not by itself confirm settlement. The payment status changes "
            "after the required verification or reconciliation is completed."
        ),
        category="Payments",
        sort_order=100,
    ),
    FAQSpec(
        faq_id="omc-faq-track-request",
        question="How can I track my service request?",
        answer=(
            "Use the tracking and service request screens to review the "
            "current request status, document activity, payment information, "
            "and customer-visible service progress available for that case."
        ),
        category="Tracking",
        sort_order=110,
    ),
    FAQSpec(
        faq_id="omc-faq-request-waiting",
        question="Why might my request be waiting for the next step?",
        answer=(
            "A request can be waiting for required documents, payment "
            "verification, review, or another step in the service process. "
            "Check the latest status and any pending actions shown in the app. "
            "If nothing is clear, contact OMC support."
        ),
        category="Tracking",
        sort_order=120,
    ),
    FAQSpec(
        faq_id="omc-faq-support",
        question="How do I contact OMC about a request or account issue?",
        answer=(
            "Use the support area available to your account. When asking "
            "about a particular service request, include the relevant request "
            "or case reference and enough detail for the OMC team to identify "
            "the issue."
        ),
        category="Support",
        sort_order=130,
    ),
    FAQSpec(
        faq_id="omc-faq-tax-calculator",
        question="Is the tax calculator a final tax assessment?",
        answer=(
            "No. The calculator is an informational tool based on the tax "
            "rules and inputs configured for the selected tax year. Actual "
            "tax treatment can depend on your circumstances, source records, "
            "current law, and filing position. Review the result before using "
            "it for a formal filing or financial decision."
        ),
        category="Tax & Tools",
        sort_order=140,
    ),
    FAQSpec(
        faq_id="omc-faq-expense-tracker",
        question="What is the expense tracker for?",
        answer=(
            "The expense tracker helps organize income and expense records "
            "inside the app. Categories can support general record keeping "
            "and tax-related organization, but an expense entry by itself "
            "does not determine its accounting or tax treatment."
        ),
        category="Tax & Tools",
        sort_order=150,
    ),
)


def validate_faq_manifest() -> dict:
    errors = []
    seen_ids = set()
    seen_orders = set()
    previous_order = -1

    if not 12 <= len(FAQS) <= 15:
        errors.append(
            "FAQ manifest must contain 12 to 15 FAQs"
        )

    for faq in FAQS:
        if not faq.faq_id.startswith("omc-faq-"):
            errors.append(
                f"Invalid managed FAQ ID: {faq.faq_id}"
            )

        if faq.faq_id in seen_ids:
            errors.append(
                f"Duplicate faq_id: {faq.faq_id}"
            )
        seen_ids.add(faq.faq_id)

        if not faq.question.strip():
            errors.append(
                f"Missing question: {faq.faq_id}"
            )

        if not faq.answer.strip():
            errors.append(
                f"Missing answer: {faq.faq_id}"
            )

        if faq.category not in ALLOWED_CATEGORIES:
            errors.append(
                f"Invalid category for {faq.faq_id}: "
                f"{faq.category}"
            )

        if faq.status not in ALLOWED_STATUSES:
            errors.append(
                f"Invalid status for {faq.faq_id}: "
                f"{faq.status}"
            )

        if faq.status != "Published":
            errors.append(
                f"Managed FAQ must be Published: "
                f"{faq.faq_id}"
            )

        if faq.sort_order in seen_orders:
            errors.append(
                f"Duplicate sort_order: "
                f"{faq.sort_order}"
            )
        seen_orders.add(faq.sort_order)

        if faq.sort_order <= previous_order:
            errors.append(
                "FAQ sort_order must be strictly increasing"
            )
        previous_order = faq.sort_order

    if errors:
        raise ValueError(
            "Invalid FAQ manifest:\n- "
            + "\n- ".join(errors)
        )

    return {
        "faqs": len(FAQS),
        "categories": len(
            {faq.category for faq in FAQS}
        ),
        "valid": True,
    }
