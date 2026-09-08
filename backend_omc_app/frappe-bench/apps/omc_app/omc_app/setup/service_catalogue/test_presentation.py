from unittest import TestCase

from omc_app.setup.service_catalogue.manifest import SERVICES
from omc_app.setup.service_catalogue.presentation import (
    PRESENTATION_FIELDS,
    desired_presentation,
    validate_presentation_source,
)


class TestServicePresentationSource(TestCase):
    def test_copy_covers_exact_manifest(self):
        self.assertEqual(len(SERVICES), 31)
        self.assertEqual(len({service.service_id for service in SERVICES}), 31)

    def test_copy_is_complete_and_concise(self):
        result = validate_presentation_source()
        self.assertTrue(result["ok"], result["errors"])

        for service in SERVICES:
            self.assertTrue(service.short_description, service.service_id)
            self.assertTrue(service.description, service.service_id)
            self.assertTrue(service.support_message, service.service_id)
            self.assertLessEqual(len(service.short_description), 240)
            self.assertLessEqual(len(service.support_message), 240)

            desired = desired_presentation(service.service_id)
            self.assertEqual(desired["short_description"], service.short_description)
            self.assertEqual(desired["description"], service.description)
            self.assertEqual(desired["support_message"], service.support_message)
            self.assertNotIn("default_assignment_role", desired)

    def test_assignment_is_not_catalogue_presentation_state(self):
        self.assertEqual(
            PRESENTATION_FIELDS,
            ("short_description", "description", "support_message"),
        )
        for service in SERVICES:
            self.assertNotIn(
                "default_assignment_role",
                desired_presentation(service.service_id),
            )
