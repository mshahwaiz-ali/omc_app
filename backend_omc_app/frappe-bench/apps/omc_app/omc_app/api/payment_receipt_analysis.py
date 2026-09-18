from __future__ import annotations

import base64
import json
import re

import frappe
import requests
from frappe.utils import flt, now_datetime

from omc_app.api import access, payments, security


RECEIPT_DOCTYPE = "OMC Payment Receipt"
PAYMENT_DOCTYPE = "OMC Service Payment"
CONFIDENT_SUGGESTION_THRESHOLD = 0.85
LOW_CONFIDENCE_THRESHOLD = 0.50
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"

SUCCESS_STATUSES = {
    "approved",
    "complete",
    "completed",
    "paid",
    "processed",
    "success",
    "successful",
}

CRITICAL_WARNING_CODES = {
    "AMOUNT_EXCEEDS_INSTALLMENT",
    "BENEFICIARY_ACCOUNT_MISMATCH",
    "CURRENCY_MISMATCH",
    "DUPLICATE_FILE",
    "DUPLICATE_REFERENCE",
    "TRANSACTION_STATUS_NOT_SUCCESSFUL",
}

EXTRACTION_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "amount": {"type": ["number", "null"]},
        "currency": {"type": ["string", "null"]},
        "transaction_reference": {"type": ["string", "null"]},
        "transaction_date": {"type": ["string", "null"]},
        "transaction_time": {"type": ["string", "null"]},
        "bank_or_wallet": {"type": ["string", "null"]},
        "beneficiary_or_account": {"type": ["string", "null"]},
        "transaction_status": {"type": ["string", "null"]},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    },
    "required": [
        "amount",
        "currency",
        "transaction_reference",
        "transaction_date",
        "transaction_time",
        "bank_or_wallet",
        "beneficiary_or_account",
        "transaction_status",
        "confidence",
    ],
}


class ReceiptAnalysisError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def _text(value) -> str:
    return str(value or "").strip()


def _normalised_token(value) -> str:
    return re.sub(r"[^a-z0-9]+", "", _text(value).lower())


def _provider_config() -> dict:
    conf = getattr(frappe, "conf", None) or {}
    api_key = _text(
        conf.get("omc_openai_api_key")
        or conf.get("openai_api_key")
    )
    return {
        "api_key": api_key,
        "model": _text(conf.get("omc_receipt_ai_model")) or "gpt-5.6-luna",
    }


def operational() -> bool:
    return bool(_provider_config()["api_key"])


def _safe_error_code(exc: Exception) -> str:
    if isinstance(exc, ReceiptAnalysisError):
        return exc.code[:140]
    return type(exc).__name__[:140] or "ANALYSIS_FAILED"


def _mark_manual_review(receipt_name: str, code: str) -> dict:
    frappe.db.set_value(
        RECEIPT_DOCTYPE,
        receipt_name,
        {
            "ai_status": "Manual Review",
            "ai_error_code": _text(code)[:140],
            "ai_analyzed_at": now_datetime(),
        },
        update_modified=False,
    )
    return {
        "status": "manual_review",
        "receipt": receipt_name,
        "reason": _text(code)[:140],
    }


def schedule_analysis(receipt_name: str) -> dict:
    receipt_name = _text(receipt_name)
    if not receipt_name or not frappe.db.exists(RECEIPT_DOCTYPE, receipt_name):
        return {"status": "missing", "receipt": receipt_name}

    if not operational():
        return _mark_manual_review(receipt_name, "AI_NOT_CONFIGURED")

    try:
        frappe.db.set_value(
            RECEIPT_DOCTYPE,
            receipt_name,
            {
                "ai_status": "Queued",
                "ai_requested_at": now_datetime(),
                "ai_error_code": "",
            },
            update_modified=False,
        )
        frappe.enqueue(
            "omc_app.api.payment_receipt_analysis.analyze_receipt",
            queue="short",
            enqueue_after_commit=True,
            receipt_name=receipt_name,
        )
        return {"status": "queued", "receipt": receipt_name}
    except Exception as exc:
        return _mark_manual_review(
            receipt_name,
            f"SCHEDULING_{_safe_error_code(exc)}",
        )


def _receipt_file(receipt):
    file_name = frappe.db.get_value(
        "File",
        {
            "file_url": receipt.receipt_attachment,
            "attached_to_doctype": PAYMENT_DOCTYPE,
            "attached_to_name": receipt.service_payment,
        },
        "name",
    )
    if not file_name:
        raise ReceiptAnalysisError("RECEIPT_FILE_NOT_FOUND")

    file_doc = frappe.get_doc("File", file_name)
    content = file_doc.get_content()
    if isinstance(content, str):
        content = content.encode("utf-8")
    if not content:
        raise ReceiptAnalysisError("RECEIPT_FILE_EMPTY")

    filename = _text(
        getattr(file_doc, "file_name", None)
        or getattr(file_doc, "file_url", None)
        or "receipt"
    )
    return filename, bytes(content)


def _input_part(filename: str, content: bytes) -> dict:
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    encoded = base64.b64encode(content).decode("ascii")

    if extension == "pdf":
        return {
            "type": "input_file",
            "filename": filename,
            "file_data": encoded,
        }

    mime = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
    }.get(extension)
    if not mime:
        raise ReceiptAnalysisError("UNSUPPORTED_RECEIPT_FORMAT")

    return {
        "type": "input_image",
        "image_url": f"data:{mime};base64,{encoded}",
        "detail": "high",
    }


def _provider_payload(*, model: str, filename: str, content: bytes) -> dict:
    return {
        "model": model,
        "store": False,
        "input": [
            {
                "role": "developer",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "You extract payment receipt facts for a human finance reviewer. "
                            "Use only facts visibly supported by the receipt. "
                            "Do not infer missing transaction IDs, dates, accounts, amounts, "
                            "currencies, banks, or statuses. Return null when not visible. "
                            "Confidence is 0 to 1 for the extraction as a whole."
                        ),
                    }
                ],
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "Extract amount, currency, transaction/reference ID, date, time, "
                            "bank or wallet, beneficiary/account, transaction status, and confidence."
                        ),
                    },
                    _input_part(filename, content),
                ],
            },
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "omc_payment_receipt_analysis",
                "strict": True,
                "schema": EXTRACTION_SCHEMA,
            }
        },
        "max_output_tokens": 900,
    }


def _response_output_text(payload: dict) -> str:
    direct = payload.get("output_text")
    if isinstance(direct, str) and direct.strip():
        return direct.strip()

    for item in payload.get("output") or []:
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for part in item.get("content") or []:
            if (
                isinstance(part, dict)
                and part.get("type") == "output_text"
                and isinstance(part.get("text"), str)
                and part["text"].strip()
            ):
                return part["text"].strip()
    raise ReceiptAnalysisError("PROVIDER_OUTPUT_MISSING")


def _call_provider(*, filename: str, content: bytes) -> tuple[dict, str]:
    config = _provider_config()
    if not config["api_key"]:
        raise ReceiptAnalysisError("AI_NOT_CONFIGURED")

    response = requests.post(
        OPENAI_RESPONSES_URL,
        headers={
            "Authorization": f"Bearer {config['api_key']}",
            "Content-Type": "application/json",
        },
        json=_provider_payload(
            model=config["model"],
            filename=filename,
            content=content,
        ),
        timeout=(5, 60),
        allow_redirects=False,
    )

    if not response.ok:
        raise ReceiptAnalysisError(
            f"PROVIDER_HTTP_{int(response.status_code or 0)}"
        )

    try:
        body = response.json()
    except (TypeError, ValueError):
        raise ReceiptAnalysisError("PROVIDER_INVALID_JSON")

    try:
        extracted = json.loads(_response_output_text(body))
    except (TypeError, ValueError):
        raise ReceiptAnalysisError("PROVIDER_INVALID_STRUCTURED_OUTPUT")

    if not isinstance(extracted, dict):
        raise ReceiptAnalysisError("PROVIDER_INVALID_STRUCTURED_OUTPUT")
    return extracted, config["model"]


def _clean_nullable_text(value):
    value = _text(value)
    return value or None


def _normalise_extraction(data: dict) -> dict:
    amount = data.get("amount")
    try:
        amount = flt(amount, 6) if amount is not None else None
    except (TypeError, ValueError):
        amount = None

    try:
        confidence = float(data.get("confidence") or 0)
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = min(max(confidence, 0.0), 1.0)

    currency = _clean_nullable_text(data.get("currency"))
    if currency:
        currency = currency.upper()[:12]

    return {
        "amount": amount,
        "currency": currency,
        "transaction_reference": _clean_nullable_text(
            data.get("transaction_reference")
        ),
        "transaction_date": _clean_nullable_text(data.get("transaction_date")),
        "transaction_time": _clean_nullable_text(data.get("transaction_time")),
        "bank_or_wallet": _clean_nullable_text(data.get("bank_or_wallet")),
        "beneficiary_or_account": _clean_nullable_text(
            data.get("beneficiary_or_account")
        ),
        "transaction_status": _clean_nullable_text(
            data.get("transaction_status")
        ),
        "confidence": confidence,
    }


def _warning(code: str, message: str, *, severity="warning") -> dict:
    return {
        "code": code,
        "severity": severity,
        "message": message,
    }


def _duplicate_file_exists(receipt, receipt_sha256: str) -> bool:
    receipt_sha256 = _text(receipt_sha256)
    if not receipt_sha256:
        return False
    return bool(
        frappe.db.exists(
            RECEIPT_DOCTYPE,
            {
                "name": ["!=", receipt.name],
                "receipt_sha256": receipt_sha256,
            },
        )
    )


def _duplicate_reference_exists(receipt, reference: str) -> bool:
    reference = _text(reference)
    if not reference:
        return False

    if frappe.db.exists(
        RECEIPT_DOCTYPE,
        {
            "name": ["!=", receipt.name],
            "ai_detected_reference": reference,
        },
    ):
        return True

    return bool(
        frappe.db.exists(
            RECEIPT_DOCTYPE,
            {
                "name": ["!=", receipt.name],
                "submitted_reference": reference,
            },
        )
    )


def _active_payment_accounts(currency: str) -> list[dict]:
    rows = frappe.get_all(
        "OMC Payment Account",
        filters={"is_active": 1},
        fields=[
            "name",
            "bank_name",
            "account_title",
            "account_number",
            "iban",
            "currency",
        ],
        limit_page_length=100,
    )
    expected_currency = _text(currency).upper()
    return [
        dict(row)
        for row in rows
        if not _text(row.currency)
        or not expected_currency
        or _text(row.currency).upper() == expected_currency
    ]


def _beneficiary_matches(value: str, accounts: list[dict]) -> bool:
    detected = _normalised_token(value)
    if len(detected) < 4:
        return True

    for row in accounts:
        for fieldname in (
            "account_title",
            "account_number",
            "iban",
        ):
            candidate = _normalised_token(row.get(fieldname))
            if len(candidate) < 4:
                continue
            if detected in candidate or candidate in detected:
                return True
    return False


def _build_warnings(
    *,
    receipt,
    extraction: dict,
    expected_amount: float,
    expected_currency: str,
    payment_accounts: list[dict],
) -> list[dict]:
    warnings = []
    detected_amount = extraction.get("amount")
    expected_amount = max(flt(expected_amount or 0, 6), 0)
    expected_currency = _text(expected_currency).upper()

    if detected_amount is not None and detected_amount > 0 and expected_amount > 0:
        if detected_amount < expected_amount - 0.000001:
            warnings.append(
                _warning(
                    "PARTIAL_PAYMENT",
                    "Detected amount is below the installment amount.",
                    severity="info",
                )
            )
        elif detected_amount > expected_amount + 0.000001:
            warnings.append(
                _warning(
                    "AMOUNT_EXCEEDS_INSTALLMENT",
                    "Detected amount exceeds the installment amount.",
                )
            )

    detected_currency = _text(extraction.get("currency")).upper()
    if (
        detected_currency
        and expected_currency
        and detected_currency != expected_currency
    ):
        warnings.append(
            _warning(
                "CURRENCY_MISMATCH",
                "Detected currency does not match the payment currency.",
            )
        )

    if _duplicate_file_exists(receipt, getattr(receipt, "receipt_sha256", "")):
        warnings.append(
            _warning(
                "DUPLICATE_FILE",
                "The same receipt file appears on another payment evidence record.",
            )
        )

    reference = _text(extraction.get("transaction_reference"))
    if reference and _duplicate_reference_exists(receipt, reference):
        warnings.append(
            _warning(
                "DUPLICATE_REFERENCE",
                "The detected transaction reference appears on another receipt.",
            )
        )

    beneficiary = _text(extraction.get("beneficiary_or_account"))
    if (
        beneficiary
        and payment_accounts
        and not _beneficiary_matches(beneficiary, payment_accounts)
    ):
        warnings.append(
            _warning(
                "BENEFICIARY_ACCOUNT_MISMATCH",
                "Detected beneficiary/account does not match an active OMC payment account.",
            )
        )

    status = _normalised_token(extraction.get("transaction_status"))
    if status and status not in SUCCESS_STATUSES:
        warnings.append(
            _warning(
                "TRANSACTION_STATUS_NOT_SUCCESSFUL",
                "Detected transaction status is not Successful/Completed.",
            )
        )
    elif not status:
        warnings.append(
            _warning(
                "TRANSACTION_STATUS_UNREADABLE",
                "Transaction status could not be read from the receipt.",
                severity="info",
            )
        )

    return warnings


def _analysis_context(receipt):
    payment = frappe.get_doc(PAYMENT_DOCTYPE, receipt.service_payment)
    request = frappe.get_doc("OMC Service Request", payment.service_request)
    currency = _text(
        getattr(request, "pricing_currency", None)
        or getattr(payment, "currency", None)
    ) or "PKR"
    return {
        "payment": payment,
        "request": request,
        "expected_amount": max(flt(payment.amount or 0, 6), 0),
        "currency": currency,
        "payment_accounts": _active_payment_accounts(currency),
    }


def analyze_receipt(receipt_name: str):
    receipt_name = _text(receipt_name)
    if not receipt_name or not frappe.db.exists(RECEIPT_DOCTYPE, receipt_name):
        return {"status": "missing", "receipt": receipt_name}

    locked = frappe.db.get_value(
        RECEIPT_DOCTYPE,
        receipt_name,
        "name",
        for_update=True,
    )
    if not locked:
        return {"status": "missing", "receipt": receipt_name}

    receipt = frappe.get_doc(RECEIPT_DOCTYPE, locked)
    if _text(receipt.review_status) != "Submitted":
        return {
            "status": "skipped",
            "receipt": receipt.name,
            "reason": "REVIEW_ALREADY_DECIDED",
        }

    frappe.db.set_value(
        RECEIPT_DOCTYPE,
        receipt.name,
        {
            "ai_status": "Processing",
            "ai_error_code": "",
        },
        update_modified=False,
    )

    try:
        filename, content = _receipt_file(receipt)
        raw, model = _call_provider(
            filename=filename,
            content=content,
        )
        extraction = _normalise_extraction(raw)
        context = _analysis_context(receipt)
        warnings = _build_warnings(
            receipt=receipt,
            extraction=extraction,
            expected_amount=context["expected_amount"],
            expected_currency=context["currency"],
            payment_accounts=context["payment_accounts"],
        )

        manual_review = bool(
            extraction["confidence"] < LOW_CONFIDENCE_THRESHOLD
            or extraction["amount"] is None
            or extraction["amount"] <= 0
        )
        status = "Manual Review" if manual_review else "Completed"
        analyzed_at = now_datetime()

        values = {
            "ai_status": status,
            "ai_model": model,
            "ai_confidence": extraction["confidence"],
            "ai_detected_amount": extraction["amount"],
            "ai_detected_currency": extraction["currency"] or "",
            "ai_detected_reference": extraction["transaction_reference"] or "",
            "ai_detected_date": extraction["transaction_date"] or None,
            "ai_detected_time": extraction["transaction_time"] or None,
            "ai_detected_bank": extraction["bank_or_wallet"] or "",
            "ai_detected_beneficiary": extraction["beneficiary_or_account"] or "",
            "ai_detected_status": extraction["transaction_status"] or "",
            "ai_warnings_json": json.dumps(
                warnings,
                sort_keys=True,
                separators=(",", ":"),
            ),
            "ai_result_json": json.dumps(
                extraction,
                sort_keys=True,
                separators=(",", ":"),
            ),
            "ai_error_code": (
                "LOW_CONFIDENCE_OR_AMOUNT_UNREADABLE"
                if manual_review
                else ""
            ),
            "ai_analyzed_at": analyzed_at,
        }
        frappe.db.set_value(
            RECEIPT_DOCTYPE,
            receipt.name,
            values,
            update_modified=False,
        )
        security.audit_event(
            event_type="payment.receipt_ai_analyzed",
            target_doctype=RECEIPT_DOCTYPE,
            target_name=receipt.name,
            safe_reason=status.lower().replace(" ", "_"),
        )
        return {
            "status": status.lower().replace(" ", "_"),
            "receipt": receipt.name,
            "warnings": warnings,
            "confidence": extraction["confidence"],
        }
    except Exception as exc:
        code = _safe_error_code(exc)
        # Never log receipt bytes/base64 or provider response bodies.
        frappe.log_error(
            f"{type(exc).__name__}: {code}",
            f"OMC Receipt AI Analysis Failed: {receipt.name}",
        )
        return _mark_manual_review(receipt.name, code)


def analysis_summary(receipt) -> dict:
    try:
        warnings = json.loads(receipt.ai_warnings_json or "[]")
    except (TypeError, ValueError):
        warnings = []
    if not isinstance(warnings, list):
        warnings = []

    return {
        "receipt_evidence": receipt.name,
        "receipt_url": receipt.receipt_attachment or "",
        "status": _text(getattr(receipt, "ai_status", None)) or "Not Requested",
        "model": _text(getattr(receipt, "ai_model", None)),
        "confidence": flt(getattr(receipt, "ai_confidence", 0) or 0, 6),
        "detected_amount": getattr(receipt, "ai_detected_amount", None),
        "detected_currency": _text(getattr(receipt, "ai_detected_currency", None)),
        "detected_reference": _text(getattr(receipt, "ai_detected_reference", None)),
        "detected_date": str(getattr(receipt, "ai_detected_date", None) or ""),
        "detected_time": str(getattr(receipt, "ai_detected_time", None) or ""),
        "detected_bank": _text(getattr(receipt, "ai_detected_bank", None)),
        "detected_beneficiary": _text(
            getattr(receipt, "ai_detected_beneficiary", None)
        ),
        "detected_status": _text(getattr(receipt, "ai_detected_status", None)),
        "warnings": warnings,
        "manual_review_required": (
            _text(getattr(receipt, "ai_status", None)) == "Manual Review"
        ),
        "error_code": _text(getattr(receipt, "ai_error_code", None)),
    }


@frappe.whitelist(methods=["POST"])
def retry_analysis(receipt_name=None):
    receipt_name = _text(receipt_name)
    capabilities = access.get_mobile_capabilities()
    if not (
        capabilities.get("can_access_internal_workspace")
        and capabilities.get("can_review_payments")
    ):
        frappe.throw(
            "You do not have permission to analyze payment receipts.",
            frappe.PermissionError,
        )
    if not receipt_name or not frappe.db.exists(RECEIPT_DOCTYPE, receipt_name):
        frappe.throw("Receipt evidence not found.", frappe.DoesNotExistError)

    receipt = frappe.get_doc(RECEIPT_DOCTYPE, receipt_name)
    payments._assert_service_request_payment_access(
        receipt.service_request,
        internal_user=payments._current_user(),
    )
    if _text(receipt.review_status) != "Submitted":
        frappe.throw(
            "AI analysis cannot be retried after receipt review is complete.",
            frappe.ValidationError,
        )
    return schedule_analysis(receipt.name)
