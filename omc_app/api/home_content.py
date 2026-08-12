import frappe
from frappe.utils import get_datetime, now_datetime

from omc_app.api.mobile import _customer_access_state, _current_user


HOME_AUDIENCE_ALL = "All"
HOME_AUDIENCE_GUEST = "Guest"
HOME_AUDIENCE_CUSTOMER = "Customer"
HOME_AUDIENCE_APPROVED = "Approved Customer"


def _doctype_exists(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _meta_fields(doctype):
    if not _doctype_exists(doctype):
        return set()
    try:
        return {field.fieldname for field in frappe.get_meta(doctype).fields}
    except Exception:
        return set()


def _available_fields(doctype, desired_fields):
    available = _meta_fields(doctype)
    return [field for field in desired_fields if field in available or field == "name"]


def _clean(value):
    return (value or "").strip() if isinstance(value, str) else value


def _int_value(value, default=0):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return default


def _datetime_value(value):
    if not value:
        return None
    try:
        return get_datetime(value)
    except (TypeError, ValueError):
        return None


def _is_started(value, current_time):
    starts_at = _datetime_value(value)
    return starts_at is None or starts_at <= current_time


def _is_not_expired(value, current_time):
    expires_at = _datetime_value(value)
    return expires_at is None or expires_at >= current_time


def _current_audience():
    state = _customer_access_state(user=_current_user())
    if state == "guest":
        return HOME_AUDIENCE_GUEST
    if state == "approved":
        return HOME_AUDIENCE_APPROVED
    if state in {"pending", "rejected"}:
        return HOME_AUDIENCE_CUSTOMER
    return HOME_AUDIENCE_ALL


def _audience_matches(value, current_audience):
    audience = (_clean(value) or HOME_AUDIENCE_ALL).lower()
    current = (current_audience or HOME_AUDIENCE_ALL).lower()

    if audience == HOME_AUDIENCE_ALL.lower():
        return True
    if audience == HOME_AUDIENCE_GUEST.lower():
        return current == HOME_AUDIENCE_GUEST.lower()
    if audience == HOME_AUDIENCE_APPROVED.lower():
        return current == HOME_AUDIENCE_APPROVED.lower()
    if audience == HOME_AUDIENCE_CUSTOMER.lower():
        return current in {
            HOME_AUDIENCE_CUSTOMER.lower(),
            HOME_AUDIENCE_APPROVED.lower(),
        }
    return False


def _published_rows(doctype, fields, order_by="sort_order asc, creation desc", limit=30):
    if not _doctype_exists(doctype):
        return []

    available = _available_fields(doctype, fields)
    if "status" not in available:
        return []

    try:
        return frappe.get_all(
            doctype,
            filters={"status": "Published"},
            fields=available,
            order_by=order_by,
            limit_page_length=limit,
            ignore_permissions=True,
        )
    except Exception:
        return []


def _banner_items(current_time, audience):
    rows = _published_rows(
        "OMC App Banner",
        [
            "name",
            "banner_id",
            "title",
            "subtitle",
            "badge",
            "image",
            "content_type",
            "action_type",
            "action_target",
            "action_label",
            "mobile_route",
            "audience",
            "priority",
            "starts_on",
            "ends_on",
            "sort_order",
            "status",
        ],
        order_by="priority desc, sort_order asc, creation desc",
        limit=12,
    )

    items = []
    for row in rows:
        if not _is_started(row.get("starts_on"), current_time):
            continue
        if not _is_not_expired(row.get("ends_on"), current_time):
            continue
        if not _audience_matches(row.get("audience"), audience):
            continue

        target = _clean(row.get("action_target")) or _clean(row.get("mobile_route")) or ""
        action_type = _clean(row.get("action_type")) or ("Route" if target else "None")
        items.append(
            {
                "id": _clean(row.get("banner_id")) or row.get("name") or "",
                "title": _clean(row.get("title")) or "",
                "subtitle": _clean(row.get("subtitle")) or "",
                "badge": _clean(row.get("badge")) or "",
                "image": _clean(row.get("image")) or "",
                "content_type": _clean(row.get("content_type")) or "Featured",
                "action": {
                    "type": action_type,
                    "target": target,
                    "label": _clean(row.get("action_label")) or "",
                },
                "priority": _int_value(row.get("priority")),
                "sort_order": _int_value(row.get("sort_order")),
            }
        )

    return items


def _knowledge_items(current_time, audience):
    rows = _published_rows(
        "OMC Knowledge Article",
        [
            "name",
            "article_id",
            "title",
            "category",
            "summary",
            "cover_image",
            "content_type",
            "home_section",
            "audience",
            "is_featured",
            "priority",
            "sort_order",
            "read_time_minutes",
            "published_on",
            "expires_on",
            "status",
        ],
        order_by="priority desc, sort_order asc, published_on desc, creation desc",
        limit=24,
    )

    items = []
    for row in rows:
        home_section = (_clean(row.get("home_section")) or "Learn & Grow").lower()
        if home_section not in {"learn & grow", "learn and grow"}:
            continue
        if not _is_started(row.get("published_on"), current_time):
            continue
        if not _is_not_expired(row.get("expires_on"), current_time):
            continue
        if not _audience_matches(row.get("audience"), audience):
            continue

        items.append(
            {
                "id": _clean(row.get("article_id")) or row.get("name") or "",
                "title": _clean(row.get("title")) or "",
                "summary": _clean(row.get("summary")) or "",
                "category": _clean(row.get("category")) or "Guide",
                "content_type": _clean(row.get("content_type")) or "Guide",
                "image": _clean(row.get("cover_image")) or "",
                "is_featured": bool(row.get("is_featured")),
                "priority": _int_value(row.get("priority")),
                "sort_order": _int_value(row.get("sort_order")),
                "read_time_minutes": _int_value(row.get("read_time_minutes")),
                "published_on": str(row.get("published_on") or ""),
                "detail_type": "knowledge",
            }
        )

    return items


def _tax_update_items(current_time, audience):
    rows = _published_rows(
        "OMC Tax Alert",
        [
            "name",
            "alert_id",
            "title",
            "category",
            "summary",
            "cover_image",
            "urgency",
            "audience",
            "is_featured",
            "priority",
            "sort_order",
            "read_time_minutes",
            "effective_date",
            "published_on",
            "expires_on",
            "status",
        ],
        order_by="priority desc, sort_order asc, published_on desc, creation desc",
        limit=20,
    )

    items = []
    for row in rows:
        if not _is_started(row.get("published_on"), current_time):
            continue
        if not _is_not_expired(row.get("expires_on"), current_time):
            continue
        if not _audience_matches(row.get("audience"), audience):
            continue

        items.append(
            {
                "id": _clean(row.get("alert_id")) or row.get("name") or "",
                "title": _clean(row.get("title")) or "",
                "summary": _clean(row.get("summary")) or "",
                "category": _clean(row.get("category")) or "Tax Alert",
                "content_type": "Tax Update",
                "image": _clean(row.get("cover_image")) or "",
                "urgency": _clean(row.get("urgency")) or "Normal",
                "is_featured": bool(row.get("is_featured")),
                "priority": _int_value(row.get("priority")),
                "sort_order": _int_value(row.get("sort_order")),
                "read_time_minutes": _int_value(row.get("read_time_minutes")),
                "effective_date": str(row.get("effective_date") or ""),
                "published_on": str(row.get("published_on") or ""),
                "detail_type": "knowledge",
            }
        )

    return items


def _announcement_items(current_time, audience):
    rows = _published_rows(
        "OMC Announcement",
        [
            "name",
            "announcement_id",
            "title",
            "message",
            "priority",
            "audience",
            "home_section",
            "mobile_route",
            "starts_on",
            "ends_on",
            "is_featured",
            "sort_order",
            "status",
        ],
        order_by="sort_order asc, creation desc",
        limit=16,
    )

    items = []
    for row in rows:
        home_section = (_clean(row.get("home_section")) or "Tax & Business Updates").lower()
        if home_section not in {"tax & business updates", "tax and business updates"}:
            continue
        if not _is_started(row.get("starts_on"), current_time):
            continue
        if not _is_not_expired(row.get("ends_on"), current_time):
            continue
        if not _audience_matches(row.get("audience"), audience):
            continue

        priority_label = _clean(row.get("priority")) or "Normal"
        items.append(
            {
                "id": _clean(row.get("announcement_id")) or row.get("name") or "",
                "title": _clean(row.get("title")) or "",
                "summary": _clean(row.get("message")) or "",
                "category": "OMC Update",
                "content_type": "Announcement",
                "image": "",
                "urgency": priority_label,
                "is_featured": bool(row.get("is_featured")),
                "priority": {"high": 30, "normal": 20, "low": 10}.get(priority_label.lower(), 20),
                "sort_order": _int_value(row.get("sort_order")),
                "read_time_minutes": 0,
                "published_on": str(row.get("starts_on") or ""),
                "detail_type": "knowledge",
                "mobile_route": _clean(row.get("mobile_route")) or "",
            }
        )

    return items


def _content_sort_key(item):
    return (-_int_value(item.get("priority")), _int_value(item.get("sort_order")))


@frappe.whitelist(allow_guest=True)
def get_home_content():
    """Return lightweight, curated content for the customer/guest home screen.

    Full article bodies are intentionally excluded. Detail content continues to be
    served by the existing knowledge detail endpoint.
    """

    current_time = now_datetime()
    audience = _current_audience()

    updates = _tax_update_items(current_time, audience) + _announcement_items(
        current_time, audience
    )
    updates.sort(key=_content_sort_key)

    learn_grow = _knowledge_items(current_time, audience)
    learn_grow.sort(key=_content_sort_key)

    return {
        "audience": audience,
        "featured_banners": _banner_items(current_time, audience),
        "tax_business_updates": updates[:12],
        "learn_grow": learn_grow[:12],
    }
