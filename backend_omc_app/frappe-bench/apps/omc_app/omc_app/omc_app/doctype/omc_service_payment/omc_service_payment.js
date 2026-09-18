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


function omc_escape_html(value) {
  return String(value == null ? '' : value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  })[char]);
}


function omc_format_money(value, currency) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return '-';
  const prefix = String(currency || '').trim();
  return `${omc_escape_html(prefix)} ${amount.toLocaleString(undefined, {
    maximumFractionDigits: 6,
  })}`.trim();
}


function omc_payment_review_context_html(data) {
  const ai = data.ai || {};
  const currency = data.currency || 'PKR';
  const confidence = Number(ai.confidence || 0);
  const confidenceLabel = `${Math.round(confidence * 100)}%`;
  const warnings = Array.isArray(ai.warnings) ? ai.warnings : [];
  const accounts = Array.isArray(data.payment_accounts) ? data.payment_accounts : [];

  const warningHtml = warnings.length
    ? `<ul class="mb-0">${warnings
        .map((row) => `<li><strong>${omc_escape_html(row.code || 'Warning')}</strong>: ${omc_escape_html(row.message || '')}</li>`)
        .join('')}</ul>`
    : `<span class="text-muted">${__('No AI validation warnings.')}</span>`;

  const accountHtml = accounts.length
    ? `<ul class="mb-0">${accounts
        .map((row) => {
          const parts = [
            row.title,
            row.bank_name,
            row.account_title,
            row.account_number,
            row.iban,
          ].filter(Boolean);
          return `<li>${parts.map(omc_escape_html).join(' · ')}</li>`;
        })
        .join('')}</ul>`
    : `<span class="text-muted">${__('No valid mapped payment account is currently available.')}</span>`;

  const receiptUrl = String(data.receipt_url || '');
  const receiptHtml = receiptUrl
    ? `<a href="${omc_escape_html(receiptUrl)}" target="_blank" rel="noopener noreferrer">${__('Open original receipt')}</a>`
    : `<span class="text-muted">${__('Receipt attachment unavailable')}</span>`;

  const suggested = data.ai_suggestion_available
    ? omc_format_money(data.suggested_verified_amount, currency)
    : __('No safe AI amount suggestion');

  return `
    <div class="mb-3">
      <div><strong>${__('Original Receipt')}:</strong> ${receiptHtml}</div>
      <div><strong>${__('Expected Installment')}:</strong> ${omc_format_money(data.installment_amount, currency)}</div>
      <div><strong>${__('ERP Remaining')}:</strong> ${omc_format_money(data.erp_remaining_amount, currency)}</div>
      <div><strong>${__('Detected Amount')}:</strong> ${omc_format_money(ai.detected_amount, ai.detected_currency || currency)}</div>
      <div><strong>${__('Suggested Verified Amount')}:</strong> ${suggested}</div>
      <div><strong>${__('AI Confidence')}:</strong> ${omc_escape_html(confidenceLabel)}</div>
      <div><strong>${__('AI Status')}:</strong> ${omc_escape_html(ai.status || 'Not Requested')}</div>
      <div><strong>${__('Manual Review')}:</strong> ${data.ai_manual_review_required ? __('Required') : __('AI amount suggestion available')}</div>
      <hr>
      <div><strong>${__('Reference')}:</strong> ${omc_escape_html(ai.detected_reference || '-')}</div>
      <div><strong>${__('Bank / Wallet')}:</strong> ${omc_escape_html(ai.detected_bank || '-')}</div>
      <div><strong>${__('Beneficiary / Account')}:</strong> ${omc_escape_html(ai.detected_beneficiary || '-')}</div>
      <div><strong>${__('Date / Time')}:</strong> ${omc_escape_html([ai.detected_date, ai.detected_time].filter(Boolean).join(' ') || '-')}</div>
      <div><strong>${__('Transaction Status')}:</strong> ${omc_escape_html(ai.detected_status || '-')}</div>
      <div class="mt-2"><strong>${__('AI Warnings')}:</strong> ${warningHtml}</div>
      <div class="mt-2"><strong>${__('Valid Payment Accounts')}:</strong> ${accountHtml}</div>
    </div>
  `;
}


function omc_pay_later_idempotency_key(paymentName) {
  const randomPart =
    window.crypto && window.crypto.randomUUID
      ? window.crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `desk-pay-later:${paymentName}:${randomPart}`;
}


async function omc_add_pay_later_action(frm) {
  if (!['Pending', 'Rejected'].includes(String(frm.doc.status || '').trim())) {
    return;
  }

  try {
    const response = await frappe.call({
      method: 'omc_app.api.pay_later.get_approval_context',
      args: { payment_id: frm.doc.name },
    });
    const context = response.message || {};

    if (!context.can_approve || !context.eligible || context.approved) {
      return;
    }

    frm.add_custom_button(
      __('Approve Pay Later'),
      () => {
        frappe.prompt(
          [
            {
              fieldname: 'reason',
              fieldtype: 'Small Text',
              label: __('Reason'),
              reqd: 1,
              description: __(
                'Pay Later is a request-specific finance approval. No Payment Entry or Sales Invoice is created by this action.'
              ),
            },
          ],
          async (values) => {
            await frappe.call({
              method: 'omc_app.api.pay_later.approve_pay_later',
              type: 'POST',
              args: {
                payment_id: frm.doc.name,
                reason: values.reason,
                idempotency_key: omc_pay_later_idempotency_key(frm.doc.name),
              },
              freeze: true,
              freeze_message: __('Approving Pay Later and queuing service activation...'),
            });

            frappe.show_alert({
              message: __('Pay Later approved. Service activation has been queued.'),
              indicator: 'green',
            });
            await frm.reload_doc();
          },
          __('Approve Pay Later'),
          __('Approve')
        );
      },
      __('Payment Review')
    );
  } catch (error) {
    console.warn('Unable to load Pay Later approval context', error);
  }
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

    void omc_add_pay_later_action(frm);

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
        method: 'omc_app.api.payment_review_context_guard.get_review_context',
        args: { payment_id: frm.doc.name },
      });
      const data = context.message || {};
      const ai = data.ai || {};
      const accounts = data.payment_accounts || [];
      const defaultAccount = accounts.length === 1 ? accounts[0].name : '';
      const defaultVerifiedAmount = data.ai_suggestion_available
        ? data.suggested_verified_amount
        : 0;

      const dialog = new frappe.ui.Dialog({
        title: __('Verify Payment Receipt'),
        fields: [
          {
            fieldname: 'review_context',
            fieldtype: 'HTML',
            options: omc_payment_review_context_html(data),
          },
          {
            fieldname: 'verified_amount',
            fieldtype: 'Currency',
            label: __('Verified Amount'),
            options: 'currency',
            default: defaultVerifiedAmount,
            reqd: 1,
            description: data.ai_suggestion_available
              ? __('AI populated this as a suggestion only. Confirm or edit it after checking the original receipt.')
              : __('Enter the amount only after manually checking the original receipt.'),
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
            default: frm.doc.payment_reference || ai.detected_reference || '',
          },
          {
            fieldname: 'ai_override_reason',
            fieldtype: 'Small Text',
            label: __('Override / Exception Reason'),
            reqd: Boolean(data.ai_exception_reason_required),
            description: __(
              'Required when AI is unavailable or not confident enough, and whenever you change a confidently detected AI amount.'
            ),
          },
          {
            fieldname: 'remarks',
            fieldtype: 'Small Text',
            label: __('Review Remarks'),
          },
        ],
        primary_action_label: __('Verify & Start Accounting'),
        primary_action: async (values) => {
          const verifiedAmount = Number(values.verified_amount || 0);
          const aiAmount = data.ai_confident_detected_amount;
          const changedFromConfidentAi =
            aiAmount !== null &&
            aiAmount !== undefined &&
            aiAmount !== '' &&
            Math.abs(verifiedAmount - Number(aiAmount)) > 0.000001;
          const reasonRequired =
            Boolean(data.ai_exception_reason_required) || changedFromConfidentAi;
          const overrideReason = String(values.ai_override_reason || '').trim();

          if (reasonRequired && !overrideReason) {
            frappe.msgprint({
              title: __('Reason Required'),
              message: changedFromConfidentAi
                ? __('Enter an override reason because the verified amount differs from the confidently detected AI amount.')
                : __('Enter an exception reason because AI analysis is unavailable or not confident enough.'),
              indicator: 'orange',
            });
            return;
          }

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
                ai_override_reason: overrideReason,
                remarks: values.remarks,
              },
              freeze: true,
              freeze_message: __('Verifying receipt and queuing ERP accounting...'),
            });
            dialog.hide();
            await frm.reload_doc();
            frappe.show_alert({
              message: __('Receipt verified. ERP accounting has been queued.'),
              indicator: 'green',
            });
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
