// Copyright (c) 2025, Frappe Technologies Pvt. Ltd. and contributors
// For license information, please see license.txt

frappe.ui.form.on('Tax Associates', {
    refresh: function(frm) {
        if (!frm.doc.__islocal) {
            return;
        }

        frm.add_custom_button(__('Create User'), function() {
            frappe.prompt([
                {
                    fieldname: 'email',
                    fieldtype: 'Data',
                    label: 'Email',
                    reqd: 1
                },
                {
                    fieldname: 'first_name',
                    fieldtype: 'Data',
                    label: 'First Name',
                    reqd: 1
                },
                {
                    fieldname: 'last_name',
                    fieldtype: 'Data',
                    label: 'Last Name'
                }
            ], function(values) {
                frappe.call({
                    method: 'erpnext.crm.doctype.freelancer.freelancer.create_user',
                    args: {
                        email: values.email,
                        first_name: values.first_name,
                        last_name: values.last_name
                    },
                    callback: function(response) {
                        if (response.message) {
                            frm.set_value('user_link', response.message);
                            frappe.msgprint(__('User Created Successfully!'));
                        }
                    }
                });
            }, __('Enter User Details'), __('Create'));
        });
    }
});
