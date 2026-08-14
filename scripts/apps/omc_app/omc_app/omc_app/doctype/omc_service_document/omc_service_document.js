frappe.listview_settings['OMC Service Document'] = {
  get_indicator(doc) {
    const status = (doc.status || '').trim();
    const colors = {
      Pending: 'gray',
      Uploaded: 'orange',
      Approved: 'green',
      Rejected: 'red',
    };

    return [status || 'Pending', colors[status] || 'gray', `status,=,${status || 'Pending'}`];
  },
};

frappe.ui.form.on('OMC Service Document', {
  refresh(frm) {
    const status = (frm.doc.status || 'Pending').trim();
    const colors = {
      Pending: 'gray',
      Uploaded: 'orange',
      Approved: 'green',
      Rejected: 'red',
    };

    frm.dashboard.clear_headline();
    frm.dashboard.set_headline_alert(
      `<div class="indicator ${colors[status] || 'gray'}">${frappe.utils.escape_html(status)}</div>`,
    );
  },
});
