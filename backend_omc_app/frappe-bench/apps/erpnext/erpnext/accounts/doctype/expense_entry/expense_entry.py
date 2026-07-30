# -*- coding: utf-8 -*-
# Copyright (c) 2022, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt

from __future__ import unicode_literals
# import frappe

import frappe
from frappe.model.document import Document
import json
from frappe.utils import getdate, add_days, get_time,today
from frappe import _
import datetime
from frappe.core.doctype.sms_settings.sms_settings import send_sms
from datetime import timedelta, datetime, date


class ExpenseEntry(Document):
	pass

	def before_save(self):
		self.petty_cash_acc()

	def on_submit(self):
		self.create_jv()

	def on_cancel(self):
		self.cancel_jv()

	@frappe.whitelist()
	def create_jv(self):
		jv = frappe.new_doc('Journal Entry')
		jv.voucher_type = "Cash Entry"
		jv.company = self.company
		jv.posting_date = self.posting_date
		jv.total_debit = self.total_debit_amount
		jv.total_cridet = self.total_debit_amount
		cost_center = frappe.db.get_value("Company", self.company, "cost_center")
		for jv_detail in self.expence_entry_accounts:
			accounts = jv.append('accounts')
			accounts.account = jv_detail.account
			accounts.user_remark = jv_detail.remakrs
			accounts.debit_in_account_currency = jv_detail.amount
			accounts.cost_center = cost_center
			accounts.branch = self.branch
		accountscr = jv.append('accounts')
		accountscr.account = self.petty_cash_account
		accountscr.credit_in_account_currency = self.total_debit_amount
		accountscr.cost_center = cost_center
		accountscr.branch = self.branch
		jv.reference_expense_entry = self.name
		jv.save()
		jv.submit()

		# Add the Journal Entry name to the Expense Entry
		frappe.db.set_value("Expense Entry", self.name, "journal_entry", jv.name)

	def petty_cash_acc(self):
		from erpnext.accounts.utils import get_balance_on
		account_balance = get_balance_on(self.petty_cash_account)
		self.account_balance = account_balance
		total_debit = 0
		for row in self.expence_entry_accounts:
			total_debit += row.amount
		self.total_debit_amount = total_debit
		self.total_balance = self.account_balance - self.total_debit_amount

	def cancel_jv(self):
		# Get the associated Journal Entry by reference
		jv_name = frappe.db.get_value(
			"Journal Entry", {"reference_expense_entry": self.name}, "name"
		)
		if jv_name:
			# Fetch and cancel the Journal Entry
			jv_doc = frappe.get_doc("Journal Entry", jv_name)
			if jv_doc.docstatus == 1:  # Check if the document is submitted
				jv_doc.cancel()
