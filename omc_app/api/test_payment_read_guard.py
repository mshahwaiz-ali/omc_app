from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import payment_read_guard


class TestPaymentReadGuard(FrappeTestCase):
    def _payment(self, *, service_request="OMC-SR-TEST", visible=1):
        return SimpleNamespace(
            name="OMC-PAY-TEST",
            service_request=service_request,
            visible_to_customer=visible,
        )

    def test_hooks_route_payment_reads_through_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.payments.get_payments"],
            "omc_app.api.payment_read_guard.get_payments",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.payments.get_payment"],
            "omc_app.api.payment_read_guard.get_payment",
        )

    @patch("omc_app.api.payment_read_guard.frappe.get_doc")
    @patch("omc_app.api.payment_read_guard.frappe.db.exists")
    def test_blank_parent_is_not_readable(self, exists, get_doc):
        exists.side_effect = [True]
        get_doc.return_value = self._payment(service_request="")

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard._load_readable_payment("OMC-PAY-TEST")

    @patch("omc_app.api.payment_read_guard.frappe.get_doc")
    @patch("omc_app.api.payment_read_guard.frappe.db.exists")
    def test_missing_parent_is_not_readable(self, exists, get_doc):
        exists.side_effect = [True, False]
        get_doc.return_value = self._payment()

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard._load_readable_payment("OMC-PAY-TEST")

    @patch("omc_app.api.payment_read_guard.payments._payment_dict")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_safe_payload_skips_stale_payment(self, load_payment, payment_dict):
        load_payment.side_effect = frappe.DoesNotExistError

        result = payment_read_guard._safe_payment_payload(
            "OMC-PAY-STALE",
            capabilities={},
            customer_view=True,
        )

        self.assertIsNone(result)
        payment_dict.assert_not_called()

    @patch("omc_app.api.payment_read_guard.payments._payment_dict")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_safe_payload_preserves_canonical_serialisation(
        self,
        load_payment,
        payment_dict,
    ):
        payment = self._payment()
        load_payment.return_value = payment
        payment_dict.return_value = {"name": payment.name}

        result = payment_read_guard._safe_payment_payload(
            payment.name,
            capabilities={"can_review_payments": True},
            customer_view=False,
        )

        payment_dict.assert_called_once_with(
            payment,
            capabilities={"can_review_payments": True},
            customer_view=False,
        )
        self.assertEqual(result["name"], payment.name)

    @patch("omc_app.api.payment_read_guard.frappe.get_all")
    @patch("omc_app.api.payment_read_guard._safe_payment_payload")
    @patch("omc_app.api.payment_read_guard.payments._accessible_service_requests")
    @patch("omc_app.api.payment_read_guard.access.get_mobile_capabilities")
    @patch("omc_app.api.payment_read_guard.mobile._assert_approved_customer")
    @patch("omc_app.api.payment_read_guard.mobile._can_access_internal_workspace")
    def test_payment_list_skips_only_stale_rows(
        self,
        internal_workspace,
        approved_customer,
        capabilities,
        accessible_requests,
        safe_payload,
        get_all,
    ):
        internal_workspace.return_value = False
        profile = SimpleNamespace(name="CUS-TEST")
        approved_customer.return_value = profile
        capabilities.return_value = {}
        accessible_requests.return_value = [SimpleNamespace(name="OMC-SR-TEST")]
        get_all.side_effect = [
            [
                frappe._dict(
                    name="OMC-PAY-GOOD",
                    payment_title="Tax filing",
                    payment_reference="PK-1",
                    status="Receipt Submitted",
                    service_request="OMC-SR-TEST",
                ),
                frappe._dict(
                    name="OMC-PAY-STALE",
                    payment_title="Tax filing",
                    payment_reference="PK-2",
                    status="Receipt Submitted",
                    service_request="OMC-SR-TEST",
                ),
            ],
            [
                frappe._dict(
                    name="OMC-SR-TEST",
                    customer_name="Ayesha Khan",
                    customer_profile="OMC-CUST-1",
                    service_title="Tax Filing",
                    service="tax-filing",
                )
            ],
        ]
        safe_payload.side_effect = [
            {"name": "OMC-PAY-GOOD"},
            None,
        ]

        result = payment_read_guard.get_payments(
            limit_start=0,
            limit_page_length=1,
            search="Ayesha",
            status="Receipt Submitted,Under Review",
        )

        self.assertEqual(
            result,
            {
                "payments": [{"name": "OMC-PAY-GOOD"}],
                "limit_start": 0,
                "limit_page_length": 1,
                "total": 1,
                "has_more": False,
            },
        )
        self.assertEqual(safe_payload.call_count, 2)

    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_hidden_payment_detail_is_not_found(self, load_payment):
        load_payment.return_value = self._payment(visible=0)

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard.get_payment(payment_id="OMC-PAY-TEST")

    @patch("omc_app.api.payment_read_guard.payments._payment_receipt_urls")
    @patch("omc_app.api.payment_read_guard.payments._payment_invoice_numbers")
    @patch("omc_app.api.payment_read_guard.payments._payment_dict")
    @patch(
        "omc_app.api.payment_read_guard."
        "payments._assert_service_request_payment_access"
    )
    @patch("omc_app.api.payment_read_guard.access.get_mobile_capabilities")
    @patch("omc_app.api.payment_read_guard.mobile._assert_approved_customer")
    @patch(
        "omc_app.api.payment_read_guard."
        "mobile._can_access_internal_workspace"
    )
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_payment_detail_exposes_accounting_evidence_lists(
        self,
        load_payment,
        internal_workspace,
        approved_customer,
        capabilities,
        payment_access,
        payment_dict,
        invoice_numbers,
        receipt_urls,
    ):
        payment = self._payment()
        load_payment.return_value = payment
        internal_workspace.return_value = False
        approved_customer.return_value = SimpleNamespace(name="CUS-TEST")
        capabilities.return_value = {}
        payment_dict.return_value = {
            "name": payment.name,
            "linked_invoice": "SINV-O-03059",
            "accounted_amount": 4000,
        }
        invoice_numbers.return_value = [
            "SINV-O-03059",
            "SINV-LEGACY-00001",
        ]
        receipt_urls.return_value = [
            "/private/files/proof-1.png",
            "/private/files/proof-2.png",
        ]

        result = payment_read_guard.get_payment(
            payment_id=payment.name,
        )

        self.assertEqual(result["invoice_number"], "SINV-O-03059")
        self.assertEqual(
            result["invoice_numbers"],
            ["SINV-O-03059", "SINV-LEGACY-00001"],
        )
        self.assertEqual(
            result["receipt_urls"],
            [
                "/private/files/proof-1.png",
                "/private/files/proof-2.png",
            ],
        )
        self.assertEqual(result["accounted_amount"], 4000)
        payment_access.assert_called_once()

    def test_submitted_invoice_payment_total_counts_only_submitted_entries(self):
        calls = []

        def fake_sql(query, params):
            calls.append((query, params))
            return [(1500,)]

        fake_frappe = SimpleNamespace(
            db=SimpleNamespace(sql=fake_sql),
        )

        with patch.object(
            payment_read_guard,
            "frappe",
            fake_frappe,
        ):
            result = (
                payment_read_guard._submitted_invoice_payment_total(
                    "SINV-O-03060"
                )
            )

        self.assertEqual(result, 1500)
        self.assertEqual(len(calls), 1)

        query = " ".join(calls[0][0].split())
        params = calls[0][1]

        self.assertIn(
            "ref.reference_doctype = 'Sales Invoice'",
            query,
        )
        self.assertIn("pe.docstatus = 1", query)
        self.assertEqual(params, ("SINV-O-03060",))

    def test_invoice_pdf_render_uses_sales_format_and_erp_settlement(self):
        invoice = SimpleNamespace(
            name="SINV-O-03060",
            outstanding_amount=1500,
            currency="PKR",
        )

        with (
            patch.object(
                payment_read_guard.frappe,
                "get_doc",
                return_value=invoice,
            ),
            patch.object(
                payment_read_guard.frappe.db,
                "exists",
                return_value=True,
            ) as exists,
            patch.object(
                payment_read_guard,
                "_submitted_invoice_payment_total",
                return_value=1500,
            ) as paid_total,
            patch.object(
                payment_read_guard.printview,
                "get_html_and_style",
                return_value={
                    "html": "<div>Sales Format invoice body</div>",
                    "style": ".print-format { font-size: 9pt; }",
                },
            ) as render,
            patch.object(
                payment_read_guard,
                "fmt_money",
                return_value="PKR 1,500.00",
            ),
            patch.object(
                payment_read_guard,
                "get_pdf",
                return_value=b"pdf-content",
            ) as get_pdf,
        ):
            content = (
                payment_read_guard._render_invoice_pdf_with_outstanding(
                    invoice.name
                )
            )

        self.assertEqual(content, b"pdf-content")

        exists.assert_called_once_with(
            "Print Format",
            "Sales Format",
        )
        paid_total.assert_called_once_with(invoice.name)

        render.assert_called_once_with(
            doc=invoice,
            print_format="Sales Format",
            no_letterhead=0,
        )

        pdf_html = get_pdf.call_args.args[0]

        self.assertIn("Sales Format invoice body", pdf_html)
        self.assertIn("Paid / Settled:", pdf_html)
        self.assertIn("Outstanding Amount:", pdf_html)
        self.assertEqual(
            pdf_html.count("PKR 1,500.00"),
            2,
        )
    def test_download_invoice_pdf_returns_authenticated_erp_invoice(self):
        payment = SimpleNamespace(service_request="OMC-SR-TEST")

        with (
            patch(
                "omc_app.api.payment_read_guard._load_readable_payment"
            ) as load_payment,
            patch(
                "omc_app.api.payment_read_guard.identity.current_user"
            ) as current_user,
            patch(
                "omc_app.api.payment_read_guard.access.is_internal_user"
            ) as is_internal,
            patch(
                "omc_app.api.payment_read_guard.identity.require_owned_request"
            ) as require_owned_request,
            patch(
                "omc_app.api.payment_read_guard.security.enforce_rate_limit"
            ),
            patch(
                "omc_app.api.payment_read_guard.frappe.get_all"
            ) as get_all,
            patch(
                "omc_app.api.payment_read_guard.frappe.db.get_value"
            ) as get_value,
            patch(
                "omc_app.api.payment_read_guard."
                "_render_invoice_pdf_with_outstanding"
            ) as render_invoice_pdf,
        ):
            load_payment.return_value = payment
            current_user.return_value = "customer@example.com"
            is_internal.return_value = False
            get_all.return_value = ["SINV-O-03059"]
            get_value.return_value = 1

            previous_ignore = frappe.local.flags.get(
                "ignore_print_permissions"
            )

            def render_invoice(*args, **kwargs):
                self.assertTrue(
                    frappe.local.flags.get("ignore_print_permissions")
                )
                return b"%PDF-test"

            render_invoice_pdf.side_effect = render_invoice

            result = payment_read_guard.download_invoice_pdf(
                payment_id="OMC-PAY-TEST",
                invoice_id="SINV-O-03059",
            )

            self.assertEqual(
                frappe.local.flags.get("ignore_print_permissions"),
                previous_ignore,
            )

        require_owned_request.assert_called_once_with("OMC-SR-TEST")
        render_invoice_pdf.assert_called_once_with(
            "SINV-O-03059",
        )
        self.assertEqual(result["invoice_id"], "SINV-O-03059")
        self.assertEqual(result["file_name"], "SINV-O-03059.pdf")
        self.assertEqual(result["mime_type"], "application/pdf")
        self.assertEqual(result["file_content"], "JVBERi10ZXN0")
