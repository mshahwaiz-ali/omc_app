from __future__ import annotations

import frappe
from frappe.utils import get_datetime, now_datetime

from omc_app.api import capabilities


def _text(value) -> str:
    return str(value or "").strip()


def _integer(value) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _audience() -> str:
    state = capabilities.effective().get("access_state")
    if state == "guest":
        return "Guest"
    if state == "approved":
        return "Approved Customer"
    if state in {"pending", "blocked"}:
        return "Customer"
    return "All"


def _audience_matches(value, current) -> bool:
    value = _text(value) or "All"
    return value == "All" or value == current or (value == "Customer" and current == "Approved Customer")


def _within_window(row, start_field, end_field, current) -> bool:
    start = row.get(start_field)
    end = row.get(end_field)
    try:
        return (not start or get_datetime(start) <= current) and (not end or get_datetime(end) >= current)
    except (TypeError, ValueError):
        return False


def _rows(doctype, desired, *, order_by, limit):
    if not frappe.db.exists("DocType", doctype):
        return []
    available = {field.fieldname for field in frappe.get_meta(doctype).fields}
    fields = [field for field in desired if field == "name" or field in available]
    if "status" not in fields:
        return []
    return frappe.get_all(
        doctype, filters={"status": "Published"}, fields=fields,
        order_by=order_by, limit_page_length=limit,
    )


def _banners(current, audience):
    rows = _rows(
        "OMC App Banner",
        ["name", "banner_id", "title", "subtitle", "badge", "image", "content_type", "action_type", "action_target", "action_label", "mobile_route", "audience", "priority", "starts_on", "ends_on", "sort_order", "status"],
        order_by="priority desc, sort_order asc, creation desc", limit=12,
    )
    items = []
    for row in rows:
        if not _within_window(row, "starts_on", "ends_on", current) or not _audience_matches(row.get("audience"), audience):
            continue
        target = _text(row.get("action_target")) or _text(row.get("mobile_route"))
        items.append({
            "id": _text(row.get("banner_id")) or row.name, "title": _text(row.get("title")),
            "subtitle": _text(row.get("subtitle")), "badge": _text(row.get("badge")),
            "image": _text(row.get("image")), "content_type": _text(row.get("content_type")) or "Featured",
            "action": {"type": _text(row.get("action_type")) or ("Route" if target else "None"), "target": target, "label": _text(row.get("action_label"))},
            "priority": _integer(row.get("priority")), "sort_order": _integer(row.get("sort_order")),
        })
    return items


def _articles(current, audience):
    rows = _rows(
        "OMC Knowledge Article",
        ["name", "article_id", "title", "category", "summary", "cover_image", "content_type", "home_section", "audience", "is_featured", "priority", "sort_order", "read_time_minutes", "published_on", "expires_on", "status"],
        order_by="priority desc, sort_order asc, published_on desc, creation desc", limit=24,
    )
    items = []
    for row in rows:
        section = (_text(row.get("home_section")) or "Learn & Grow").lower()
        if section not in {"learn & grow", "learn and grow"}:
            continue
        if not _within_window(row, "published_on", "expires_on", current) or not _audience_matches(row.get("audience"), audience):
            continue
        items.append({
            "id": _text(row.get("article_id")) or row.name, "title": _text(row.get("title")),
            "summary": _text(row.get("summary")), "category": _text(row.get("category")) or "Guide",
            "content_type": _text(row.get("content_type")) or "Guide", "image": _text(row.get("cover_image")),
            "is_featured": bool(row.get("is_featured")), "priority": _integer(row.get("priority")),
            "sort_order": _integer(row.get("sort_order")), "read_time_minutes": _integer(row.get("read_time_minutes")),
            "published_on": str(row.get("published_on") or ""), "detail_type": "knowledge",
        })
    return items


def _updates(current, audience):
    rows = _rows(
        "OMC Tax Alert",
        ["name", "alert_id", "title", "category", "summary", "cover_image", "urgency", "audience", "is_featured", "priority", "sort_order", "read_time_minutes", "effective_date", "published_on", "expires_on", "status"],
        order_by="priority desc, sort_order asc, published_on desc, creation desc", limit=20,
    )
    items = []
    for row in rows:
        if not _within_window(row, "published_on", "expires_on", current) or not _audience_matches(row.get("audience"), audience):
            continue
        items.append({
            "id": _text(row.get("alert_id")) or row.name, "title": _text(row.get("title")),
            "summary": _text(row.get("summary")), "category": _text(row.get("category")) or "Tax Alert",
            "content_type": "Tax Update", "image": _text(row.get("cover_image")),
            "urgency": _text(row.get("urgency")) or "Normal", "is_featured": bool(row.get("is_featured")),
            "priority": _integer(row.get("priority")), "sort_order": _integer(row.get("sort_order")),
            "read_time_minutes": _integer(row.get("read_time_minutes")), "effective_date": str(row.get("effective_date") or ""),
            "published_on": str(row.get("published_on") or ""), "detail_type": "knowledge",
        })
    announcements = _rows(
        "OMC Announcement",
        ["name", "announcement_id", "title", "message", "priority", "audience", "home_section", "mobile_route", "starts_on", "ends_on", "is_featured", "sort_order", "status"],
        order_by="sort_order asc, creation desc", limit=16,
    )
    for row in announcements:
        if not _within_window(row, "starts_on", "ends_on", current) or not _audience_matches(row.get("audience"), audience):
            continue
        label = _text(row.get("priority")) or "Normal"
        items.append({
            "id": _text(row.get("announcement_id")) or row.name, "title": _text(row.get("title")),
            "summary": _text(row.get("message")), "category": "OMC Update", "content_type": "Announcement",
            "image": "", "urgency": label, "is_featured": bool(row.get("is_featured")),
            "priority": {"high": 30, "normal": 20, "low": 10}.get(label.lower(), 20),
            "sort_order": _integer(row.get("sort_order")), "read_time_minutes": 0,
            "published_on": str(row.get("starts_on") or ""), "detail_type": "knowledge",
            "mobile_route": _text(row.get("mobile_route")),
        })
    return sorted(items, key=lambda item: (-item["priority"], item["sort_order"]))


@frappe.whitelist(allow_guest=True)
def get_home_content():
    current = now_datetime()
    audience = _audience()
    articles = sorted(_articles(current, audience), key=lambda item: (-item["priority"], item["sort_order"]))
    return {
        "audience": audience, "featured_banners": _banners(current, audience),
        "tax_business_updates": _updates(current, audience)[:12], "learn_grow": articles[:12],
    }
