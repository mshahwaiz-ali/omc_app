from __future__ import unicode_literals
import json
import frappe
import requests
from frappe import _
from frappe.utils import now_datetime, flt, today
from frappe.utils.password import get_decrypted_password
from lead_app.lead_app.fcm import send_notification


def _get_epg_settings():
    """Load EPG Settings with decrypted password."""
    settings = frappe.get_single("EPG Settings")
    settings.decrypted_password = get_decrypted_password(
        "EPG Settings", "EPG Settings", "password"
    )
    return settings


def _make_epg_request(url, payload, is_sandbox=False):
    """Make HTTP POST request to EPG API."""
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    verify_ssl = not is_sandbox
    response = requests.post(
        url,
        json=payload,
        headers=headers,
        verify=verify_ssl,
        timeout=60
    )
    response.raise_for_status()
    return response.json()


@frappe.whitelist()
def initiate_payment(amount, order_id, order_name, reference_doctype=None, reference_name=None):
    """
    Step 1: Call EPG Registration API to initiate payment.
    Returns the PaymentPortal URL where user should be redirected.
    """
    amount = str(amount)
    if not amount or float(amount) <= 0:
        frappe.throw(_("Amount must be greater than 0"))
    if not order_id:
        frappe.throw(_("Order ID is required"))
    if not order_name:
        frappe.throw(_("Order Name is required"))

    # Prevent duplicate payment initiation
    if reference_doctype and reference_name:
        existing = frappe.db.exists(
            "EPG Payment Transaction",
            {
                "reference_doctype": reference_doctype,
                "reference_name": reference_name,
                "status": ["in", ["Initiated", "Redirected", "Pending"]],
            },
        )
        if existing:
            frappe.throw(
                _("A payment is already in progress for {0}. "
                  "Please wait for it to complete or check EPG Payment Transaction {1}.").format(
                    reference_name, existing
                )
            )

    settings = _get_epg_settings()

    # Build Registration payload
    payload = {
        "Registration": {
            "Currency": settings.currency,
            "ReturnPath": settings.return_path,
            "TransactionHint": settings.transaction_hint,
            "OrderID": order_id,
            "OrderName": order_name,
            "Channel": settings.channel,
            "Amount": amount,
            "Customer": settings.customer,
            "Store": settings.store,
            "Terminal": settings.terminal,
            "UserName": settings.username,
            "Password": settings.decrypted_password
        }
    }

    # Create transaction record
    txn = frappe.get_doc({
        "doctype": "EPG Payment Transaction",
        "order_id": order_id,
        "order_name": order_name,
        "amount": float(amount),
        "currency": settings.currency,
        "status": "Initiated",
        "user": frappe.session.user,
        "initiated_at": now_datetime(),
        "reference_doctype": reference_doctype,
        "reference_name": reference_name
    })
    txn.insert(ignore_permissions=True)
    frappe.db.commit()

    try:
        # Call EPG Registration API
        api_url = settings.api_url
        response_data = _make_epg_request(api_url, payload, settings.is_sandbox)

        transaction = response_data.get("Transaction", {})
        response_code = transaction.get("ResponseCode", "")
        transaction_id = transaction.get("TransactionID", "")
        payment_portal = transaction.get("PaymentPortal", "") or transaction.get("PaymentPage", "")

        # Store response
        txn.registration_response = json.dumps(response_data, indent=2)
        txn.response_code = response_code
        txn.response_description = transaction.get("ResponseDescription", "")

        if response_code == "0" and payment_portal:
            txn.transaction_id = transaction_id
            txn.payment_portal_url = payment_portal
            txn.status = "Redirected"
            txn.save(ignore_permissions=True)
            frappe.db.commit()

            return {
                "success": True,
                "transaction_name": txn.name,
                "transaction_id": transaction_id,
                "payment_portal_url": payment_portal
            }
        else:
            txn.status = "Failed"
            txn.error_message = transaction.get("ResponseDescription", "Registration failed")
            txn.save(ignore_permissions=True)
            frappe.db.commit()
            frappe.throw(
                _("Payment registration failed: {0}").format(
                    transaction.get("ResponseDescription", "Unknown error")
                )
            )

    except requests.exceptions.RequestException as e:
        txn.status = "Error"
        txn.error_message = str(e)
        txn.save(ignore_permissions=True)
        frappe.db.commit()
        frappe.throw(_("Failed to connect to payment gateway: {0}").format(str(e)))


@frappe.whitelist(allow_guest=True, methods=["GET", "POST"])
def epg_callback():
    """
    Step 3: EPG redirects user back here after 3D Secure authentication.
    Reads TransactionID and calls Finalization to complete payment.
    """
    args = frappe.form_dict
    transaction_id = args.get("TransactionID") or args.get("transactionid") or args.get("transactionId")

    if not transaction_id:
        frappe.respond_as_web_page(
            _("Payment Error"),
            _("No transaction ID received from payment gateway."),
            indicator_color="red"
        )
        return

    # Find the transaction record
    txn_name = frappe.db.get_value(
        "EPG Payment Transaction",
        {"transaction_id": transaction_id},
        "name"
    )

    if not txn_name:
        frappe.respond_as_web_page(
            _("Payment Error"),
            _("Transaction not found: {0}").format(transaction_id),
            indicator_color="red"
        )
        return

    txn = frappe.get_doc("EPG Payment Transaction", txn_name)

    # Prevent duplicate finalization
    if txn.status == "Success":
        frappe.respond_as_web_page(
            _("Payment Successful"),
            _("Payment for Order {0} of {1} {2} has already been completed successfully.<br><br>"
              "Transaction ID: {3}<br>Approval Code: {4}").format(
                txn.order_id, txn.currency, txn.amount,
                txn.transaction_id, txn.approval_code or "N/A"
            ),
            indicator_color="green"
        )
        return

    if txn.status == "Failed":
        frappe.respond_as_web_page(
            _("Payment Failed"),
            _("Payment for Order {0} has already been marked as failed.<br><br>"
              "Reason: {1}").format(txn.order_id, txn.response_description or "Unknown"),
            indicator_color="red"
        )
        return

    # Update status
    txn.status = "Pending"
    txn.save(ignore_permissions=True)
    frappe.db.commit()

    # Call Finalization
    result = _finalize_transaction(txn)

    # Send push notification to user
    _send_payment_notification(txn, result)

    if result.get("success"):
        # If payment was for a Sales Invoice, redirect back to it
        if txn.reference_doctype == "Sales Invoice" and txn.reference_name:
            frappe.local.response["type"] = "redirect"
            frappe.local.response["location"] = "/app/sales-invoice/" + txn.reference_name
            return

        frappe.respond_as_web_page(
            _("Payment Successful"),
            _("Your payment has been processed successfully!<br><br>"
              "<strong>Order ID:</strong> {0}<br>"
              "<strong>Amount:</strong> {1} {2}<br>"
              "<strong>Transaction ID:</strong> {3}<br>"
              "<strong>Approval Code:</strong> {4}<br>"
              "<strong>Card:</strong> {5}").format(
                txn.order_id, txn.currency, txn.amount,
                txn.transaction_id,
                result.get("approval_code", "N/A"),
                result.get("card_number", "N/A")
            ),
            indicator_color="green"
        )
    else:
        frappe.respond_as_web_page(
            _("Payment Failed"),
            _("Your payment could not be processed.<br><br>"
              "<strong>Order ID:</strong> {0}<br>"
              "<strong>Reason:</strong> {1}").format(
                txn.order_id,
                result.get("error", "Unknown error")
            ),
            indicator_color="red"
        )


def _send_payment_notification(txn, result):
    """Send push notification and create App Notification on payment completion."""
    try:
        if not txn.user:
            return

        token = frappe.db.get_value("User", txn.user, "device_id")

        if result.get("success"):
            title = "Payment Successful"
            body = "Your payment of {0} {1} for {2} has been completed successfully.".format(
                txn.currency, txn.amount, txn.order_name or txn.order_id
            )
        else:
            title = "Payment Failed"
            body = "Your payment of {0} {1} for {2} could not be processed. {3}".format(
                txn.currency, txn.amount, txn.order_name or txn.order_id,
                result.get("error", "")
            )

        if token:
            send_notification(token=token, title=title, body=body, payload={})

        frappe.get_doc({
            "doctype": "App Notification",
            "title": title,
            "sub_title": body,
            "user": txn.user,
        }).insert(ignore_permissions=True)
        frappe.db.commit()

    except Exception as e:
        frappe.log_error(f"Payment Notification Error: {str(e)}", "EPG Notification Error")


def _finalize_transaction(txn):
    """Internal function to call EPG Finalization API."""
    settings = _get_epg_settings()

    payload = {
        "Finalization": {
            "TransactionID": txn.transaction_id,
            "Customer": settings.customer,
            "UserName": settings.username,
            "Password": settings.decrypted_password
        }
    }

    try:
        api_url = settings.api_url
        response_data = _make_epg_request(api_url, payload, settings.is_sandbox)

        transaction = response_data.get("Transaction", {})
        response_code = transaction.get("ResponseCode", "")

        txn.finalization_response = json.dumps(response_data, indent=2)
        txn.response_code = response_code
        txn.response_description = transaction.get("ResponseDescription", "")
        txn.completed_at = now_datetime()

        if response_code == "0":
            txn.status = "Success"
            txn.approval_code = transaction.get("ApprovalCode", "")
            txn.card_number = transaction.get("CardNumber", "")
            txn.card_brand = transaction.get("CardBrand", "")
            txn.save(ignore_permissions=True)
            frappe.db.commit()

            # Auto-create Payment Entry for Sales Invoice
            payment_entry_name = _create_payment_entry(txn)
            if payment_entry_name:
                frappe.db.commit()

            return {
                "success": True,
                "approval_code": txn.approval_code,
                "card_number": txn.card_number,
                "card_brand": txn.card_brand,
                "payment_entry": payment_entry_name
            }
        else:
            txn.status = "Failed"
            txn.error_message = transaction.get("ResponseDescription", "Finalization failed")
            txn.save(ignore_permissions=True)
            frappe.db.commit()

            return {
                "success": False,
                "error": transaction.get("ResponseDescription", "Unknown error")
            }

    except requests.exceptions.RequestException as e:
        txn.status = "Error"
        txn.error_message = str(e)
        txn.save(ignore_permissions=True)
        frappe.db.commit()

        return {
            "success": False,
            "error": str(e)
        }


def _create_payment_entry(txn):
    """Auto-create a Payment Entry against the referenced Sales Invoice."""
    if txn.reference_doctype != "Sales Invoice" or not txn.reference_name:
        return None

    # Check if auto-create is enabled
    settings = frappe.get_single("EPG Settings")
    if not getattr(settings, "auto_create_payment_entry", 1):
        return None

    try:
        invoice = frappe.get_doc("Sales Invoice", txn.reference_name)

        if invoice.outstanding_amount <= 0:
            return None

        paid_amount = min(flt(txn.amount), flt(invoice.outstanding_amount))

        paid_to = (
            getattr(settings, "payment_account", None)
            or frappe.db.get_value("Company", invoice.company, "default_bank_account")
        )

        if not paid_to:
            frappe.log_error(
                title="EPG Payment Entry Creation Failed",
                message="No payment account configured in EPG Settings "
                        "and no default bank account found for company {0}".format(
                            invoice.company
                        ),
            )
            return None

        pe = frappe.get_doc({
            "doctype": "Payment Entry",
            "payment_type": "Receive",
            "posting_date": today(),
            "company": invoice.company,
            "mode_of_payment": "Credit Card",
            "party_type": "Customer",
            "party": invoice.customer,
            "paid_from": invoice.debit_to,
            "paid_to": paid_to,
            "paid_amount": paid_amount,
            "received_amount": paid_amount,
            "reference_no": txn.transaction_id or txn.name,
            "reference_date": today(),
            "remarks": "EPG Payment - Approval Code: {0}, Card: {1}".format(
                txn.approval_code or "N/A",
                txn.card_number or "N/A",
            ),
            "references": [
                {
                    "reference_doctype": "Sales Invoice",
                    "reference_name": invoice.name,
                    "total_amount": invoice.grand_total,
                    "outstanding_amount": invoice.outstanding_amount,
                    "allocated_amount": paid_amount,
                }
            ],
        })
        pe.insert(ignore_permissions=True)
        pe.submit()

        txn.db_set("payment_entry", pe.name, update_modified=False)

        return pe.name

    except Exception:
        frappe.log_error(
            title="EPG Auto Payment Entry Failed",
            message=frappe.get_traceback(),
        )
        return None


@frappe.whitelist()
def finalize_payment(transaction_name):
    """
    Manual finalization - can be called from desk if callback was missed.
    """
    txn = frappe.get_doc("EPG Payment Transaction", transaction_name)

    if txn.status == "Success":
        frappe.throw(_("This transaction is already finalized successfully."))

    if not txn.transaction_id:
        frappe.throw(_("No Transaction ID found. Registration may have failed."))

    result = _finalize_transaction(txn)

    if result.get("success"):
        frappe.msgprint(_("Payment finalized successfully! Approval Code: {0}").format(
            result.get("approval_code", "N/A")
        ))
    else:
        frappe.throw(_("Finalization failed: {0}").format(result.get("error", "Unknown error")))

    return result


@frappe.whitelist()
def get_epg_transactions(status=None, limit=20):
    """Get list of EPG Payment Transactions for current user."""
    filters = {"user": frappe.session.user}
    if status:
        filters["status"] = status

    transactions = frappe.get_all(
        "EPG Payment Transaction",
        filters=filters,
        fields=[
            "name", "order_id", "order_name", "transaction_id",
            "amount", "currency", "status", "initiated_at",
            "completed_at", "response_description"
        ],
        order_by="initiated_at desc",
        limit_page_length=int(limit)
    )
    return transactions
