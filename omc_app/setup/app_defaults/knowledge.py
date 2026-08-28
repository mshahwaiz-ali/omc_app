from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class KnowledgeSpec:
    article_id: str
    title: str
    category: str
    summary: str
    content: str
    is_featured: int
    sort_order: int
    published_on: str
    status: str = "Published"
    cover_image: str = ""


PUBLISHED_ON = "2026-08-28 00:00:00"

KNOWLEDGE_ARTICLES = (
    KnowledgeSpec(
        article_id="business-document-checklist",
        title="A simple business document checklist",
        category="Business Guide",
        summary=(
            "A practical way to keep the documents commonly needed for "
            "professional services organised and easy to find."
        ),
        content=(
            "Keep your important documents organised\n\n"
            "Create one consistent place for business and personal records "
            "that may be needed during an OMC service. A simple folder "
            "structure makes it easier to respond when a document is requested.\n\n"
            "Useful groups include:\n"
            "• Identity and contact information\n"
            "• Business and registration documents\n"
            "• Invoices and transaction records\n"
            "• Certificates, receipts and supporting evidence\n\n"
            "Document requirements differ by service. Always use the checklist "
            "shown for the service you select instead of assuming that the same "
            "documents apply to every request."
        ),
        is_featured=1,
        sort_order=10,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="choosing-right-service",
        title="How to choose the right OMC service",
        category="Getting Started",
        summary=(
            "Start with the outcome you need, review the service requirements, "
            "and check the documents before submitting a request."
        ),
        content=(
            "Start with the outcome you need\n\n"
            "Browse the OMC service catalogue and open the service that most "
            "closely matches what you need to complete. Review its description, "
            "requirements, pricing information where available, and required "
            "documents before starting.\n\n"
            "If two services appear similar, compare the expected outcome rather "
            "than choosing only by title. If your situation still does not fit "
            "clearly, contact OMC support before submitting a request. This can "
            "prevent avoidable corrections later in the process."
        ),
        is_featured=0,
        sort_order=20,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="before-submitting-service-request",
        title="Before you submit a service request",
        category="Getting Started",
        summary=(
            "A short pre-submission check can prevent missing information, "
            "document problems and avoidable follow-up."
        ),
        content=(
            "Use this quick check before submitting\n\n"
            "1. Confirm that the selected service matches the outcome you need.\n"
            "2. Review the service description and any form questions.\n"
            "3. Prepare the required documents in readable files.\n"
            "4. Check names, identification details and contact information for "
            "obvious mistakes.\n"
            "5. Review the displayed pricing or payment step where applicable.\n\n"
            "After submission, follow the request status in the app. If OMC needs "
            "additional information, respond through the request workflow or the "
            "support channel shown to your account."
        ),
        is_featured=0,
        sort_order=30,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="document-requirements-and-corrections",
        title="Understanding document requirements and corrections",
        category="Documents",
        summary=(
            "Learn how service-specific document checklists, upload rules and "
            "replacement requests work in the OMC app."
        ),
        content=(
            "Document requirements are service-specific\n\n"
            "Each requirement can carry its own file instructions, allowed file "
            "types, size limits and required or optional status. Use the checklist "
            "attached to your service request rather than a general list.\n\n"
            "If a submitted file needs correction, check the document status and "
            "the latest request activity. Upload a replacement only when the "
            "workflow allows it or when OMC asks for a corrected copy. Keep the "
            "replacement clear, complete and relevant to the requested item."
        ),
        is_featured=0,
        sort_order=40,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="payment-receipt-versus-verification",
        title="Payment receipt vs payment verification",
        category="Payments",
        summary=(
            "Uploading payment evidence records a receipt, but verification is a "
            "separate step before payment-dependent work is activated."
        ),
        content=(
            "A receipt is evidence, not final verification\n\n"
            "When a request requires payment, the app may ask you to upload a "
            "receipt or other payment evidence. That upload records what you "
            "submitted; it does not by itself confirm that funds were settled.\n\n"
            "The backend payment process verifies or reconciles the payment. A "
            "payment-dependent service moves forward only after the required "
            "verification succeeds. Use the payment status shown in the app as "
            "the current source of truth for that request."
        ),
        is_featured=0,
        sort_order=50,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="tracking-request-progress",
        title="How to track a request and understand the next step",
        category="Tracking",
        summary=(
            "Use request status, customer-visible stages and pending actions to "
            "understand where your case currently stands."
        ),
        content=(
            "Follow the latest request state\n\n"
            "Your service request can show its current status, document activity, "
            "payment information and customer-visible service stages. These views "
            "help you distinguish work in progress from an action that is waiting "
            "on you.\n\n"
            "If the request is waiting for documents, payment verification or a "
            "customer response, complete the action shown in the app. If no action "
            "is clear and the request appears unchanged, contact OMC support and "
            "include the request reference."
        ),
        is_featured=0,
        sort_order=60,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="organise-records-year-round",
        title="Keep tax and business records organised year-round",
        category="Record Keeping",
        summary=(
            "Consistent record keeping makes future compliance, filing and "
            "professional-service work easier to prepare."
        ),
        content=(
            "Small record-keeping habits reduce last-minute work\n\n"
            "Keep invoices, receipts, bank or payment evidence, registration "
            "records and relevant certificates in a consistent structure. Add "
            "records throughout the year instead of collecting everything only "
            "when a filing or service becomes urgent.\n\n"
            "Good organisation does not determine the accounting or tax treatment "
            "of a transaction, but it makes the underlying evidence easier to "
            "review. For a formal filing or financial decision, use the applicable "
            "records and current rules for your circumstances."
        ),
        is_featured=0,
        sort_order=70,
        published_on=PUBLISHED_ON,
    ),
    KnowledgeSpec(
        article_id="using-expense-tracker",
        title="Using the OMC expense tracker effectively",
        category="Tax & Tools",
        summary=(
            "Use consistent categories and clear descriptions to keep income and "
            "expense records easier to review later."
        ),
        content=(
            "Treat the tracker as an organised record, not a tax decision\n\n"
            "Record transactions consistently, choose the closest relevant "
            "category, and add enough description to understand the entry later. "
            "Keep supporting receipts or documents where they are needed for your "
            "own records.\n\n"
            "An entry or category in the app does not automatically make an amount "
            "deductible, taxable or correctly classified for accounting purposes. "
            "Those conclusions depend on the transaction, supporting records and "
            "the rules that apply to your circumstances."
        ),
        is_featured=0,
        sort_order=80,
        published_on=PUBLISHED_ON,
    ),
)


def validate_knowledge_manifest() -> dict[str, object]:
    if len(KNOWLEDGE_ARTICLES) != 8:
        raise ValueError("Knowledge manifest must contain exactly 8 articles.")

    ids = [article.article_id for article in KNOWLEDGE_ARTICLES]
    if len(ids) != len(set(ids)):
        raise ValueError("Knowledge article IDs must be unique.")

    orders = [article.sort_order for article in KNOWLEDGE_ARTICLES]
    if orders != sorted(orders) or len(orders) != len(set(orders)):
        raise ValueError("Knowledge sort orders must be unique and increasing.")

    featured = 0
    categories = set()

    for article in KNOWLEDGE_ARTICLES:
        if not article.article_id or not article.title.strip():
            raise ValueError("Knowledge article identity and title are required.")
        if not article.summary.strip() or not article.content.strip():
            raise ValueError(f"Knowledge article {article.article_id} is incomplete.")
        if "<" in article.content or ">" in article.content:
            raise ValueError(
                f"Knowledge article {article.article_id} must use plain text content."
            )
        if article.status != "Published":
            raise ValueError("Managed knowledge articles must be Published.")
        featured += int(bool(article.is_featured))
        categories.add(article.category)

    if featured != 1:
        raise ValueError("Exactly one managed knowledge article must be featured.")

    return {
        "articles": len(KNOWLEDGE_ARTICLES),
        "categories": len(categories),
        "featured": featured,
        "valid": True,
    }
