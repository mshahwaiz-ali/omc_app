from types import SimpleNamespace
import unittest
from unittest.mock import patch

from omc_app.omc_app.doctype.omc_service.omc_service import (
    OMCService,
)
from omc_app.omc_app.doctype.omc_service_category.omc_service_category import (
    OMCServiceCategory,
)


class TestStableCatalogueIdentity(unittest.TestCase):
    def test_service_honours_explicit_service_id(self):
        document = SimpleNamespace(
            service_id="pvt-registration-services",
            title="Private Limited Company Registration",
            name=None,
        )

        with patch(
            "omc_app.omc_app.doctype.omc_service.omc_service."
            "frappe.db.exists"
        ) as exists:
            OMCService.autoname(document)

        self.assertEqual(
            document.name,
            "pvt-registration-services",
        )
        self.assertEqual(
            document.service_id,
            "pvt-registration-services",
        )
        exists.assert_not_called()

    def test_service_keeps_title_derived_legacy_behaviour(self):
        document = SimpleNamespace(
            service_id="",
            title="Private Limited Company Registration",
            name=None,
        )

        with patch(
            "omc_app.omc_app.doctype.omc_service.omc_service."
            "frappe.db.exists",
            return_value=False,
        ):
            OMCService.autoname(document)

        self.assertEqual(
            document.name,
            "private-limited-company-registration",
        )
        self.assertEqual(
            document.service_id,
            "private-limited-company-registration",
        )

    def test_category_honours_explicit_category_name(self):
        document = SimpleNamespace(
            category_name="income-tax",
            title="Income Tax & Returns",
            name=None,
        )

        with patch(
            "omc_app.omc_app.doctype.omc_service_category."
            "omc_service_category.frappe.db.exists"
        ) as exists:
            OMCServiceCategory.autoname(document)

        self.assertEqual(
            document.name,
            "income-tax",
        )
        self.assertEqual(
            document.category_name,
            "income-tax",
        )
        exists.assert_not_called()

    def test_category_keeps_title_derived_legacy_behaviour(self):
        document = SimpleNamespace(
            category_name="",
            title="Income Tax & Returns",
            name=None,
        )

        with patch(
            "omc_app.omc_app.doctype.omc_service_category."
            "omc_service_category.frappe.db.exists",
            return_value=False,
        ):
            OMCServiceCategory.autoname(document)

        self.assertEqual(
            document.name,
            "income-tax-&-returns",
        )
        self.assertEqual(
            document.category_name,
            "income-tax-&-returns",
        )
