import re, pytesseract, cv2
from PIL import Image
from pyzbar.pyzbar import decode as zbar_decode

import cv2, numpy as np, pytesseract, re
from PIL import Image
from pyzbar.pyzbar import decode as zbar_decode

REG_NO_RE = re.compile(r'(Registration\s*No[:\s-]*)(\d{10,20})', re.I)
TAX_YEAR_RE = re.compile(r'(Tax\s*Year[:\s-]*)(20\d{2}|19\d{2})', re.I)
JUST_DIGITS_RE = re.compile(r'\d+')



#######################################
ONLY_DIGITS_RE = re.compile(r'^\d{8,32}$')

def _decode_barcode_pyzbar(img_bgr):
    pil = Image.fromarray(cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB))
    for code in zbar_decode(pil):
        txt = (code.data or b'').decode('utf-8', errors='ignore').strip()
        if ONLY_DIGITS_RE.fullmatch(txt):
            return txt
    return None

def _decode_barcode_opencv(img_bgr):
    # Requires opencv-contrib-python. The API name varies by build; try both.
    try:
        BD = getattr(cv2, "barcode_BarcodeDetector", None) or getattr(cv2.barcode, "BarcodeDetector", None)
        if BD is None:
            return None, None
        bd = BD()
        try:
            ok, decoded_info, decoded_type, corners = bd.detectAndDecode(img_bgr)
        except TypeError:
            # Some builds return (decoded_info, decoded_type, corners)
            res = bd.detectAndDecode(img_bgr)
            if isinstance(res, tuple) and len(res) == 3:
                decoded_info, decoded_type, corners = res
                ok = True if decoded_info else False
            else:
                return None, None

        if ok and decoded_info:
            for s in decoded_info:
                if s and ONLY_DIGITS_RE.fullmatch(s.strip()):
                    return s.strip(), corners
        # Even if decode failed, corners may still exist
        return None, corners
    except Exception:
        return None, None

def _locate_bar_region(img_bgr):
    """Heuristic locator using vertical edges & morphology; returns largest 'bar-like' bbox."""
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    # emphasize vertical bars
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    ax = cv2.convertScaleAbs(gx)
    _, th = cv2.threshold(ax, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # close gaps to form a solid block over the bars
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (21, 7))
    morph = cv2.morphologyEx(th, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(morph, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    H, W = gray.shape[:2]
    best = None
    best_score = 0.0
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        area = w * h
        # barcode bars are typically wide & not too tall; near bottom third on your form
        aspect = w / float(h + 1e-6)
        vertical_pos = (y + h/2) / float(H)
        score = area * (1 + min(aspect/6.0, 1.0)) * (1 + (vertical_pos > 0.45))
        if aspect > 2.5 and w > 0.25 * W and area > best_score:
            best_score = area
            best = (x, y, w, h)
    return best  # (x,y,w,h) or None

def _ocr_digits(img_bgr, psm=7):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_CUBIC)
    _, th = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    cfg = f'--psm {psm} -c tessedit_char_whitelist=0123456789'
    txt = pytesseract.image_to_string(th, config=cfg).strip()
    # keep only long digit runs
    cands = re.findall(r'\d{8,32}', txt.replace(" ", ""))
    if not cands:
        return None
    # choose the longest; if tie pick the most centered text line
    return max(cands, key=len)

def extract_barcode(img_bgr):
    # 1) try pyzbar
    code = _decode_barcode_pyzbar(img_bgr)
    if code:
        print("ZBAR found barcode:", code)
        return code

    # 2) try OpenCV barcode detector (may also give corners/bbox)
    code, corners = _decode_barcode_opencv(img_bgr)
    if code:
        print("OpenCV found barcode:", code)
        return code

    # Build a bbox from corners if present
    bbox = None
    if corners is not None and len(corners):
        # corners: list of arrays of shape (N,1,2) or (4,2)
        pts = np.concatenate([np.squeeze(c, axis=1) if len(c.shape)==3 else c for c in corners], axis=0)
        x, y = np.min(pts, axis=0).astype(int)
        X, Y = np.max(pts, axis=0).astype(int)
        bbox = (x, y, X - x, Y - y)

    # 3) heuristic locate if no bbox yet
    if bbox is None:
        bbox = _locate_bar_region(img_bgr)

    # 4) ROI OCR: read the human-readable digits under the bars
    if bbox is not None:
        x, y, w, h = bbox
        H, W = img_bgr.shape[:2]
        # expand a bit and take a band **below** the bars
        y_digits = min(H-1, y + h)
        band_h = int(h * 0.85)  # digits typically ~ same height as bars, slightly less
        roi = img_bgr[max(0, y_digits):min(H, y_digits + band_h), max(0, x):min(W, x + w)]
        candidate = _ocr_digits(roi, psm=7)
        if candidate:
            return candidate

    # 5) last resort: look ONLY in bottom third to avoid contact number on top
    H = img_bgr.shape[0]
    roi = img_bgr[int(H*0.55):, :]
    candidate = _ocr_digits(roi, psm=6)
    return candidate
#######################################


def _read(img_path_or_bytes):
    if isinstance(img_path_or_bytes, (bytes, bytearray)):
        import numpy as np
        arr = np.frombuffer(img_path_or_bytes, np.uint8)
        return cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return cv2.imread(img_path_or_bytes, cv2.IMREAD_COLOR)

def _preprocess_for_ocr(img):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    g = cv2.bilateralFilter(g, 9, 75, 75)
    # adaptive threshold helps on scans / photos
    th = cv2.adaptiveThreshold(g, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                               cv2.THRESH_BINARY, 31, 8)
    return th

def extract_ack_fields(img_path_or_bytes):
    img = _read(img_path_or_bytes)
    if img is None:
        raise ValueError("Failed to read image")

    # 1) Try barcode via zbar
    barcode = None
    barcode = extract_barcode(img)

    # 2) OCR for text fields (and fallback for barcode)
    th = _preprocess_for_ocr(img)
    ocr_text = pytesseract.image_to_string(th, lang="eng")

    # Registration No
    reg_no = None
    m = REG_NO_RE.search(ocr_text)
    if m:
        reg_no = JUST_DIGITS_RE.search(m.group(2)).group(0)

    # Tax Year
    tax_year = None
    m = TAX_YEAR_RE.search(ocr_text)
    if m:
        tax_year = int(JUST_DIGITS_RE.search(m.group(2)).group(0))

    # If barcode not decoded, try reading the digits under the barcode from OCR text
    if barcode is None:
        # Heuristic: last big number sequence in text is often the barcode line
        candidates = JUST_DIGITS_RE.findall(ocr_text)
        if candidates:
            barcode = max(candidates, key=len)

    return {
        "registration_no": reg_no,
        "tax_year": tax_year,
        "barcode": barcode
    }

if __name__ == "__main__":
    # quick test
    print(extract_ack_fields("/home/frappe/frappe-bench/sites/erp.omchouse.com/public/files/tax_return.jpg"))
