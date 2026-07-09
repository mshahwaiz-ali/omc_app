import frappe

from omc_app.api.mobile import _current_user, _get_mobile_capabilities


CUSTOMER_FALLBACK_QUICK_ACTIONS = [
    {
        "title": "Start Service",
        "subtitle": "Request",
        "icon_key": "services",
        "target_type": "Feature",
        "target_value": "services",
        "sort_order": 10,
        "access_level": "Public",
        "required_capability": "",
        "badge_type": "None",
        "style": "Highlighted",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Services",
    },
    {
        "title": "Tax Calculator",
        "subtitle": "Estimate",
        "icon_key": "calculator",
        "target_type": "Feature",
        "target_value": "calculator",
        "sort_order": 20,
        "access_level": "Public",
        "required_capability": "can_use_tax_calculator",
        "badge_type": "None",
        "style": "Normal",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Tax",
    },
    {
        "title": "Documents",
        "subtitle": "Upload",
        "icon_key": "documents",
        "target_type": "Route",
        "target_value": "/documents",
        "sort_order": 30,
        "access_level": "Approved Customer",
        "required_capability": "can_view_documents",
        "badge_type": "Documents",
        "style": "Normal",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Work",
    },
    {
        "title": "Payments",
        "subtitle": "Dues",
        "icon_key": "payments",
        "target_type": "Route",
        "target_value": "/payments",
        "sort_order": 40,
        "access_level": "Approved Customer",
        "required_capability": "can_view_payments",
        "badge_type": "Payments",
        "style": "Normal",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Finance",
    },
    {
        "title": "Support",
        "subtitle": "Help",
        "icon_key": "support",
        "target_type": "Feature",
        "target_value": "support",
        "sort_order": 50,
        "access_level": "Logged In",
        "required_capability": "can_create_support_ticket",
        "badge_type": "Support",
        "style": "Normal",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Support",
    },
    {
        "title": "Expense Tracker",
        "subtitle": "Local",
        "icon_key": "track",
        "target_type": "Route",
        "target_value": "/expense-tracker",
        "sort_order": 60,
        "access_level": "Public",
        "required_capability": "",
        "badge_type": "None",
        "style": "Normal",
        "placement": "home_primary",
        "layout_size": "small",
        "group": "Finance",
    },
]

INTERNAL_FALLBACK_QUICK_ACTIONS = [
    {
        "title": "Service Cases",
        "subtitle": "Workspace",
        "icon_key": "dashboard",
        "target_type": "Route",
        "target_value": "/internal-workspace/service-cases",
        "sort_order": 10,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "None",
        "style": "Highlighted",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Work",
    },
    {
        "title": "Review Docs",
        "subtitle": "Queue",
        "icon_key": "documents",
        "target_type": "Route",
        "target_value": "/internal-workspace/documents",
        "sort_order": 20,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "Documents",
        "style": "Urgent",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Work",
    },
    {
        "title": "Review Payments",
        "subtitle": "Receipts",
        "icon_key": "payments",
        "target_type": "Route",
        "target_value": "/internal-workspace/payments",
        "sort_order": 30,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "Payments",
        "style": "Urgent",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Finance",
    },
    {
        "title": "Leads",
        "subtitle": "Pipeline",
        "icon_key": "services",
        "target_type": "Route",
        "target_value": "/leads",
        "sort_order": 40,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "None",
        "style": "Normal",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Sales",
    },
    {
        "title": "Tasks",
        "subtitle": "Pending",
        "icon_key": "track",
        "target_type": "Route",
        "target_value": "/tasks",
        "sort_order": 50,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "None",
        "style": "Normal",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Work",
    },
    {
        "title": "Customers",
        "subtitle": "Profiles",
        "icon_key": "message",
        "target_type": "Route",
        "target_value": "/customers",
        "sort_order": 60,
        "access_level": "Internal Staff",
        "required_capability": "can_access_internal_workspace",
        "badge_type": "None",
        "style": "Normal",
        "placement": "internal_home",
        "layout_size": "small",
        "group": "Customers",
    },
]

FALLBACK_QUICK_ACTIONS = CUSTOMER_FALLBACK_QUICK_ACTIONS


def _has_quick_action_doctype():
    try:
        return bool(frappe.db.exists("DocType", "OMC Mobile Quick Action"))
    except Exception:
        return False


def _meta_has_field(meta, fieldname):
    try:
        return bool(meta.has_field(fieldname))
    except Exception:
        return False


def _normalize_key(value):
    return (value or "").strip().lower().replace("_", "-").replace(" ", "-")


def _target_type(value):
    normalized = (value or "Route").strip().lower()
    if normalized == "external url":
        return "external_url"
    return normalized.replace(" ", "_")


def _badge_type(value):
    return (value or "None").strip().lower().replace(" ", "_")


def _style(value):
    return (value or "Normal").strip().lower()


def _allowed_for_access(row, capabilities, user):
    access_level = (row.get("access_level") or "Public").strip().lower()
    if access_level == "public":
        return True
    if access_level == "logged in":
        return bool(user and user != "Guest")
    if access_level == "approved customer":
        return bool(capabilities.get("is_approved_customer"))
    if access_level == "internal staff":
        return bool(capabilities.get("can_access_internal_workspace"))
    return True


def _allowed_for_capability(row, capabilities):
    required = (row.get("required_capability") or "").strip()
    if not required:
        return True
    return bool(capabilities.get(required))


def _service_target(row):
    service = (row.get("service") or "").strip()
    target = (row.get("target_value") or "").strip()
    return service or target


def _row_to_action(row):
    target_type = _target_type(row.get("target_type"))
    target_value = _service_target(row) if target_type == "service" else (row.get("target_value") or "")
    return {
        "id": row.get("name") or "",
        "title": row.get("title") or "",
        "subtitle": row.get("subtitle") or "",
        "icon_key": _normalize_key(row.get("icon_key")),
        "target_type": target_type,
        "target_value": target_value,
        "sort_order": int(row.get("sort_order") or 0),
        "access_level": row.get("access_level") or "Public",
        "required_capability": row.get("required_capability") or "",
        "badge_type": _badge_type(row.get("badge_type")),
        "style": _style(row.get("style")),
        "placement": _normalize_key(row.get("placement") or "home_primary"),
        "layout_size": _normalize_key(row.get("layout_size") or "small"),
        "is_featured": 1 if row.get("is_featured") else 0,
        "group": row.get("group") or "",
        "description_long": row.get("description_long") or "",
    }


def _fallback_actions(capabilities=None):
    source = INTERNAL_FALLBACK_QUICK_ACTIONS if (capabilities or {}).get("can_access_internal_workspace") else CUSTOMER_FALLBACK_QUICK_ACTIONS
    return [
        {
            "id": f"fallback-{index}",
            **action,
            "target_type": _target_type(action.get("target_type")),
            "icon_key": _normalize_key(action.get("icon_key")),
            "badge_type": _badge_type(action.get("badge_type")),
            "style": _style(action.get("style")),
            "placement": _normalize_key(action.get("placement")),
            "layout_size": _normalize_key(action.get("layout_size")),
        }
        for index, action in enumerate(source, start=1)
    ]


@frappe.whitelist(allow_guest=True)
def get_mobile_quick_actions():
    user = _current_user()
    capabilities = _get_mobile_capabilities(user=user)

    if not _has_quick_action_doctype():
        actions = _fallback_actions(capabilities)
    else:
        meta = frappe.get_meta("OMC Mobile Quick Action")
        fields = [
            "name",
            "title",
            "subtitle",
            "icon_key",
            "target_type",
            "target_value",
            "service",
            "sort_order",
            "access_level",
            "required_capability",
            "badge_type",
            "style",
        ]
        for optional in [
            "placement",
            "layout_size",
            "is_featured",
            "starts_on",
            "ends_on",
            "description_long",
            "group",
        ]:
            if _meta_has_field(meta, optional):
                fields.append(optional)

        rows = frappe.get_all(
            "OMC Mobile Quick Action",
            filters={"enabled": 1},
            fields=fields,
            order_by="sort_order asc, creation asc",
            limit_page_length=30,
            ignore_permissions=True,
        )
        actions = [
            _row_to_action(row)
            for row in rows
            if _allowed_for_access(row, capabilities, user)
            and _allowed_for_capability(row, capabilities)
        ]
        if not actions:
            actions = _fallback_actions(capabilities)

    return {"quick_actions": actions, "actions": actions}
