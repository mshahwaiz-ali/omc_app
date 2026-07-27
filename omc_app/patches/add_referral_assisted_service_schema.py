"""Backfill safe defaults and indexes for referral/assisted service schema."""

import frappe


def _has_field(doctype, fieldname):
    return frappe.get_meta(doctype).has_field(fieldname)


def _add_index(doctype, fields, name):
    if not frappe.db.exists("DocType", doctype):
        return
    available = [field for field in fields if _has_field(doctype, field)]
    if len(available) == len(fields):
        frappe.db.add_index(doctype, available, index_name=name)


def execute():
    if frappe.db.exists("DocType", "OMC Customer Profile"):
        if _has_field("OMC Customer Profile", "acquisition_source"):
            frappe.db.sql(
                """UPDATE `tabOMC Customer Profile`
                   SET acquisition_source = 'Existing'
                 WHERE IFNULL(acquisition_source, '') IN ('', 'Unknown')"""
            )
        if _has_field("OMC Customer Profile", "customer_origin"):
            frappe.db.sql(
                """UPDATE `tabOMC Customer Profile`
                   SET customer_origin = 'App Signup'
                 WHERE IFNULL(customer_origin, '') = ''"""
            )
        if _has_field("OMC Customer Profile", "linked_app_user"):
            frappe.db.sql(
                """UPDATE `tabOMC Customer Profile`
                   SET linked_app_user = user
                 WHERE IFNULL(linked_app_user, '') = ''
                   AND IFNULL(user, '') != ''"""
            )

    if frappe.db.exists("DocType", "OMC Service Request"):
        if _has_field("OMC Service Request", "submission_mode"):
            frappe.db.sql(
                """UPDATE `tabOMC Service Request`
                   SET submission_mode = 'Customer Self-Service'
                 WHERE IFNULL(submission_mode, '') = ''"""
            )
        if _has_field("OMC Service Request", "customer_mode"):
            frappe.db.sql(
                """UPDATE `tabOMC Service Request`
                   SET customer_mode = 'Self'
                 WHERE IFNULL(customer_mode, '') = ''"""
            )
        if _has_field("OMC Service Request", "submitted_by_user"):
            frappe.db.sql(
                """UPDATE `tabOMC Service Request`
                   SET submitted_by_user = requested_by
                 WHERE IFNULL(submitted_by_user, '') = ''
                   AND IFNULL(requested_by, '') != ''"""
            )

    _add_index("OMC Referral", ["referrer_user", "is_active"], "idx_omc_referral_owner_active")
    _add_index("OMC Referral", ["referred_customer_profile", "is_active"], "idx_omc_referral_customer_active")
    _add_index("OMC Manual Customer", ["cnic", "conversion_status"], "idx_omc_manual_customer_cnic_status")
    _add_index("OMC Manual Customer", ["mobile", "conversion_status"], "idx_omc_manual_customer_mobile_status")
    _add_index("OMC Service Request", ["referral_owner", "status"], "idx_omc_service_referral_status")
