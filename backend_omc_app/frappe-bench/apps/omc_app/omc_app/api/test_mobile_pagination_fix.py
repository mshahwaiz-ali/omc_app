from contextlib import ExitStack
from unittest import TestCase
from unittest.mock import patch
import frappe
from omc_app.api import public_catalogue, mobile, lead_read_guard, expense, expense_read_guard


class TestMobilePaginationFix(TestCase):
    def test_catalogue_default_keeps_documents_and_lightweight_is_opt_in(self):
        with patch.object(frappe, 'get_all', return_value=[frappe._dict(name='s')]), patch.object(public_catalogue, '_public_service_payload', return_value={'id': 's'}) as payload:
            public_catalogue.get_service_catalogue()
            self.assertTrue(payload.call_args.kwargs['include_required_documents'])
            public_catalogue.get_service_catalogue(lightweight=1)
            self.assertFalse(payload.call_args.kwargs['include_required_documents'])

    def test_customer_scope_precedes_search_and_page(self):
        with ExitStack() as stack:
            stack.enter_context(patch.object(mobile, '_assert_internal_workspace_access', return_value='staff'))
            stack.enter_context(patch.object(mobile, '_require_canonical_capability', return_value={'can_view_relevant_customers': True}))
            stack.enter_context(patch.object(mobile, '_relevant_customer_names', return_value=['owned']))
            query = stack.enter_context(patch.object(frappe, 'get_all', return_value=[]))
            mobile.get_customers(start=100, limit=50, search='needle')
            self.assertEqual(query.call_args.kwargs['filters'], {'name': ['in', ['owned']]})
            self.assertEqual(query.call_args.kwargs['limit_start'], 100)
            self.assertEqual(query.call_args.kwargs['limit_page_length'], 51)
            self.assertIn('full_name', query.call_args.kwargs['or_filters'])

    def test_lead_page_still_requires_canonical_permission(self):
        with patch.object(mobile, '_assert_internal_workspace_access'), patch.object(mobile, '_require_canonical_capability', side_effect=PermissionError), patch.object(frappe, 'get_all') as query:
            with self.assertRaises(PermissionError):
                lead_read_guard.get_leads(start=100, search='secret')
            query.assert_not_called()

    def test_expense_page_has_continuation_and_full_summary(self):
        with patch.object(expense, '_profile', return_value=frappe._dict(name='owned')), patch.object(expense, '_has_doctype', return_value=True), patch.object(frappe, 'get_all', return_value=[frappe._dict(name=str(i)) for i in range(201)]) as query, patch.object(expense, '_entry_to_dict', side_effect=lambda row: {'id': row.name}), patch.object(expense, '_complete_summary', return_value={'transaction_count': 201, 'expenses': 2010}):
            page = expense.get_expense_entries(limit=200)
            self.assertEqual(len(page['entries']), 200)
            self.assertEqual(page['next_start'], 200)
            self.assertEqual(page['summary']['transaction_count'], 201)
            self.assertEqual(query.call_args.kwargs['filters']['customer_profile'], 'owned')

    def test_read_guard_preserves_full_summary(self):
        with patch.object(expense, 'get_expense_entries', return_value={'entries': [], 'summary': {'transaction_count': 201}, 'next_start': 100}):
            self.assertEqual(expense_read_guard.get_expense_entries()['summary']['transaction_count'], 201)
