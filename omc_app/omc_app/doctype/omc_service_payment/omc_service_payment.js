// Copyright (c) 2026, M.Shahwaiz.Ali and contributors
// For license information, please see license.txt

frappe.ui.form.on("OMC Service Payment", {
    refresh(frm) {
        frm.__omc_saved_payment_status = frm.doc.status || "";
    },

    async status(frm) {
        if (frm.is_new()) {
            return;
        }

        const previous_status = frm.__omc_saved_payment_status || "";
        const next_status = frm.doc.status || "";

        if (!next_status || next_status === previous_status) {
            return;
        }

        const review_statuses = [
            "Under Review",
            "Paid",
            "Rejected",
            "Cancelled",
        ];

        if (!review_statuses.includes(next_status)) {
            return;
        }

        try {
            await frappe.call({
                method: "omc_app.api.payment_mutation_guard.review_payment_receipt",
                args: {
                    payment_id: frm.doc.name,
                    status: next_status,
                    remarks: frm.doc.remarks || null,
                    payment_reference: frm.doc.payment_reference || null,
                },
                freeze: true,
                freeze_message:
                    next_status === "Paid"
                        ? __("Confirming payment and starting service processing...")
                        : __("Updating payment status..."),
            });

            await frm.reload_doc();
            frm.__omc_saved_payment_status = frm.doc.status || "";

            frappe.show_alert({
                message: __("Payment status updated successfully."),
                indicator: "green",
            });
        } catch (error) {
            await frm.reload_doc();
            frm.__omc_saved_payment_status = frm.doc.status || "";
            throw error;
        }
    },
});
