from unittest import TestCase
from unittest.mock import patch

from omc_app.setup import operations


class TestCatalogueOperations(TestCase):
    @patch(
        "omc_app.setup.service_catalogue.presentation.preview_service_presentation"
    )
    @patch(
        "omc_app.setup.service_catalogue.provisioner.preview_service_catalogue"
    )
    def test_preview_surfaces_manifest_presentation_changes(
        self,
        catalogue_preview,
        presentation_preview,
    ):
        catalogue_preview.return_value = {
            "ok": True,
            "read_only": True,
            "ready_to_sync": True,
            "summary": {"totals": {}},
        }
        presentation_preview.return_value = {
            "ok": True,
            "read_only": True,
            "updated": 31,
            "unchanged": 0,
            "missing_services": [],
            "assignment_role": "Employee",
            "errors": [],
        }

        result = operations.preview_service_catalogue()

        self.assertTrue(result["ready_to_sync"])
        self.assertEqual(result["presentation"]["updated"], 31)
        self.assertEqual(
            result["presentation"]["assignment_role"],
            "Employee",
        )

    @patch(
        "omc_app.setup.service_catalogue.presentation.preview_service_presentation"
    )
    @patch(
        "omc_app.setup.service_catalogue.provisioner.preview_service_catalogue"
    )
    def test_preview_fails_closed_on_invalid_presentation_source(
        self,
        catalogue_preview,
        presentation_preview,
    ):
        catalogue_preview.return_value = {
            "ok": True,
            "read_only": True,
            "ready_to_sync": True,
        }
        presentation_preview.return_value = {
            "ok": False,
            "read_only": True,
            "errors": ["invalid copy"],
        }

        result = operations.preview_service_catalogue()

        self.assertFalse(result["ready_to_sync"])

    @patch(
        "omc_app.setup.service_catalogue.presentation.validate_service_presentation"
    )
    @patch(
        "omc_app.setup.service_catalogue.provisioner.validate_service_catalogue"
    )
    def test_validation_requires_catalogue_and_presentation_to_converge(
        self,
        catalogue_validate,
        presentation_validate,
    ):
        catalogue_validate.return_value = {
            "ok": True,
            "valid": True,
            "ready_to_sync": True,
        }
        presentation_validate.return_value = {
            "ok": True,
            "valid": False,
            "updated": 1,
            "assignment_role": "Employee",
        }

        result = operations.validate_service_catalogue()

        self.assertFalse(result["valid"])
        self.assertFalse(result["presentation"]["valid"])
