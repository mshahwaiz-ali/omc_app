frappe.ui.form.on('OMC Service Payment', {
  refresh(frm) {
    if (frm.is_new()) return;

    const reviewable = ['Receipt Submitted', 'Under Review'].includes(frm.doc.status);
    if (!reviewable || !frm.doc.receipt_attachment) return;

    frm.add_custom_button(__('Verify Receipt'), async () => {
      const context = await frappe.call({
        method: 'omc_app.api.payment_accounting.get_review_context',
        args: { payment_id: frm.doc.name },
      });
      const data = context.message || {};
      const accounts = data.payment_accounts || [];
      const defaultAccount = accounts.length === 1 ? accounts[0].name : '';

      const dialog = new frappe.ui.Dialog({
        title: __('Verify Payment Receipt'),
        fields: [
          {
            fieldname: 'verified_amount',
            fieldtype: 'Currency',
            label: __('Verified Amount'),
            options: 'currency',
            default: data.remaining_amount || 0,
            reqd: 1,
          },
          {
            fieldname: 'currency',
            fieldtype: 'Data',
            label: __('Currency'),
            default: data.currency || frm.doc.currency,
            read_only: 1,
          },
          {
            fieldname: 'payment_account',
            fieldtype: 'Link',
            label: __('Received In'),
            options: 'OMC Payment Account',
            default: defaultAccount,
            reqd: 1,
          },
          {
            fieldname: 'payment_reference',
            fieldtype: 'Data',
            label: __('Payment Reference'),
            default: frm.doc.payment_reference || '',
          },
          {
            fieldname: 'remarks',
            fieldtype: 'Small Text',
            label: __('Review Remarks'),
          },
        ],
        primary_action_label: __('Verify & Start Accounting'),
        primary_action: async (values) => {
          dialog.disable_primary_action();
          try {
            await frappe.call({
              method: 'omc_app.api.payment_mutation_guard.review_payment_receipt',
              type: 'POST',
              args: {
                payment_id: frm.doc.name,
                status: 'Verified',
                verified_amount: values.verified_amount,
                payment_account: values.payment_account,
                payment_reference: values.payment_reference,
                remarks: values.remarks,
              },
              freeze: true,
              freeze_message: __('Verifying receipt and queuing ERP accounting...'),
            });
            dialog.hide();
            await frm.reload_doc();
            frappe.show_alert({ message: __('Receipt verified. ERP accounting has been queued.'), indicator: 'green' });
          } finally {
            dialog.enable_primary_action();
          }
        },
      });
      dialog.show();
    }, __('Payment Review'));

    frm.add_custom_button(__('Reject Receipt'), () => {
      frappe.prompt(
        [{ fieldname: 'remarks', fieldtype: 'Small Text', label: __('Reason'), reqd: 1 }],
        async (values) => {
          await frappe.call({
            method: 'omc_app.api.payment_mutation_guard.review_payment_receipt',
            type: 'POST',
            args: {
              payment_id: frm.doc.name,
              status: 'Rejected',
              remarks: values.remarks,
            },
            freeze: true,
            freeze_message: __('Rejecting receipt...'),
          });
          await frm.reload_doc();
        },
        __('Reject Payment Receipt'),
        __('Reject')
      );
    }, __('Payment Review'));
  },
});
