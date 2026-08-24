from __future__ import annotations

import threading
import unittest

import frappe
import pymysql
from frappe.tests.utils import FrappeTestCase


class TestPhaseNDatabaseAcceptance(FrappeTestCase):
    """Acceptance tests that hit real MariaDB constraints with no DB mocks."""

    def _connection_settings(self):
        if str(frappe.conf.db_type or "mariadb").lower() != "mariadb":
            self.skipTest("Phase N concurrency acceptance is defined for the MariaDB deployment.")
        settings = dict(frappe.db.get_connection_settings())
        settings["autocommit"] = False
        return settings

    def _raw_connection(self):
        return pymysql.connect(**self._connection_settings())

    def _cleanup_names(self, table: str, names: list[str]):
        if not names:
            return
        placeholders = ", ".join(["%s"] * len(names))
        connection = self._raw_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"DELETE FROM `{table}` WHERE name IN ({placeholders})",
                    tuple(names),
                )
            connection.commit()
        finally:
            connection.close()

    def _race(self, statements):
        barrier = threading.Barrier(len(statements))
        outcomes = []
        outcome_lock = threading.Lock()
        settings = self._connection_settings()

        def worker(query, values):
            connection = pymysql.connect(**settings)
            try:
                barrier.wait(timeout=10)
                with connection.cursor() as cursor:
                    cursor.execute(query, values)
                connection.commit()
                outcome = ("committed", None)
            except Exception as exc:  # assertion below validates exact DB outcome
                connection.rollback()
                outcome = ("error", exc)
            finally:
                connection.close()
            with outcome_lock:
                outcomes.append(outcome)

        threads = [
            threading.Thread(target=worker, args=statement, daemon=True)
            for statement in statements
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=20)

        self.assertFalse(
            any(thread.is_alive() for thread in threads),
            "Concurrent database acceptance worker did not terminate.",
        )
        self.assertEqual(len(outcomes), len(statements))
        return outcomes

    def _assert_one_unique_winner(self, outcomes):
        committed = [result for result in outcomes if result[0] == "committed"]
        errors = [result[1] for result in outcomes if result[0] == "error"]
        self.assertEqual(len(committed), 1, outcomes)
        self.assertEqual(len(errors), 1, outcomes)
        self.assertIsInstance(errors[0], pymysql.IntegrityError, outcomes)
        self.assertEqual(errors[0].args[0], 1062, outcomes)

    def test_required_unique_constraints_exist_in_mariadb(self):
        expected_unique_columns = {
            "tabOMC Accounting Link": {
                "source_key",
                "base_invoice_key",
                "base_request_key",
            },
            "tabOMC Bridge Operation": {"operation_key", "service_request"},
            "tabOMC Reconciliation Run": {"run_id"},
            "tabOMC Reconciliation Checkpoint": {"checkpoint_key"},
            "tabOMC Technical Quarantine": {"quarantine_key"},
            "tabOMC Reconciliation Review": {"review_key"},
        }
        for table, expected in expected_unique_columns.items():
            rows = frappe.db.sql(f"SHOW INDEX FROM `{table}`", as_dict=True)
            actual = {
                row.Column_name
                for row in rows
                if int(row.Non_unique or 0) == 0 and row.Key_name != "PRIMARY"
            }
            self.assertTrue(expected.issubset(actual), (table, expected, actual))

    def test_reconciliation_queue_indexes_exist(self):
        expected = {
            "tabOMC Technical Quarantine": "idx_omc_quarantine_queue",
            "tabOMC Reconciliation Review": "idx_omc_review_queue",
            "tabOMC Reconciliation Run": "idx_omc_reconciliation_run",
            "tabOMC Reconciliation Checkpoint": "idx_omc_reconciliation_checkpoint",
        }
        for table, key_name in expected.items():
            rows = frappe.db.sql(f"SHOW INDEX FROM `{table}`", as_dict=True)
            self.assertIn(key_name, {row.Key_name for row in rows}, table)

    def test_system_manager_has_no_omc_doctype_permission_rows(self):
        for table in ("tabDocPerm", "tabCustom DocPerm"):
            count = frappe.db.sql(
                f"""
                SELECT COUNT(*)
                FROM `{table}`
                WHERE parent LIKE 'OMC %'
                  AND role = 'System Manager'
                """
            )[0][0]
            self.assertEqual(int(count or 0), 0, table)

    def test_bridge_service_request_unique_constraint_wins_concurrent_race(self):
        token = frappe.generate_hash(length=12)
        request_name = f"N-BRIDGE-REQ-{token}"
        names = [f"N-BRIDGE-A-{token}", f"N-BRIDGE-B-{token}"]
        query = """
            INSERT INTO `tabOMC Bridge Operation`
                (name, operation_key, operation_type, service_request, state, source_version, attempt_count)
            VALUES (%s, %s, 'Activate Request', %s, 'Pending', %s, 0)
        """
        try:
            outcomes = self._race(
                [
                    (query, (names[0], f"op-a-{token}", request_name, f"v-a-{token}")),
                    (query, (names[1], f"op-b-{token}", request_name, f"v-b-{token}")),
                ]
            )
            self._assert_one_unique_winner(outcomes)
        finally:
            self._cleanup_names("tabOMC Bridge Operation", names)

    def test_accounting_base_invoice_unique_constraint_wins_concurrent_race(self):
        token = frappe.generate_hash(length=12)
        invoice_key = f"N-INVOICE-{token}"
        names = [f"N-LINK-A-{token}", f"N-LINK-B-{token}"]
        query = """
            INSERT INTO `tabOMC Accounting Link`
                (name, source_key, service_request, sales_invoice, base_invoice_key,
                 base_request_key, erp_customer, company, accounting_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'Unmatched')
        """
        try:
            outcomes = self._race(
                [
                    (
                        query,
                        (
                            names[0],
                            f"source-a-{token}",
                            f"N-REQ-A-{token}",
                            invoice_key,
                            invoice_key,
                            f"N-REQ-A-{token}",
                            f"N-CUSTOMER-{token}",
                            f"N-COMPANY-{token}",
                        ),
                    ),
                    (
                        query,
                        (
                            names[1],
                            f"source-b-{token}",
                            f"N-REQ-B-{token}",
                            invoice_key,
                            invoice_key,
                            f"N-REQ-B-{token}",
                            f"N-CUSTOMER-{token}",
                            f"N-COMPANY-{token}",
                        ),
                    ),
                ]
            )
            self._assert_one_unique_winner(outcomes)
        finally:
            self._cleanup_names("tabOMC Accounting Link", names)

    def test_accounting_base_request_unique_constraint_wins_concurrent_race(self):
        token = frappe.generate_hash(length=12)
        request_key = f"N-REQUEST-{token}"
        names = [f"N-REQ-LINK-A-{token}", f"N-REQ-LINK-B-{token}"]
        query = """
            INSERT INTO `tabOMC Accounting Link`
                (name, source_key, service_request, sales_invoice, base_invoice_key,
                 base_request_key, erp_customer, company, accounting_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'Unmatched')
        """
        try:
            outcomes = self._race(
                [
                    (
                        query,
                        (
                            names[0],
                            f"req-source-a-{token}",
                            request_key,
                            f"N-INVOICE-A-{token}",
                            f"N-INVOICE-A-{token}",
                            request_key,
                            f"N-CUSTOMER-{token}",
                            f"N-COMPANY-{token}",
                        ),
                    ),
                    (
                        query,
                        (
                            names[1],
                            f"req-source-b-{token}",
                            request_key,
                            f"N-INVOICE-B-{token}",
                            f"N-INVOICE-B-{token}",
                            request_key,
                            f"N-CUSTOMER-{token}",
                            f"N-COMPANY-{token}",
                        ),
                    ),
                ]
            )
            self._assert_one_unique_winner(outcomes)
        finally:
            self._cleanup_names("tabOMC Accounting Link", names)

    def test_allocation_rows_allow_multiple_null_base_keys(self):
        token = frappe.generate_hash(length=12)
        names = [f"N-ALLOC-A-{token}", f"N-ALLOC-B-{token}"]
        request_name = f"N-ALLOC-REQ-{token}"
        invoice_name = f"N-ALLOC-INVOICE-{token}"
        connection = self._raw_connection()
        try:
            with connection.cursor() as cursor:
                for index, name in enumerate(names, start=1):
                    cursor.execute(
                        """
                        INSERT INTO `tabOMC Accounting Link`
                            (name, source_key, service_request, sales_invoice,
                             payment_entry, base_invoice_key, base_request_key,
                             erp_customer, company, accounting_status, allocated_amount)
                        VALUES (%s, %s, %s, %s, %s, NULL, NULL, %s, %s,
                                'Partially Settled', 1)
                        """,
                        (
                            name,
                            f"allocation-{index}-{token}",
                            request_name,
                            invoice_name,
                            f"N-PE-{index}-{token}",
                            f"N-CUSTOMER-{token}",
                            f"N-COMPANY-{token}",
                        ),
                    )
            connection.commit()
        finally:
            connection.close()
        try:
            verify = self._raw_connection()
            try:
                with verify.cursor() as cursor:
                    cursor.execute(
                        "SELECT COUNT(*) FROM `tabOMC Accounting Link` WHERE name IN (%s, %s)",
                        tuple(names),
                    )
                    count = cursor.fetchone()[0]
                self.assertEqual(int(count or 0), 2)
            finally:
                verify.close()
        finally:
            self._cleanup_names("tabOMC Accounting Link", names)
