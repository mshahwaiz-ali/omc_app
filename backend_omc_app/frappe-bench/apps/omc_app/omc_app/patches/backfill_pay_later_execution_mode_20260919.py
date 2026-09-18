from __future__ import annotations

import frappe


REQUEST_TABLE = "tabOMC Service Request"
PAYMENT_TABLE = "tabOMC Service Payment"
RECEIPT_TABLE = "tabOMC Payment Receipt"


def _table_exists(table: str) -> bool:
    return bool(frappe.db.sql("show tables like %s", table))


def _column_exists(table: str, column: str) -> bool:
    if not _table_exists(table):
        return False
    return column in [row[0] for row in frappe.db.sql(f"desc `{table}`")]


def execute() -> None:
    if not _column_exists(REQUEST_TABLE, "payment_execution_mode"):
        return
    if not _column_exists(REQUEST_TABLE, "pay_later_reason"):
        return

    frappe.db.sql(
        f"""
        update `{REQUEST_TABLE}`
        set payment_execution_mode = 'Prepaid'
        where coalesce(payment_execution_mode, '') = ''
        """
    )

    frappe.db.sql(
        f"""
        update `{REQUEST_TABLE}`
        set
            payment_execution_mode = 'Pay Later',
            pay_later_reason = case
                when coalesce(pay_later_reason, '') = ''
                then 'Legacy post-paid approval migrated from frozen payment policy.'
                else pay_later_reason
            end,
            expires_at = null
        where payment_policy_snapshot = 'Post-paid Approval'
          and coalesce(post_paid_approved_by, '') != ''
          and post_paid_approved_at is not null
          and not exists (
              select 1
              from `tabOMC Accounting Link` link
              where link.service_request = `{REQUEST_TABLE}`.name
                and (
                    coalesce(link.sales_invoice, '') != ''
                    or coalesce(link.payment_entry, '') != ''
                    or coalesce(link.allocated_amount, 0) > 0
                )
          )
          and not exists (
              select 1
              from `{RECEIPT_TABLE}` receipt
              where receipt.service_request = `{REQUEST_TABLE}`.name
                and receipt.review_status in ('Submitted', 'Verified')
          )
        """
    )

    if not _table_exists(PAYMENT_TABLE):
        return
    if not _column_exists(PAYMENT_TABLE, "status"):
        return

    receipt_join = ""
    receipt_guard = ""
    if _table_exists(RECEIPT_TABLE):
        receipt_join = f"""
        left join `{RECEIPT_TABLE}` receipt
          on receipt.service_payment = payment.name
         and receipt.review_status in ('Submitted', 'Verified')
        """
        receipt_guard = "and receipt.name is null"

    frappe.db.sql(
        f"""
        update `{PAYMENT_TABLE}` payment
        inner join `{REQUEST_TABLE}` request
          on request.name = payment.service_request
        {receipt_join}
        set payment.status = 'Deferred'
        where request.payment_execution_mode = 'Pay Later'
          and payment.status in ('Pending', 'Rejected')
          and coalesce(payment.accounted_amount, 0) <= 0
          and coalesce(payment.linked_invoice, '') = ''
          and coalesce(payment.linked_payment_entry, '') = ''
          and coalesce(payment.accounting_status, 'Unmatched') = 'Unmatched'
          {receipt_guard}
        """
    )
