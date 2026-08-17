"""Canonical Work / Business Address contract for OMC customer profiles."""

from __future__ import annotations

import json
import math
from typing import Any

import frappe
from frappe import _
from frappe.exceptions import ValidationError
from frappe.utils import now_datetime


TEXT_LIMITS = {
    "work_address": 500,
    "work_address_details": 500,
    "google_place_id": 255,
    "work_city": 140,
    "work_district": 140,
    "work_province": 140,
    "work_postal_code": 40,
    "work_country": 140,
    "work_location_source": 40,
}

INPUT_FIELDS = (
    "work_address",
    "work_address_details",
    "work_latitude",
    "work_longitude",
    "google_place_id",
    "work_city",
    "work_district",
    "work_province",
    "work_postal_code",
    "work_country",
    "work_location_source",
)

ADDRESS_FIELDS = set(INPUT_FIELDS)

LOCATION_SOURCES = {
    "",
    "GPS",
    "Google Search",
    "Map Pin",
}


def _text(value: Any, fieldname: str, max_length: int) -> str:
    if value is not None and not isinstance(value, (str, int, float)):
        frappe.throw(
            _("{0} must be text.").format(fieldname),
            ValidationError,
        )

    clean = str(value or "").strip()
    if len(clean) > max_length:
        frappe.throw(
            _("{0} must be {1} characters or fewer.").format(
                fieldname,
                max_length,
            ),
            ValidationError,
        )
    return clean


def _coordinate(value: Any, fieldname: str, minimum: float, maximum: float):
    if value is None or str(value).strip() == "":
        return None

    if isinstance(value, bool):
        frappe.throw(
            _("{0} must be a valid coordinate.").format(fieldname),
            ValidationError,
        )

    try:
        number = float(value)
    except (TypeError, ValueError):
        frappe.throw(
            _("{0} must be a valid coordinate.").format(fieldname),
            ValidationError,
        )

    if not math.isfinite(number) or number < minimum or number > maximum:
        frappe.throw(
            _("{0} is outside the valid coordinate range.").format(fieldname),
            ValidationError,
        )

    return number


def clean_input(data: dict | None) -> dict:
    source = dict(data or {})
    cleaned = {}

    for fieldname, max_length in TEXT_LIMITS.items():
        if fieldname in source:
            cleaned[fieldname] = _text(
                source.get(fieldname),
                fieldname,
                max_length,
            )

    if "work_latitude" in source:
        cleaned["work_latitude"] = _coordinate(
            source.get("work_latitude"),
            "work_latitude",
            -90.0,
            90.0,
        )

    if "work_longitude" in source:
        cleaned["work_longitude"] = _coordinate(
            source.get("work_longitude"),
            "work_longitude",
            -180.0,
            180.0,
        )

    location_source = cleaned.get("work_location_source")
    if (
        location_source is not None
        and location_source not in LOCATION_SOURCES
    ):
        frappe.throw(
            _(
                "work_location_source must be GPS, Google Search, or Map Pin."
            ),
            ValidationError,
        )

    return cleaned


def _meaningful_location_value(fieldname: str, value: Any) -> bool:
    if fieldname in {"work_latitude", "work_longitude"}:
        return value is not None
    return bool(str(value or "").strip())


def validate_candidate(candidate: dict) -> dict:
    validated = dict(candidate or {})

    latitude = validated.get("work_latitude")
    longitude = validated.get("work_longitude")

    if (latitude is None) != (longitude is None):
        frappe.throw(
            _(
                "Work address latitude and longitude must be provided together."
            ),
            ValidationError,
        )

    has_any = any(
        _meaningful_location_value(fieldname, validated.get(fieldname))
        for fieldname in INPUT_FIELDS
    )

    if not has_any:
        return validated

    if latitude is None or longitude is None:
        frappe.throw(
            _(
                "Select a map pin for the Work / Business Address."
            ),
            ValidationError,
        )

    if not str(validated.get("work_address") or "").strip():
        frappe.throw(
            _(
                "A formatted Work / Business Address is required for the selected map pin."
            ),
            ValidationError,
        )

    if not str(validated.get("work_location_source") or "").strip():
        validated["work_location_source"] = "Map Pin"

    return validated


def signup_payload(data: dict | None) -> dict:
    """Return optional validated signup location fields."""

    source = dict(data or {})
    if not any(fieldname in source for fieldname in INPUT_FIELDS):
        return {}

    cleaned = clean_input(source)

    candidate = {
        fieldname: cleaned.get(fieldname)
        for fieldname in INPUT_FIELDS
        if fieldname in cleaned
    }

    return validate_candidate(candidate)


def profile_values(profile) -> dict:
    result = {}

    for fieldname in INPUT_FIELDS:
        if not profile or not profile.meta.has_field(fieldname):
            result[fieldname] = (
                None
                if fieldname in {"work_latitude", "work_longitude"}
                else ""
            )
            continue

        value = profile.get(fieldname)
        if fieldname in {"work_latitude", "work_longitude"}:
            if value is None or str(value).strip() == "":
                result[fieldname] = None
            else:
                result[fieldname] = float(value)
        else:
            result[fieldname] = str(value or "")

    # Frappe Float fields may materialize an unset value as 0.0. Do not
    # interpret that storage default as an intentional Equator/Greenwich pin
    # unless some actual Work Address context also exists.
    if (
        profile
        and result.get("work_latitude") == 0.0
        and result.get("work_longitude") == 0.0
    ):
        location_context_fields = (
            "work_address",
            "work_address_details",
            "google_place_id",
            "work_city",
            "work_district",
            "work_province",
            "work_postal_code",
            "work_country",
            "work_location_source",
        )

        has_location_context = any(
            str(result.get(fieldname) or "").strip()
            for fieldname in location_context_fields
        )

        geolocation = ""
        if profile.meta.has_field("work_geolocation"):
            geolocation = str(
                profile.get("work_geolocation") or ""
            ).strip()

        if not has_location_context and not geolocation:
            result["work_latitude"] = None
            result["work_longitude"] = None

    return result


def merged_candidate(profile, changes: dict) -> dict:
    candidate = profile_values(profile)
    candidate.update(clean_input(changes))
    return validate_candidate(candidate)


def has_work_address(profile_or_values) -> bool:
    if isinstance(profile_or_values, dict):
        values = profile_or_values
    else:
        values = profile_values(profile_or_values)

    return bool(
        str(values.get("work_address") or "").strip()
        and values.get("work_latitude") is not None
        and values.get("work_longitude") is not None
    )


def geolocation_json(latitude, longitude) -> str:
    if latitude is None or longitude is None:
        return ""

    return json.dumps(
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {},
                    "geometry": {
                        "type": "Point",
                        # GeoJSON order is longitude, latitude.
                        "coordinates": [
                            float(longitude),
                            float(latitude),
                        ],
                    },
                }
            ],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def google_maps_url(latitude, longitude) -> str:
    if latitude is None or longitude is None:
        return ""

    return (
        "https://www.google.com/maps/search/?api=1&query="
        f"{float(latitude):.8f},{float(longitude):.8f}"
    )


def apply_profile_geolocation(profile) -> None:
    if not profile.meta.has_field("work_latitude"):
        return

    values = validate_candidate(profile_values(profile))
    latitude = values.get("work_latitude")
    longitude = values.get("work_longitude")

    if profile.meta.has_field("work_geolocation"):
        profile.work_geolocation = geolocation_json(
            latitude,
            longitude,
        )

    changed = False
    if profile.is_new():
        changed = has_work_address(values)
    else:
        for fieldname in ADDRESS_FIELDS:
            if (
                profile.meta.has_field(fieldname)
                and profile.has_value_changed(fieldname)
            ):
                changed = True
                break

    if (
        changed
        and profile.meta.has_field("work_location_updated_on")
    ):
        profile.work_location_updated_on = now_datetime()


def api_payload(profile) -> dict:
    values = profile_values(profile)
    completed = has_work_address(values)

    dismissed = bool(
        profile
        and profile.meta.has_field("work_address_prompt_dismissed")
        and int(profile.get("work_address_prompt_dismissed") or 0)
    )

    return {
        **values,
        "work_google_maps_url": google_maps_url(
            values.get("work_latitude"),
            values.get("work_longitude"),
        ),
        "has_work_address": completed,
        "needs_work_address_prompt": (
            not completed and not dismissed
        ),
    }
