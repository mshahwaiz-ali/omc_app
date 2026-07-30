frappe.ui.form.on("Sales Invoice", {
  refresh: function (frm) {
    // Only show on submitted invoices with outstanding amount
    if (frm.doc.docstatus === 1 && flt(frm.doc.outstanding_amount) > 0) {
      frm.add_custom_button(
        __("Pay Now (EPG)"),
        function () {
          frappe.confirm(
            __("Initiate EPG payment of {0} {1} for invoice {2}?", [
              frm.doc.currency,
              format_currency(frm.doc.outstanding_amount, frm.doc.currency),
              frm.doc.name,
            ]),
            function () {
              frappe.call({
                method: "lead_app.epg.initiate_payment",
                args: {
                  amount: frm.doc.outstanding_amount,
                  order_id: frm.doc.name,
                  order_name:
                    (frm.doc.customer_name || frm.doc.customer) +
                    " - " +
                    frm.doc.name,
                  reference_doctype: "Sales Invoice",
                  reference_name: frm.doc.name,
                },
                freeze: true,
                freeze_message: __("Initiating payment..."),
                callback: function (r) {
                  if (r.message && r.message.success) {
                    var payment_url =
                      r.message.payment_portal_url +
                      "?TransactionID=" +
                      r.message.transaction_id;

                    frappe.msgprint({
                      title: __("Redirecting to Payment Gateway"),
                      message: __(
                        "You will be redirected to the EPG payment portal in a new tab. " +
                          "Complete the payment there, then return to this page and refresh.",
                      ),
                      primary_action: {
                        label: __("Open Payment Page"),
                        action: function () {
                          window.open(payment_url, "_blank");
                          frappe.msg_dialog.hide();
                        },
                      },
                    });
                  }
                },
              });
            },
          );
        },
        __("Payment"),
      );
    }
  },
});
