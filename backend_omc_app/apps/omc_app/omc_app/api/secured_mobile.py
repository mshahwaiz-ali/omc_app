"""Permission-guarded mobile API overrides.

These wrappers keep customer-facing mobile routes stable while enforcing
server-side capability checks for internal-only service case actions.
"""

import frappe

from omc_app.api import mobile


@frappe.whitelist()
def update_service_case_status(
    case_id=None,
    status=None,
    note=None,
    expected_completion_date=None,
):
    """Allow only internal workspace users to update service case status."""

    mobile._assert_internal_workspace_access()

    return mobile.update_service_case_status(
        case_id=case_id,
        status=status,
        note=note,
        expected_completion_date=expected_completion_date,
    )


@frappe.whitelist()
def update_service_document_status(document_id=None, status=None, remarks=None):
    """Allow only internal workspace users to approve/reject documents."""

    mobile._assert_internal_workspace_access()

    return mobile.update_service_document_status(
        document_id=document_id,
        status=status,
        remarks=remarks,
    )
