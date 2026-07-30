import frappe, json, base64, mimetypes, os

api_key = os.environ.get("OPENAI_API_KEY")
from openai import OpenAI

def _read_file_as_base64(file_url: str):
    from frappe.utils.file_manager import get_file
    fname, content = get_file(file_url)
    b64 = base64.b64encode(content).decode("utf-8")
    mime, _ = mimetypes.guess_type(fname or file_url)
    return b64, (mime or "image/jpeg")

def _call_openai_for_ack_slip(b64_data: str, mime_type: str):
    if not api_key:
        frappe.throw("OPENAI_API_KEY is not configured on the server.")
   
    import json

    client = OpenAI(api_key=api_key)

    prompt = (
        "You are parsing an FBR Acknowledgement Slip.\n"
        "Extract exactly these fields:\n"
        "1) registration_no → the alpha numeric string that appears next to 'Registration No'.\n"
        "2) tax_year → 4-digit tax year.\n"
        "3) barcode → the digits printed below the barcode.\n"
        "4) period → the line showing the filing period, formatted as DD-MMM-YYYY - DD-MMM-YYYY.\n"
        "5) document_date → the date printed at the bottom right, formatted as DD-MMM-YYYY.\n\n"
        "Rules for registration_no:\n"
        "- Read ONLY the token aligned with the 'Registration No' label on the same line. Starts after : character \n"
        "- DO NOT reorder or transpose adjacent characters; if any character is unclear, return null (no guessing).\n"
        "- Do not mix adjacent like 266233 with 262633.\n"
        "- Return ONLY valid JSON that matches the schema (no prose).\n"
         "- DO NOT auto-substitute lookalikes (O↔0, I↔1, S↔5, B↔8, Z↔2).\n"
        "- For barcode, return only the alphanumeric string below the barcode, no spaces or dashes.\n"
    )

    response_format = {
        "type": "json_schema",
        "json_schema": {
            "name": "fbr_ack_schema",
            "strict": True,
            "schema": {
                "type": "object",
                "properties": {
                    # Allow shorter reg numbers (e.g., 7+ alphanumeric like 4693266A).
                    "registration_no": {"type": "string", "pattern": r"^[A-Za-z0-9]{6,20}$"},
                    "tax_year": {"type": "integer", "minimum": 1900, "maximum": 2100},
                    "barcode": {"type": "string", "pattern": r"^[A-Za-z0-9]{8,32}$"},
                    # e.g., 01-Jul-2024 - 30-Jun-2025
                    "period": {
                        "type": "string",
                        "pattern": r"^\d{2}-[A-Za-z]{3}-\d{4}\s*-\s*\d{2}-[A-Za-z]{3}-\d{4}$"
                    },
                    # e.g., 11-Oct-2025
                    "document_date": {
                        "type": "string",
                        "pattern": r"^\d{2}-[A-Za-z]{3}-\d{4}$"
                    }
                },
                "required": [
                    "registration_no",
                    "tax_year",
                    "barcode",
                    "period",
                    "document_date"
                ],
                "additionalProperties": False
            }
        }
    }


    data_url = f"data:{mime_type};base64,{b64_data}"

    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        temperature=0,
        response_format=response_format,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": data_url}}
            ],
        }],
        max_tokens=200
    )

    # Prefer parsed output if the SDK exposes it
    msg = resp.choices[0].message
    parsed = getattr(msg, "parsed", None)
    if parsed is not None:
        return parsed

    # Fallback: extract JSON text and load
    content = getattr(msg, "content", None)
    if isinstance(content, list) and content and hasattr(content[0], "text"):
        return json.loads(content[0].text)
    if isinstance(content, str):
        return json.loads(content)

    raise ValueError("Chat Completions did not return parsable JSON.")



@frappe.whitelist()
def parse_ack_slip(doctype: str, name: str, image_field: str = "ack_image"):
    """
    Call with: frappe.call('parse_ack_slip', {doctype: 'Your DocType', name: doc.name})
    Expects an Attach Image field (default: ack_image).
    Also add optional fields to store results:
      ack_registration_no (Data), ack_tax_year (Int), ack_barcode (Data), ack_json (Code - JSON)
    """
    doc = frappe.get_doc(doctype, name)
    img = getattr(doc, image_field, None)
    if not img:
        frappe.throw(f"Please attach an image in '{image_field}' first.")

    b64, mime = _read_file_as_base64(img)
    result = _call_openai_for_ack_slip(b64, mime)

    # Write back to fields if present
    if hasattr(doc, "ack_registration_no"):
        doc.ack_registration_no = result.get("registration_no")
    if hasattr(doc, "ack_tax_year"):
        doc.ack_tax_year = int(result.get("tax_year")) if result.get("tax_year") else None
    if hasattr(doc, "ack_barcode"):
        doc.ack_barcode = result.get("barcode")
    if hasattr(doc, "ack_json"):
        doc.ack_json = json.dumps(result, ensure_ascii=False, indent=2)

    doc.save(ignore_permissions=True)
    frappe.db.commit()
    return result

# # Auto-run after save (if you want it automatic)
# doc = locals().get("doc")
# if doc and getattr(doc, "ack_image", None):
#     try:
#         b64, mime = _read_file_as_base64(doc.ack_image)
#         result = _call_openai_for_ack_slip(b64, mime)
#         if hasattr(doc, "ack_registration_no"):
#             doc.ack_registration_no = result.get("registration_no")
#         if hasattr(doc, "ack_tax_year"):
#             doc.ack_tax_year = int(result.get("tax_year")) if result.get("tax_year") else None
#         if hasattr(doc, "ack_barcode"):
#             doc.ack_barcode = result.get("barcode")
#         if hasattr(doc, "ack_json"):
#             doc.ack_json = json.dumps(result, ensure_ascii=False, indent=2)
#     except Exception:
#         frappe.log_error(title="ACK Slip Parse Failed", message=frappe.get_traceback())
