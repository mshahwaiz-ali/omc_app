function omc_receipt_idempotency_key(paymentName) {
  const randomPart =
    window.crypto && window.crypto.randomUUID
      ? window.crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `desk-receipt:${paymentName}:${randomPart}`;
}


function omc_read_receipt_as_base64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const value = String(reader.result || '');
      const marker = value.indexOf(',');
      resolve(marker >= 0 ? value.slice(marker + 1) : value);
    };
    reader.onerror = () => reject(reader.error || new Error('Unable to read receipt file.'));
    reader.readAsDataURL(file);
  });
}


function omc_pick_receipt_file() {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png';
    input.onchange = () => resolve(input.files && input.files[0] ? input.files[0] : null);
    input.click();
  });
}


async function omc_staff_upload_receipt(frm) {
  const file = await omc_pick_receipt_file();
  if (!file) return;

  const dialog = new frappe.ui.Dialog({
    title: __('Upload Receipt on Behalf of Customer'),
    fields: [
      {
        fieldname: 'selected_file',
        fieldtype: 'Data',
        label: __('Selected File'),
        default: file.name,
        read_only: 1,
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
        label: __('Submission Remarks'),
        description: __('This upload will be recorded as Staff On Behalf with your user identity.'),
      },
    ],
    primary_action_label: __('Upload Receipt'),
    primary_action: async (values) => {
      dialog.disable_primary_action();
      try {
        const contentBase64 = await omc_read_receipt_as_base64(file);
        await frappe.call({
          method: 'omc_app.api.payment_mutation_guard.staff_upload_payment_receipt_file',
          type: 'POST',
          args: {
            payment_id: frm.doc.name,
            file_name: file.name,
            content_base64: contentBase64,
            payment_reference: values.payment_reference,
            remarks: values.remarks,
            idempotency_key: omc_receipt_idempotency_key(frm.doc.name),
          },
          freeze: true,
          freeze_message: __('Uploading and validating receipt...'),
        });
        dialog.hide();
        await frm.reload_doc();
        frappe.show_alert({
          message: __('Receipt uploaded on behalf of customer.'),
          indicator: 'green',
        });
      } finally {
        dialog.enable_primary_action();
      }
    },
  });

  dialog.show();
}


function omc_lock_payment_form(frm) {
  const authoritative_fields = [
    'service_request',
    'payment_title',
    'amount',
    'accounted_amount',
    'currency',
    'status',
    'receipt_status',
    'accounting_status',
    'quarantine_status',
    'due_date',
    'paid_on',
    'payment_reference',
    'receipt_attachment',
    'visible_to_customer',
    'linked_invoice',
    'linked_payment_entry',
    'reviewed_by',
    'reviewed_at',
    'settled_at',
    'remarks',
  ];

  authoritative_fields.forEach((fieldname) => {
    if (frm.fields_dict[fieldname]) {
      frm.set_df_property(fieldname, 'read_only', 1);
    }
  });

  frm.disable_save();

  if (frm.is_new()) {
    frm.dashboard.clear_headline();
    frm.dashboard.set_headline_alert(
      `<div class="indicator orange">
        ${__('Payments are created from the Service Request workflow.')}
      </div>`,
    );

    frm.page.set_primary_action(
      __('Go to Service Requests'),
      () => frappe.set_route('List', 'OMC Service Request'),
    );
  }
}


frappe.ui.form.on('OMC Service Payment', {
  refresh(frm) {
    omc_lock_payment_form(frm);

    if (frm.is_new()) return;

    const uploadable = ['Pending', 'Receipt Submitted', 'Under Review', 'Rejected'].includes(
      frm.doc.status,
    );
    if (uploadable) {
      frm.add_custom_button(
        __('Upload Receipt'),
        () => omc_staff_upload_receipt(frm),
        __('Payment Review'),
      );
    }

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
