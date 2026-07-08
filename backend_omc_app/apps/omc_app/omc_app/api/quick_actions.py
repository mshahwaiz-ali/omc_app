import frappe

from omc_app.api.mobile import _current_user, _get_mobile_capabilities


FALLBACK_QUICK_ACTIONS = [
    {
        "title": "Tax Return",
        "subtitle": "File now",
        "icon_key": "tax-return",
        "target_type": "Feature",
        "target_value": "services",
        "sort_order": 10,
        "required_capability": "",
        "badge_type": "None",
        "style": "Normal",
    },
    {
        "title": "NTN",
        "subtitle": "Registration",
        "icon_key": "ntn",
        "target_type": "Feature",
        "target_value": "services",
        "sort_order": 20,
        "required_capability": "",
        "badge_type": "None",
        "style": "Normal",
    },
    {
        "title": "GST",
        "subtitle": "Registration",
        "icon_key": "gst",
        "target_type": "Feature",
        "target_value": "services",
        "sort_order": 30,
        "required_capability": "",
        "badge_type": "None",
        "style": "Normal",
    },
    {
        "title": "Documents",
        "subtitle": "Upload",
        "icon_key": "documents",
        "target_type": "Route",
        "target_value": "/documents",
        "sort_order": 40,
        "required_capability": "can_view_documents",
        "badge_type": "Documents",
        "style": "Normal",
    },
    {
        "title": "Track",
        "subtitle": "Request",
        "icon_key": "track",
        "target_type": "Route",
        "target_value": "/my-services",
        "sort_order": 50,
        "required_capability": "can_track_requests",
        "badge_type": "None",
        "style": "Normal",
    },
    {
        "title": "Calculator",
        "subtitle": "Tax",
        "icon_key": "calculator",
        "target_type": "Feature",
        "target_value": "calculator",
        "sort_order": 60,
        "required_capability": "can_use_tax_calculator",
        "badge_type": "None",
        "style": "Normal",
    },
]


def _has_quick_action_doctype():
    try:
        return bool(frappe.db.exists("DocType", "OMC Mobile Quick Action"))
    except Exception:
        return False


def _normalize_key(value):
    return (value or "").strip().lower().replace("_", "-")


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
        "required_capability": row.get("required_capability") or "",
        "badge_type": _badge_type(row.get("badge_type")),
        "style": _style(row.get("style")),
    }


def _fallback_actions():
    return [
        {
            "id": f"fallback-{index}",
            "access_level": "Public",
            **action,
            "target_type": _target_type(action.get("target_type")),
            "icon_key": _normalize_key(action.get("icon_key")),
            "badge_type": _badge_type(action.get("badge_type")),
            "style": _style(action.get("style")),
        }
        for index, action in enumerate(FALLBACK_QUICK_ACTIONS, start=1)
    ]


@frappe.whitelist(allow_guest=True)
def get_mobile_quick_actions():
    user = _current_user()
    capabilities = _get_mobile_capabilities(user=user)

    if not _has_quick_action_doctype():
        actions = _fallback_actions()
    else:
        rows = frappe.get_all(
            "OMC Mobile Quick Action",
            filters={"enabled": 1},
            fields=[
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
            ],
            order_by="sort_order asc, creation asc",
            limit_page_length=20,
            ignore_permissions=True,
        )
        actions = [
            _row_to_action(row)
            for row in rows
            if _allowed_for_access(row, capabilities, user)
            and _allowed_for_capability(row, capabilities)
        ]
        if not actions:
            actions = _fallback_actions()

    return {"quick_actions": actions, "actions": actions}
