from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import public_catalogue


class TestPublicCatalogueCompatibility(FrappeTestCase):
    def test_legacy_estimated_duration_is_derived_from_completion_time(self):
        service = SimpleNamespace()
        with patch.object(
            public_catalogue.mobile,
            "_service_to_catalogue_dict",
            return_value={
                "completion_time": "3 working days",
                "completionTime": "3 working days",
                "estimated_duration": "stale legacy value",
            },
        ):
            payload = public_catalogue._public_service_payload(service)

        self.assertEqual(payload["completion_time"], "3 working days")
        self.assertEqual(payload["estimated_duration"], "3 working days")

    def test_legacy_duration_alias_falls_back_to_camel_case_canonical_value(self):
        service = SimpleNamespace()
        with patch.object(
            public_catalogue.mobile,
            "_service_to_catalogue_dict",
            return_value={"completionTime": "Same day"},
        ):
            payload = public_catalogue._public_service_payload(service)

        self.assertEqual(payload["estimated_duration"], "Same day")
