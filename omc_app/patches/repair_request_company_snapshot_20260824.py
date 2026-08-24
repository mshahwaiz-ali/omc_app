"""Repair the immutable request company authority field if it is missing.

Some restored or cloned sites may retain the historical Patch Log entry while
the Custom Field itself is absent. Re-run the existing idempotent field
creation so company authority cannot silently remain disabled.
"""

from omc_app.patches.add_request_company_snapshot_20260819 import (
    execute as ensure_company_snapshot,
)


def execute():
    ensure_company_snapshot()
