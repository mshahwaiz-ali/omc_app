import frappe


ALLOWED_ORIGINS = {
    "http://localhost:3000",
    "http://127.0.0.1:3000",
}


def _allowed_origins():
    configured = frappe.conf.get("omc_cors_allowed_origins")
    if isinstance(configured, str):
        configured = [configured]
    values = {str(value).strip() for value in (configured or ALLOWED_ORIGINS) if str(value).strip()}
    values.discard("*")
    return values


def add_cors_headers(response, request=None):
    origin = frappe.get_request_header("Origin")

    if origin in _allowed_origins():
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = (
            "Content-Type, Authorization, X-Frappe-CSRF-Token, X-Requested-With, X-Idempotency-Key"
        )
        response.headers["Vary"] = "Origin"

    return response
