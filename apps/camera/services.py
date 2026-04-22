from __future__ import annotations

from contextlib import suppress
import os
import re
import tempfile
from decimal import Decimal

from rest_framework.exceptions import ValidationError

from apps.common.utils import normalize_plate

PLATE_PATTERN = re.compile(r"[A-Z0-9]{4,15}")


def extract_plate_candidates(raw_text: str) -> list[str]:
    if not raw_text:
        return []
    candidates = []
    for token in PLATE_PATTERN.findall(raw_text.upper()):
        normalized = normalize_plate(token)
        if len(normalized) >= 4:
            candidates.append(normalized)
    deduped = []
    for candidate in candidates:
        if candidate not in deduped:
            deduped.append(candidate)
    return deduped


def _materialize_image(image_source) -> tuple[str, str | None]:
    if isinstance(image_source, str):
        return image_source, None

    if hasattr(image_source, "path"):
        with suppress(Exception):
            return image_source.path, None

    if hasattr(image_source, "read"):
        data = image_source.read()
        with suppress(Exception):
            image_source.seek(0)
    elif isinstance(image_source, (bytes, bytearray)):
        data = bytes(image_source)
    else:
        raise ValidationError({"image": "Unsupported image source."})

    handle = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
    handle.write(data)
    handle.flush()
    handle.close()
    return handle.name, handle.name


def run_anpr(image_source) -> dict:
    temp_path = None
    try:
        import cv2
        import pytesseract
    except Exception as exc:  # pragma: no cover - import fallback
        return {
            "detected_plate": "",
            "confidence": Decimal("0.00"),
            "raw_text": "",
            "candidate_plates": [],
            "error": f"OCR dependencies unavailable: {exc}",
        }

    try:
        image_path, temp_path = _materialize_image(image_source)
        image = cv2.imread(image_path)
        if image is None:
            raise ValidationError({"image": "Could not read image."})
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.bilateralFilter(gray, 11, 17, 17)
        thresholded = cv2.threshold(blurred, 150, 255, cv2.THRESH_BINARY)[1]
        config = "--psm 8 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        raw_text = pytesseract.image_to_string(thresholded, config=config)
        candidate_plates = extract_plate_candidates(raw_text)
        detected_plate = candidate_plates[0] if candidate_plates else ""
        confidence = Decimal("92.00") if detected_plate else Decimal("0.00")
        return {
            "detected_plate": detected_plate,
            "confidence": confidence,
            "raw_text": raw_text.strip(),
            "candidate_plates": candidate_plates,
        }
    except Exception as exc:
        return {
            "detected_plate": "",
            "confidence": Decimal("0.00"),
            "raw_text": "",
            "candidate_plates": [],
            "error": str(exc),
        }
    finally:
        if temp_path and os.path.exists(temp_path):
            with suppress(Exception):
                os.unlink(temp_path)
