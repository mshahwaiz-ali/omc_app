import frappe


ALLOWED_ORIGINS = {
    "http://localhost:3000",
    "http://127.0.0.1:3000",
}


def add_cors_headers(response):
    origin = frappe.get_request_header("Origin")

    if origin in ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = (
            "Content-Type, Authorization, X-Frappe-CSRF-Token, X-Requested-With"
        )
        response.headers["Vary"] = "Origin"

    return response
