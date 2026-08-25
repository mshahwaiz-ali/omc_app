from __future__ import annotations

import json
from pathlib import Path

import frappe
from frappe.tests.utils import FrappeTestCase


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
DOCTYPE_ROOT = PACKAGE_ROOT / "omc_app" / "doctype"
WORKSPACE_PATH = (
    PACKAGE_ROOT / "omc_app" / "workspace" / "omc_app" / "omc_app.json"
)
FIXTURE_PATHS = (
    PACKAGE_ROOT / "fixtures" / "workspace.json",
    PACKAGE_ROOT / "omc_app" / "fixtures" / "workspace.json",
)


def _doctype_inventory() -> tuple[set[str], set[str]]:
    standalone: set[str] = set()
    child_tables: set[str] = set()

    for directory in sorted(DOCTYPE_ROOT.iterdir()):
        if not directory.is_dir():
            continue
        definition_path = directory / f"{directory.name}.json"
        if not definition_path.exists():
            continue

        definition = json.loads(definition_path.read_text(encoding="utf-8"))
        if definition.get("doctype") != "DocType":
            continue

        doctype_name = str(definition.get("name") or "").strip()
        if not doctype_name:
            continue

        target = child_tables if definition.get("istable") else standalone
        target.add(doctype_name)

    return standalone, child_tables


def _linked_omc_doctypes(workspace: dict) -> set[str]:
    return {
        str(link.get("link_to") or "").strip()
        for link in workspace.get("links") or []
        if link.get("type") == "Link"
        and link.get("link_type") == "DocType"
        and str(link.get("link_to") or "").startswith("OMC ")
    }


def _workspace_link_projection(workspace: dict) -> list[tuple]:
    return [
        (
            idx,
            link.get("label"),
            link.get("type"),
            link.get("link_type"),
            link.get("link_to"),
            int(link.get("is_query_report") or 0),
        )
        for idx, link in enumerate(workspace.get("links") or [], start=1)
    ]


class TestWorkspaceDoctypeCoverage(FrappeTestCase):
    def test_all_standalone_omc_doctypes_are_linked(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))
        standalone, child_tables = _doctype_inventory()
        linked = _linked_omc_doctypes(workspace)

        self.assertEqual(
            standalone - linked,
            set(),
            "Standalone OMC DocTypes missing from the OMC App workspace.",
        )
        self.assertEqual(
            child_tables & linked,
            set(),
            "Child-table DocTypes must not be exposed as standalone workspace links.",
        )

    def test_workspace_doctype_links_resolve_exactly(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))
        for doctype_name in sorted(_linked_omc_doctypes(workspace)):
            self.assertTrue(
                frappe.db.exists("DocType", doctype_name),
                f"Workspace link targets missing DocType: {doctype_name}",
            )

    def test_workspace_database_links_match_source_exactly(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))
        source_projection = _workspace_link_projection(workspace)
        rows = frappe.get_all(
            "Workspace Link",
            filters={"parent": "OMC App", "parenttype": "Workspace"},
            fields=["idx", "label", "type", "link_type", "link_to", "is_query_report"],
            order_by="idx asc",
            limit_page_length=200,
        )
        database_projection = [
            (
                int(row.get("idx") or 0),
                row.get("label"),
                row.get("type"),
                row.get("link_type"),
                row.get("link_to"),
                int(row.get("is_query_report") or 0),
            )
            for row in rows
        ]
        self.assertEqual(database_projection, source_projection)

    def test_workspace_source_and_fixtures_stay_in_sync(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))

        for fixture_path in FIXTURE_PATHS:
            fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
            self.assertEqual(len(fixture), 1)
            self.assertEqual(fixture[0]["name"], "OMC App")
            self.assertEqual(fixture[0]["content"], workspace["content"])
            self.assertEqual(fixture[0]["links"], workspace["links"])
            self.assertEqual(fixture[0]["quick_lists"], workspace["quick_lists"])

    def test_workspace_uses_current_functional_sections(self):
        workspace = json.loads(WORKSPACE_PATH.read_text(encoding="utf-8"))
        sections = [
            link["label"]
            for link in workspace.get("links") or []
            if link.get("type") == "Card Break"
        ]

        self.assertEqual(
            sections,
            [
                "Service Operations",
                "Service Configuration",
                "Customers & Onboarding",
                "Referrals & Commissions",
                "Finance & Reconciliation",
                "Support & Communications",
                "Mobile Experience & Content",
                "Tax Calculator",
                "Staff & Access Control",
                "Security & Technical Operations",
                "App Settings",
            ],
        )
