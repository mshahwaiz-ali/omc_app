"""Retired mobile ERP Task write surface.

ERP Tasks linked to OMC Service Requests are readable through
``task_read_guard``. Task status, assignment, priority, dates, and planning are
edited only in ERP Desk. Operational task creation and initial assignment remain
in ``erp_service_task_adapter`` and are not mobile endpoints.
"""
