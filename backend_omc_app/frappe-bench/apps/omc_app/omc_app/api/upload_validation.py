from __future__ import annotations

import io
import importlib
import re
import zipfile

import frappe


EXTENSION_MIME_TYPES = {
    "pdf": {"application/pdf"},
    "jpg": {"image/jpeg"},
    "jpeg": {"image/jpeg"},
    "png": {"image/png"},
    "webp": {"image/webp"},
    "doc": {"application/msword", "application/octet-stream"},
    "docx": {
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/zip",
        "application/octet-stream",
    },
}


def safe_filename(value, *, fallback="upload") -> str:
    raw = str(value or fallback).strip().rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    return re.sub(r"[^A-Za-z0-9._-]+", "-", raw).strip(".-_") or fallback


def validate_upload_bytes(
    *,
    filename,
    content: bytes,
    allowed_extensions: set[str],
    max_size_bytes: int,
    declared_mime: str | None = None,
) -> str:
    clean_name = safe_filename(filename)
    extension = clean_name.rsplit(".", 1)[-1].lower() if "." in clean_name else ""
    if extension not in allowed_extensions:
        frappe.throw("Unsupported file type.", frappe.ValidationError)
    if not content:
        frappe.throw("Uploaded file is empty.", frappe.ValidationError)
    if len(content) > max_size_bytes:
        frappe.throw("Uploaded file exceeds the allowed size.", frappe.ValidationError)
    mime = str(declared_mime or "").split(";", 1)[0].strip().lower()
    if mime and mime not in EXTENSION_MIME_TYPES.get(extension, set()):
        frappe.throw(
            "The selected file MIME type does not match its extension.",
            frappe.ValidationError,
        )
    if not _signature_matches(extension, content):
        frappe.throw(
            "The selected file content does not match its extension.",
            frappe.ValidationError,
        )
    _validate_format_bounds(extension, content)
    return clean_name


def _validate_format_bounds(extension: str, content: bytes) -> None:
    if extension in {"jpg", "jpeg", "png", "webp"}:
        try:
            from PIL import Image

            with Image.open(io.BytesIO(content)) as image:
                width, height = image.size
                if width <= 0 or height <= 0 or width > 12000 or height > 12000 or width * height > 40_000_000:
                    frappe.throw("Image dimensions exceed the allowed bounds.", frappe.ValidationError)
                image.verify()
        except frappe.ValidationError:
            raise
        except Exception:
            frappe.throw("The uploaded image is invalid.", frappe.ValidationError)
    elif extension == "pdf":
        if any(marker in content for marker in (b"/JavaScript", b"/JS ", b"/Launch", b"/EmbeddedFile")):
            frappe.throw("PDF contains unsupported active or embedded content.", frappe.ValidationError)
        page_count = content.count(b"/Type /Page") - content.count(b"/Type /Pages")
        if page_count > 100:
            frappe.throw("PDF exceeds the maximum page count.", frappe.ValidationError)
    elif extension == "docx":
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                infos = archive.infolist()
                if len(infos) > 1000:
                    frappe.throw("Document archive contains too many entries.", frappe.ValidationError)
                total = 0
                for info in infos:
                    normalized = info.filename.replace("\\", "/")
                    if normalized.startswith("/") or "../" in normalized:
                        frappe.throw("Document archive contains an unsafe path.", frappe.ValidationError)
                    total += max(info.file_size, 0)
                if total > 100 * 1024 * 1024:
                    frappe.throw("Document archive expands beyond the allowed size.", frappe.ValidationError)
        except frappe.ValidationError:
            raise
        except (OSError, zipfile.BadZipFile):
            frappe.throw("The uploaded document archive is invalid.", frappe.ValidationError)


def scan_upload(*, filename: str, content: bytes) -> str:
    """Return Clean, Manual Review, or Rejected from an optional site scanner."""
    dotted_path = str(frappe.conf.get("omc_upload_scanner") or "").strip()
    if not dotted_path:
        return "Manual Review"
    try:
        module_name, function_name = dotted_path.rsplit(".", 1)
        scanner = getattr(importlib.import_module(module_name), function_name)
        result = str(scanner(filename=filename, content=content) or "").strip()
    except Exception:
        frappe.log_error(frappe.get_traceback(), "OMC Upload Scanner Failed")
        return "Manual Review"
    if result not in {"Clean", "Manual Review", "Rejected"}:
        return "Manual Review"
    return result


def read_multipart_upload(
    *,
    allowed_extensions: set[str],
    max_size_bytes: int,
):
    request = getattr(frappe, "request", None)
    uploaded = request.files.get("file") if request and getattr(request, "files", None) else None
    if not uploaded:
        frappe.throw("Upload file is required.", frappe.ValidationError)
    content = uploaded.stream.read(max_size_bytes + 1)
    filename = validate_upload_bytes(
        filename=getattr(uploaded, "filename", "") or "upload",
        content=content,
        allowed_extensions=allowed_extensions,
        max_size_bytes=max_size_bytes,
        declared_mime=getattr(uploaded, "mimetype", None),
    )
    return filename, content


def validate_file_document(
    file_doc,
    *,
    allowed_extensions: set[str],
    max_size_bytes: int,
) -> str:
    content = file_doc.get_content()
    if isinstance(content, str):
        content = content.encode("utf-8")
    return validate_upload_bytes(
        filename=file_doc.file_name or file_doc.file_url,
        content=content or b"",
        allowed_extensions=allowed_extensions,
        max_size_bytes=max_size_bytes,
        declared_mime=getattr(file_doc, "content_type", None),
    )


def _signature_matches(extension: str, content: bytes) -> bool:
    if extension == "pdf":
        return content.startswith(b"%PDF-")
    if extension in {"jpg", "jpeg"}:
        return content.startswith(b"\xff\xd8\xff")
    if extension == "png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if extension == "webp":
        return (
            len(content) >= 12
            and content.startswith(b"RIFF")
            and content[8:12] == b"WEBP"
        )
    if extension == "doc":
        return content.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1")
    if extension == "docx":
        if not content.startswith(b"PK\x03\x04"):
            return False
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                names = archive.namelist()
                return "[Content_Types].xml" in names and any(name.startswith("word/") for name in names)
        except (OSError, zipfile.BadZipFile):
            return False
    return False
