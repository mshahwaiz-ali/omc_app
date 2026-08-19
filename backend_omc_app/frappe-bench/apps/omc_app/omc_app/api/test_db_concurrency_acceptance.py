from __future__ import annotations

import queue
import threading
import uuid
import unittest

import frappe
from frappe.tests.utils import FrappeTestCase


@unittest.skipUnless(getattr(frappe.conf, "db_type", "mariadb") == "mariadb", "MariaDB acceptance test")
class TestDatabaseConcurrencyAcceptance(FrappeTestCase):
    """Database-level acceptance tests; deliberately no mocked DB calls."""

    def setUp(self):
        super().setUp()
        self.site = frappe.local.site
        self.prefix = f"OMC-ACCEPT-{uuid.uuid4().hex[:12]}"

    def tearDown(self):
        frappe.db.sql(
            "DELETE FROM `tabOMC Accounting Link` WHERE name LIKE %s",
            (f"{self.prefix}%",),
        )
        frappe.db.sql(
            "DELETE FROM `tabOMC Idempotency Record` WHERE name LIKE %s",
            (f"{self.prefix}%",),
        )
        frappe.db.commit()
        super().tearDown()

    def _thread(self, target, *args):
        result = queue.Queue()

        def worker():
            frappe.init(site=self.site)
            frappe.connect()
            try:
                target(result, *args)
            finally:
                frappe.destroy()

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()
        return thread, result

    @staticmethod
    def _insert_accounting_link(result, values):
        try:
            frappe.db.sql(
                """
                INSERT INTO `tabOMC Accounting Link`
                    (`name`, `owner`, `creation`, `modified`, `modified_by`, `docstatus`, `idx`,
                     `source_key`, `service_request`, `sales_invoice`, `base_invoice_key`,
                     `base_request_key`, `erp_customer`, `company`, `accounting_status`)
                VALUES
                    (%s, 'Administrator', NOW(6), NOW(6), 'Administrator', 0, 0,
                     %s, %s, %s, %s, %s, %s, %s, 'Unmatched')
                """,
                (
                    values["name"],
                    values["source_key"],
                    values["service_request"],
                    values["sales_invoice"],
                    values.get("base_invoice_key"),
                    values.get("base_request_key"),
                    values["erp_customer"],
                    values["company"],
                ),
            )
            frappe.db.commit()
            result.put(("success", ""))
        except Exception as exc:
            frappe.db.rollback()
            result.put(("error", type(exc).__name__))

    @staticmethod
    def _insert_idempotency_record(result, values):
        try:
            frappe.db.sql(
                """
                INSERT INTO `tabOMC Idempotency Record`
                    (`name`, `owner`, `creation`, `modified`, `modified_by`, `docstatus`, `idx`,
                     `dedupe_key`, `operation`, `actor`, `request_hash`, `state`, `expires_on`)
                VALUES
                    (%s, 'Administrator', NOW(6), NOW(6), 'Administrator', 0, 0,
                     %s, 'acceptance.test', 'Administrator', %s, 'Processing',
                     DATE_ADD(NOW(6), INTERVAL 1 HOUR))
                """,
                (values["name"], values["dedupe_key"], values["request_hash"]),
            )
            frappe.db.commit()
            result.put(("success", ""))
        except Exception as exc:
            frappe.db.rollback()
            result.put(("error", type(exc).__name__))

    def test_concurrent_same_invoice_allows_only_one_base_request_link(self):
        invoice = f"SINV-{self.prefix}"
        common = {
            "sales_invoice": invoice,
            "base_invoice_key": invoice,
            "erp_customer": f"CUST-{self.prefix}",
            "company": f"COMP-{self.prefix}",
        }
        first = {
            **common,
            "name": f"{self.prefix}-AL-1",
            "source_key": f"{self.prefix}-SOURCE-1",
            "service_request": f"{self.prefix}-REQ-1",
            "base_request_key": f"{self.prefix}-REQ-1",
        }
        second = {
            **common,
            "name": f"{self.prefix}-AL-2",
            "source_key": f"{self.prefix}-SOURCE-2",
            "service_request": f"{self.prefix}-REQ-2",
            "base_request_key": f"{self.prefix}-REQ-2",
        }

        t1, q1 = self._thread(self._insert_accounting_link, first)
        t2, q2 = self._thread(self._insert_accounting_link, second)
        t1.join(timeout=15)
        t2.join(timeout=15)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())
        outcomes = [q1.get_nowait()[0], q2.get_nowait()[0]]
        self.assertEqual(outcomes.count("success"), 1)
        self.assertEqual(outcomes.count("error"), 1)

    def test_concurrent_same_request_allows_only_one_base_invoice_link(self):
        request = f"{self.prefix}-REQ"
        common = {
            "service_request": request,
            "base_request_key": request,
            "erp_customer": f"CUST-{self.prefix}",
            "company": f"COMP-{self.prefix}",
        }
        first = {
            **common,
            "name": f"{self.prefix}-BR-1",
            "source_key": f"{self.prefix}-BSOURCE-1",
            "sales_invoice": f"SINV-{self.prefix}-1",
            "base_invoice_key": f"SINV-{self.prefix}-1",
        }
        second = {
            **common,
            "name": f"{self.prefix}-BR-2",
            "source_key": f"{self.prefix}-BSOURCE-2",
            "sales_invoice": f"SINV-{self.prefix}-2",
            "base_invoice_key": f"SINV-{self.prefix}-2",
        }

        t1, q1 = self._thread(self._insert_accounting_link, first)
        t2, q2 = self._thread(self._insert_accounting_link, second)
        t1.join(timeout=15)
        t2.join(timeout=15)
        outcomes = [q1.get_nowait()[0], q2.get_nowait()[0]]
        self.assertEqual(outcomes.count("success"), 1)
        self.assertEqual(outcomes.count("error"), 1)

    def test_multiple_allocation_rows_accept_null_base_uniqueness_keys(self):
        request = f"{self.prefix}-REQ-ALLOC"
        invoice = f"SINV-{self.prefix}-ALLOC"
        for index in (1, 2):
            result = queue.Queue()
            self._insert_accounting_link(
                result,
                {
                    "name": f"{self.prefix}-ALLOC-{index}",
                    "source_key": f"{self.prefix}-ALLOC-SOURCE-{index}",
                    "service_request": request,
                    "sales_invoice": invoice,
                    "base_invoice_key": None,
                    "base_request_key": None,
                    "erp_customer": f"CUST-{self.prefix}",
                    "company": f"COMP-{self.prefix}",
                },
            )
            self.assertEqual(result.get_nowait()[0], "success")

        count = frappe.db.count(
            "OMC Accounting Link",
            {"name": ["like", f"{self.prefix}-ALLOC-%"]},
        )
        self.assertEqual(count, 2)

    def test_concurrent_same_idempotency_key_allows_one_claim(self):
        dedupe_key = f"{self.prefix}-DEDUPE"
        first = {
            "name": f"{self.prefix}-IDEM-1",
            "dedupe_key": dedupe_key,
            "request_hash": f"{self.prefix}-HASH-1",
        }
        second = {
            "name": f"{self.prefix}-IDEM-2",
            "dedupe_key": dedupe_key,
            "request_hash": f"{self.prefix}-HASH-2",
        }
        t1, q1 = self._thread(self._insert_idempotency_record, first)
        t2, q2 = self._thread(self._insert_idempotency_record, second)
        t1.join(timeout=15)
        t2.join(timeout=15)
        outcomes = [q1.get_nowait()[0], q2.get_nowait()[0]]
        self.assertEqual(outcomes.count("success"), 1)
        self.assertEqual(outcomes.count("error"), 1)
