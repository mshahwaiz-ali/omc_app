from __future__ import annotations

import io
import re
import zipfile

import frappe


def safe_filename(value, *, fallback="upload") -> str:
    raw = str(value or fallback).strip().rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    return re.sub(r"[^A-Za-z0-9._-]+", "-", raw).strip(".-_") or fallback


def validate_upload_bytes(
    *,
    filename,
    content: bytes,
    allowed_extensions: set[str],
    max_size_bytes: int,
) -> str:
    clean_name = safe_filename(filename)
    extension = clean_name.rsplit(".", 1)[-1].lower() if "." in clean_name else ""
    if extension not in allowed_extensions:
        frappe.throw("Unsupported file type.", frappe.ValidationError)
    if not content:
        frappe.throw("Uploaded file is empty.", frappe.ValidationError)
    if len(content) > max_size_bytes:
        frappe.throw("Uploaded file exceeds the allowed size.", frappe.ValidationError)
    if not _signature_matches(extension, content):
        frappe.throw(
            "The selected file content does not match its extension.",
            frappe.ValidationError,
        )
    return clean_name


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
    )


def _signature_matches(extension: str, content: bytes) -> bool:
    if extension == "pdf":
        return content.startswith(b"%PDF-")
    if extension in {"jpg", "jpeg"}:
        return content.startswith(b"\xff\xd8\xff")
    if extension == "png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if extension == "doc":
        return content.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1")
    if extension == "docx":
        if not content.startswith(b"PK\x03\x04"):
            return False
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                return "[Content_Types].xml" in archive.namelist() and any(
                    name.startswith("word/") for name in archive.namelist()
                )
        except (OSError, zipfile.BadZipFile):
            return False
    return False
