import unittest

from omc_app.setup.service_catalogue.manifest import (
    EXPECTED_ACTIVE_SERVICE_COUNT,
    EXPECTED_SERVICE_COUNT,
    EXPECTED_TASK_TYPES,
    SERVICES,
    service_by_id,
    validate_manifest,
)


class TestServiceCatalogueManifest(unittest.TestCase):
    def test_manifest_is_internally_valid(self):
        result = validate_manifest()

        self.assertTrue(result["ok"])
        self.assertEqual(
            result["services"],
            EXPECTED_SERVICE_COUNT,
        )
        self.assertEqual(
            result["active_services"],
            EXPECTED_ACTIVE_SERVICE_COUNT,
        )
        self.assertEqual(result["inactive_services"], 14)

    def test_exact_erp_task_type_contract_is_preserved(self):
        self.assertEqual(
            tuple(item.erp_task_type for item in SERVICES),
            EXPECTED_TASK_TYPES,
        )

        services = service_by_id()

        self.assertEqual(
            services["ntn-modification"].erp_task_type,
            "NTN  MODIFICATION",
        )
        self.assertEqual(
            services["other-sources"].erp_task_type,
            "other sources",
        )
        self.assertEqual(
            services["pos-intergation"].erp_task_type,
            "POS intergation",
        )

    def test_unknown_price_services_are_not_published_as_free(self):
        services = service_by_id()

        for service_id in ("tax-club", "ubl-lead"):
            service = services[service_id]
            self.assertEqual(service.base_price, 0)
            self.assertFalse(service.is_active)
            self.assertEqual(service.price_source, "unknown")

    def test_existing_ntn_and_gst_remain_published(self):
        services = service_by_id()

        self.assertTrue(
            services["ntn-registration"].is_active
        )
        self.assertTrue(
            services["gst-registration"].is_active
        )
