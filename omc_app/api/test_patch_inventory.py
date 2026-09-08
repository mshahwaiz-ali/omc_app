from __future__ import annotations

import importlib
from pathlib import Path

from frappe.tests.utils import FrappeTestCase


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
PATCHES_FILE = PACKAGE_ROOT / "patches.txt"
PATCH_ROOT = PACKAGE_ROOT / "patches"

DEAD_LEGACY_PATCH_MODULES = {
    "activate_role_capability_model_20260719",
    "add_referral_workspace_links",
    "consolidate_omc_roles",
    "create_omc_roles",
    "finalize_omc_role_model",
    "fix_omc_customer_user_type",
    "fix_omc_field_role_desk_access",
    "fix_omc_role_desk_access",
    "fix_referral_workspace_placement",
    "simplify_omc_roles_20260710",
    "sync_canonical_roles_20260712",
}

EXPLICIT_SETUP_UTILITY_MODULES = {
    "seed_business_rental_tax_slabs",
    "seed_erp_task_types_and_service_mappings",
    "seed_tax_calculator_defaults",
}


def _registered_patch_modules() -> list[str]:
    modules = []
    for raw_line in PATCHES_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("["):
            continue
        modules.append(line)
    return modules


class TestPatchInventory(FrappeTestCase):
    def test_every_registered_patch_module_resolves(self):
        modules = _registered_patch_modules()
        self.assertTrue(modules)

        for dotted_path in modules:
            module = importlib.import_module(dotted_path)
            self.assertTrue(
                callable(getattr(module, "execute", None)),
                dotted_path,
            )

    def test_dead_legacy_patch_files_are_absent(self):
        present = {
            path.stem
            for path in PATCH_ROOT.glob("*.py")
            if path.name != "__init__.py"
        }
        self.assertFalse(DEAD_LEGACY_PATCH_MODULES & present)

    def test_explicit_setup_utilities_remain_available(self):
        present = {
            path.stem
            for path in PATCH_ROOT.glob("*.py")
            if path.name != "__init__.py"
        }
        self.assertTrue(EXPLICIT_SETUP_UTILITY_MODULES <= present)
