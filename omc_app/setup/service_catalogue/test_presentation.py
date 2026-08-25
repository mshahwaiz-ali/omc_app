from unittest import TestCase

from omc_app.setup.service_catalogue.manifest import (
    DEFAULT_ASSIGNMENT_ROLE,
    SERVICES,
)
from omc_app.setup.service_catalogue.presentation import (
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
            self.assertEqual(
                desired["default_assignment_role"],
                DEFAULT_ASSIGNMENT_ROLE,
            )

    def test_managed_services_default_to_employee_assignment(self):
        self.assertEqual(DEFAULT_ASSIGNMENT_ROLE, "Employee")
        for service in SERVICES:
            self.assertEqual(service.default_assignment_role, "Employee")
