import unittest

from omc_app.setup.service_catalogue.manifest import (
    SERVICES,
)
from omc_app.setup.service_catalogue.requirements import (
    DOCUMENTS_BY_SERVICE,
    FORM_FIELDS_BY_SERVICE,
    PRESERVED_LIVE_SERVICE_IDS,
    validate_requirements,
)


class TestServiceCatalogueRequirements(unittest.TestCase):
    def test_requirements_are_internally_valid(self):
        result = validate_requirements()

        self.assertTrue(result["ok"])
        self.assertEqual(result["services"], 31)
        self.assertGreater(
            result["document_templates"],
            0,
        )
        self.assertGreater(
            result["form_fields"],
            0,
        )

    def test_every_service_has_explicit_requirement_sets(self):
        service_ids = {
            item.service_id
            for item in SERVICES
        }

        self.assertEqual(
            set(DOCUMENTS_BY_SERVICE),
            service_ids,
        )
        self.assertEqual(
            set(FORM_FIELDS_BY_SERVICE),
            service_ids,
        )

    def test_live_ntn_and_gst_are_explicitly_preserved(self):
        self.assertEqual(
            PRESERVED_LIVE_SERVICE_IDS,
            {
                "gst-registration",
                "ntn-registration",
            },
        )

        self.assertEqual(
            [
                item.fieldname
                for item in FORM_FIELDS_BY_SERVICE[
                    "ntn-registration"
                ]
            ],
            [
                "active_mobile_number",
                "active_email_address",
                "residential_address",
            ],
        )

        self.assertEqual(
            [
                item.title
                for item in DOCUMENTS_BY_SERVICE[
                    "gst-registration"
                ]
            ],
            [
                "CNIC front and back",
                "NTN certificate",
                "Business address proof",
                "Electricity or gas bill",
                "Bank account proof",
            ],
        )

    def test_no_form_collects_password_or_otp(self):
        for service_id, fields in (
            FORM_FIELDS_BY_SERVICE.items()
        ):
            for field in fields:
                text = (
                    f"{field.fieldname} {field.label}"
                ).lower()

                self.assertNotIn(
                    "password",
                    text,
                    service_id,
                )
                self.assertNotIn(
                    "passcode",
                    text,
                    service_id,
                )
                self.assertNotIn(
                    "otp",
                    text,
                    service_id,
                )
