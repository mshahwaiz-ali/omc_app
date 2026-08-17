import json

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import profile_location


class TestProfileLocation(FrappeTestCase):
    def test_signup_location_is_optional(self):
        self.assertEqual(
            profile_location.signup_payload({}),
            {},
        )

    def test_coordinate_pair_is_required(self):
        with self.assertRaises(frappe.ValidationError):
            profile_location.signup_payload(
                {
                    "work_address": "Test office",
                    "work_latitude": 31.5,
                }
            )

    def test_invalid_coordinate_range_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            profile_location.signup_payload(
                {
                    "work_address": "Test office",
                    "work_latitude": 91,
                    "work_longitude": 74,
                }
            )

    def test_valid_pin_builds_geojson_with_longitude_first(self):
        payload = profile_location.signup_payload(
            {
                "work_address": "Test office, Lahore",
                "work_latitude": 31.5204,
                "work_longitude": 74.3587,
                "work_location_source": "GPS",
            }
        )

        value = json.loads(
            profile_location.geolocation_json(
                payload["work_latitude"],
                payload["work_longitude"],
            )
        )

        coordinates = (
            value["features"][0]["geometry"]["coordinates"]
        )

        self.assertEqual(
            coordinates,
            [74.3587, 31.5204],
        )

    def test_zero_coordinates_are_valid(self):
        payload = profile_location.signup_payload(
            {
                "work_address": "Equator office",
                "work_latitude": 0,
                "work_longitude": 0,
                "work_location_source": "Map Pin",
            }
        )

        self.assertTrue(
            profile_location.has_work_address(payload)
        )
