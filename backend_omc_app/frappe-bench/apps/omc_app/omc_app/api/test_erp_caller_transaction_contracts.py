from __future__ import annotations

import ast
import inspect
from pathlib import Path

from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service, erp_sync_recovery


def _qualified_name(node: ast.AST) -> str:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        parent = _qualified_name(node.value)
        return f"{parent}.{node.attr}" if parent else node.attr
    return ""


def _call_lines(function) -> dict[str, list[int]]:
    result: dict[str, list[int]] = {}

    for node in ast.walk(_function_node(function)):
        if not isinstance(node, ast.Call):
            continue
        name = _qualified_name(node.func)
        result.setdefault(name, []).append(node.lineno)

    return result


def _function_node(function) -> ast.FunctionDef:
    source_file = Path(inspect.getsourcefile(function) or "")
    source = source_file.read_text(encoding="utf-8")
    tree = ast.parse(source)
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == function.__name__:
            return node
    raise AssertionError(f"Function node not found: {function.__name__}")


class TestErpCallerTransactionContracts(FrappeTestCase):
    def test_assisted_request_is_payment_first_and_framework_transactional(self):
        calls = _call_lines(assisted_service._create_request)

        self.assertEqual(calls.get("erp_activation.activate_request", []), [])
        self.assertGreaterEqual(len(calls["mobile._create_service_timeline_entry"]), 1)
        self.assertEqual(calls.get("frappe.db.commit", []), [])
        self.assertEqual(calls.get("frappe.db.rollback", []), [])

    def test_recovery_locks_before_legacy_repair_and_supports_durable_bridge(self):
        calls = _call_lines(erp_sync_recovery.retry_erp_sync)

        lock_line = calls["frappe.db.get_value"][0]
        activation_line = calls["erp_activation.activate_request"][0]
        self.assertLess(lock_line, activation_line)
        self.assertIn("bridge_outbox._recover_failed_operation", calls)
        self.assertEqual(calls.get("frappe.db.commit", []), [])
        self.assertEqual(calls.get("frappe.db.rollback", []), [])

    def test_assisted_request_does_not_swallow_downstream_failures(self):
        function = _function_node(assisted_service._create_request)
        handlers = [
            node
            for node in ast.walk(function)
            if isinstance(node, ast.ExceptHandler)
        ]
        self.assertEqual(
            handlers,
            [],
            "_create_request must not swallow downstream failures.",
        )

    def test_recovery_does_not_swallow_bridge_failures(self):
        function = _function_node(erp_sync_recovery.retry_erp_sync)
        handlers = [
            node
            for node in ast.walk(function)
            if isinstance(node, ast.ExceptHandler)
        ]
        self.assertEqual(
            handlers,
            [],
            "retry_erp_sync must not swallow ERP bridge failures.",
        )

    def test_request_and_recovery_use_framework_transactions(self):
        assisted_calls = _call_lines(assisted_service._create_request)
        recovery_calls = _call_lines(erp_sync_recovery.retry_erp_sync)

        self.assertEqual(assisted_calls.get("frappe.db.commit", []), [])
        self.assertEqual(recovery_calls.get("frappe.db.commit", []), [])
        self.assertEqual(assisted_calls.get("frappe.db.rollback", []), [])
        self.assertEqual(recovery_calls.get("frappe.db.rollback", []), [])
