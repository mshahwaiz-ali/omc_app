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
    def test_assisted_request_commit_occurs_after_bridge_and_side_effects(self):
        calls = _call_lines(assisted_service._create_request)

        bridge_line = calls["erp_service_task_adapter.sync_request"][0]
        commit_line = calls["frappe.db.commit"][0]
        assignment_line = calls["service_assignment.apply_assignment"][0]
        timeline_lines = calls["mobile._create_service_timeline_entry"]

        self.assertLess(bridge_line, assignment_line)
        self.assertLess(assignment_line, commit_line)
        self.assertGreaterEqual(len(timeline_lines), 1)
        self.assertTrue(all(line < commit_line for line in timeline_lines))

    def test_recovery_commit_occurs_after_bridge(self):
        calls = _call_lines(erp_sync_recovery.retry_erp_sync)

        bridge_line = calls["erp_service_task_adapter.sync_request"][0]
        commit_line = calls["frappe.db.commit"][0]

        self.assertLess(bridge_line, commit_line)

    def test_assisted_request_does_not_swallow_bridge_failures(self):
        function = _function_node(assisted_service._create_request)
        handlers = [
            node
            for node in ast.walk(function)
            if isinstance(node, ast.ExceptHandler)
        ]
        self.assertEqual(
            handlers,
            [],
            "_create_request must not swallow ERP bridge or downstream failures.",
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

    def test_each_caller_has_single_terminal_commit(self):
        assisted_calls = _call_lines(assisted_service._create_request)
        recovery_calls = _call_lines(erp_sync_recovery.retry_erp_sync)

        self.assertEqual(len(assisted_calls.get("frappe.db.commit", [])), 1)
        self.assertEqual(len(recovery_calls.get("frappe.db.commit", [])), 1)
        self.assertEqual(assisted_calls.get("frappe.db.rollback", []), [])
        self.assertEqual(recovery_calls.get("frappe.db.rollback", []), [])
