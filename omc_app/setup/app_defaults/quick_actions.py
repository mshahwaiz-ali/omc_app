from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class QuickActionSpec:
    key: str
    title: str
    subtitle: str
    icon_key: str
    target_type: str
    target_value: str
    sort_order: int
    access_level: str
    required_capability: str = ""
    badge_type: str = "None"
    style: str = "Normal"
    placement: str = "home_primary"
    layout_size: str = "small"
    is_featured: int = 0
    group: str = ""
    description_long: str = ""


QUICK_ACTIONS = (
    QuickActionSpec(key="customer-start-service", title="Start Service", subtitle="Request", icon_key="services", target_type="Feature", target_value="services", sort_order=10, access_level="Public", style="Highlighted", group="Services", description_long="Browse OMC services and start with the service that matches your need."),
    QuickActionSpec(key="customer-tax-calculator", title="Tax Calculator", subtitle="Estimate", icon_key="calculator", target_type="Feature", target_value="calculator", sort_order=20, access_level="Public", required_capability="can_use_tax_calculator", group="Tax", description_long="Open the OMC tax estimate tool when calculator access is available."),
    QuickActionSpec(key="customer-documents", title="Documents", subtitle="Upload", icon_key="documents", target_type="Route", target_value="/documents", sort_order=30, access_level="Approved Customer", required_capability="can_view_documents", badge_type="Documents", group="Work", description_long="Review and manage documents linked to your service requests."),
    QuickActionSpec(key="customer-payments", title="Payments", subtitle="Dues", icon_key="payments", target_type="Route", target_value="/payments", sort_order=40, access_level="Approved Customer", required_capability="can_view_payments", badge_type="Payments", group="Finance", description_long="Review payment records and payment steps for your requests."),
    QuickActionSpec(key="customer-support", title="Support", subtitle="Help", icon_key="support", target_type="Feature", target_value="support", sort_order=50, access_level="Logged In", required_capability="can_create_support_ticket", badge_type="Support", group="Support", description_long="Contact OMC support about an account or service request issue."),
    QuickActionSpec(key="customer-expense-tracker", title="Expense Tracker", subtitle="Records", icon_key="track", target_type="Route", target_value="/expense-tracker", sort_order=60, access_level="Public", group="Finance", description_long="Organise income and expense records using the app's tracking tools."),
    QuickActionSpec(key="customer-budgets", title="Budgets", subtitle="Monthly", icon_key="payments", target_type="Route", target_value="/expense-budget", sort_order=70, access_level="Approved Customer", required_capability="can_view_customer_dashboard", group="Finance", description_long="Plan and review monthly budget targets alongside your expense records."),
    QuickActionSpec(key="internal-service-cases", title="Service Cases", subtitle="Workspace", icon_key="dashboard", target_type="Route", target_value="/internal-workspace/service-cases", sort_order=10, access_level="Internal Staff", required_capability="can_access_internal_workspace", style="Highlighted", placement="internal_home", group="Work", description_long="Open the internal service case workspace."),
    QuickActionSpec(key="internal-review-documents", title="Review Docs", subtitle="Queue", icon_key="documents", target_type="Route", target_value="/internal-workspace/documents", sort_order=20, access_level="Internal Staff", required_capability="can_access_internal_workspace", badge_type="Documents", style="Urgent", placement="internal_home", group="Work", description_long="Open the internal document review queue."),
    QuickActionSpec(key="internal-review-payments", title="Review Payments", subtitle="Receipts", icon_key="payments", target_type="Route", target_value="/internal-workspace/payments", sort_order=30, access_level="Internal Staff", required_capability="can_access_internal_workspace", badge_type="Payments", style="Urgent", placement="internal_home", group="Finance", description_long="Open the internal payment receipt review queue."),
    QuickActionSpec(key="internal-leads", title="Leads", subtitle="Pipeline", icon_key="services", target_type="Route", target_value="/leads", sort_order=40, access_level="Internal Staff", required_capability="can_access_internal_workspace", placement="internal_home", group="Sales", description_long="Open the staff lead pipeline."),
    QuickActionSpec(key="internal-tasks", title="Tasks", subtitle="Pending", icon_key="track", target_type="Route", target_value="/tasks", sort_order=50, access_level="Internal Staff", required_capability="can_access_internal_workspace", placement="internal_home", group="Work", description_long="Open the staff task list."),
    QuickActionSpec(key="internal-customers", title="Customers", subtitle="Profiles", icon_key="message", target_type="Route", target_value="/customers", sort_order=60, access_level="Internal Staff", required_capability="can_access_internal_workspace", placement="internal_home", group="Customers", description_long="Open customer profiles available to internal staff."),
)

ALLOWED_ICONS = {"tax-return", "ntn", "gst", "documents", "track", "calculator", "support", "payments", "message", "knowledge", "services", "notifications", "dashboard"}
ALLOWED_TARGET_TYPES = {"Route", "Feature", "Service", "External URL"}
ALLOWED_ACCESS_LEVELS = {"Public", "Logged In", "Approved Customer", "Internal Staff"}
ALLOWED_BADGES = {"None", "Documents", "Payments", "Support", "Notifications"}
ALLOWED_STYLES = {"Normal", "Highlighted", "Urgent"}
ALLOWED_PLACEMENTS = {"home_primary", "home_secondary", "more", "internal_home"}
ALLOWED_LAYOUTS = {"small", "wide", "hero"}


def validate_quick_action_manifest() -> dict[str, object]:
    keys = [action.key for action in QUICK_ACTIONS]
    if len(keys) != len(set(keys)):
        raise ValueError("Quick action keys must be unique.")
    customer = [a for a in QUICK_ACTIONS if a.access_level != "Internal Staff"]
    internal = [a for a in QUICK_ACTIONS if a.access_level == "Internal Staff"]
    if len(customer) != 7 or len(internal) != 6:
        raise ValueError("Quick action manifest must contain 7 customer and 6 internal actions.")
    for action in QUICK_ACTIONS:
        if not action.key or not action.title.strip() or not action.target_value.strip():
            raise ValueError("Quick action identity, title and target are required.")
        if action.icon_key not in ALLOWED_ICONS:
            raise ValueError(f"Unsupported quick action icon: {action.icon_key}")
        if action.target_type not in ALLOWED_TARGET_TYPES:
            raise ValueError(f"Unsupported target type: {action.target_type}")
        if action.access_level not in ALLOWED_ACCESS_LEVELS:
            raise ValueError(f"Unsupported access level: {action.access_level}")
        if action.badge_type not in ALLOWED_BADGES:
            raise ValueError(f"Unsupported badge type: {action.badge_type}")
        if action.style not in ALLOWED_STYLES:
            raise ValueError(f"Unsupported quick action style: {action.style}")
        if action.placement not in ALLOWED_PLACEMENTS:
            raise ValueError(f"Unsupported placement: {action.placement}")
        if action.layout_size not in ALLOWED_LAYOUTS:
            raise ValueError(f"Unsupported layout size: {action.layout_size}")
    return {"actions": len(QUICK_ACTIONS), "customer_actions": len(customer), "internal_actions": len(internal), "valid": True}
