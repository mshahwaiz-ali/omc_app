const OMC_SERVICE_DOCUMENT_STATUS_COLORS = {
  Pending: 'gray',
  Uploaded: 'orange',
  Approved: 'green',
  Rejected: 'red',
};

function omc_service_document_status(doc) {
  return (doc.status || 'Pending').trim();
}

function omc_lock_service_document_form(frm) {
  const workflowFields = [
    'service_request',
    'customer_profile',
    'document_key',
    'document_title',
    'document_type',
    'attachment',
    'quarantine_status',
    'status',
    'source',
    'source_document',
    'visible_to_customer',
    'is_archived',
    'archived_on',
    'archive_reason',
    'uploaded_by',
    'uploaded_on',
    'reviewed_by',
    'reviewed_on',
    'review_remarks',
    'remarks',
  ];

  workflowFields.forEach((fieldname) => {
    if (frm.fields_dict[fieldname]) {
      frm.set_df_property(
        fieldname,
        'read_only',
        1
      );
    }
  });

  if (!frm.is_new()) {
    return;
  }

  frm.disable_save();

  frm.dashboard.set_headline_alert(
    `<div class="indicator orange">${
      frappe.utils.escape_html(
        __(
          'Service documents must be created from '
          + 'the Service Request guarded workflow.'
        )
      )
    }</div>`
  );

  frm.page.set_primary_action(
    __('Go to Service Requests'),
    () => frappe.set_route(
      'List',
      'OMC Service Request'
    )
  );
}

frappe.listview_settings['OMC Service Document'] = {
  get_indicator(doc) {
    const status = omc_service_document_status(doc);

    return [
      status,
      OMC_SERVICE_DOCUMENT_STATUS_COLORS[status] || 'gray',
      `status,=,${status}`,
    ];
  },
};

frappe.ui.form.on('OMC Service Document', {
  refresh(frm) {
    const status = omc_service_document_status(frm.doc);

    frm.dashboard.clear_headline();

    if (!frm.is_new()) {
      frm.dashboard.set_headline_alert(
        `<div class="indicator ${
          OMC_SERVICE_DOCUMENT_STATUS_COLORS[status] || 'gray'
        }">${
          frappe.utils.escape_html(status)
        }</div>`
      );
    }

    omc_lock_service_document_form(frm);
  },
});
