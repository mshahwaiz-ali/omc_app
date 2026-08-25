from unittest import TestCase

from omc_app.setup.service_catalogue.manifest import SERVICES
from omc_app.setup.service_catalogue.presentation import (
    DEFAULT_ASSIGNMENT_ROLE,
    SERVICE_PRESENTATION,
    validate_presentation_source,
)


class TestServicePresentationSource(TestCase):
    def test_copy_covers_exact_manifest(self):
        expected = {service.service_id for service in SERVICES}
        self.assertEqual(set(SERVICE_PRESENTATION), expected)
        self.assertEqual(len(SERVICE_PRESENTATION), 31)

    def test_copy_is_complete_and_concise(self):
        result = validate_presentation_source()
        self.assertTrue(result["ok"], result["errors"])

        for service_id, copy in SERVICE_PRESENTATION.items():
            self.assertTrue(copy["short_description"], service_id)
            self.assertTrue(copy["description"], service_id)
            self.assertTrue(copy["support_message"], service_id)
            self.assertLessEqual(len(copy["short_description"]), 240)
            self.assertLessEqual(len(copy["support_message"]), 240)

    def test_managed_services_default_to_employee_assignment(self):
        self.assertEqual(DEFAULT_ASSIGNMENT_ROLE, "Employee")
