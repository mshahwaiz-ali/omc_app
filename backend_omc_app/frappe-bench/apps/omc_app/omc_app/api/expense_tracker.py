"""Legacy compatibility wrappers for older mobile expense API paths.

Current Flutter clients call the canonical methods in ``omc_app.api.expense``.
This module remains temporarily so already-installed older clients can continue
using the historical ``omc_app.api.expense_tracker`` dotted paths without
duplicating any expense business logic. Remove it only after the supported
mobile-version cutoff confirms those legacy routes are no longer in use.
"""

from omc_app.api.expense import (  # noqa: F401
    bulk_sync_expense_entries,
    create_expense_entry,
    delete_expense_entry,
    generate_expense_report,
    get_expense_budgets,
    get_expense_categories,
    get_expense_config,
    get_expense_entries,
    get_expense_summary,
    save_expense_budget,
    update_expense_entry,
    upload_expense_receipt,
)
