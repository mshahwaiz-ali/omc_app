"""Compatibility wrappers for the mobile expense tracker API.

The Flutter app calls methods from omc_app.api.expense_tracker.  The
implementation lives in omc_app.api.expense, so this module keeps the public
API path stable without duplicating business logic.
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
