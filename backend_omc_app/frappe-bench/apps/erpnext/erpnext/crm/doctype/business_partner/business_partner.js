// Copyright (c) 2025, Frappe Technologies Pvt. Ltd. and contributors
// For license information, please see license.txt

frappe.ui.form.on('Business Partner', {
	// refresh: function(frm) {

	// }
});
frappe.ui.form.on('Business Partner', {
    refresh: function(frm) {
        if (!frm.doc.__islocal) {
            return;
        }

        frm.add_custom_button(__('Create User'), function() {
            if (!frm.doc.email || !frm.doc.full_name) {
                frappe.msgprint(__('Please enter Email and Full Name before creating the user.'));
                return;
            }

            frappe.call({
                method: 'erpnext.crm.doctype.business_partner.business_partner.create_user',
                args: {
                    email: frm.doc.email,
                    first_name: frm.doc.full_name // Using full_name directly as first_name
                },
                callback: function(response) {
                    if (response.message) {
                        frm.set_value('user_link', response.message);
                        frappe.msgprint(__('User Created Successfully!'));
                        frm.save();
                    }
                }
            });
        });
    }
});
