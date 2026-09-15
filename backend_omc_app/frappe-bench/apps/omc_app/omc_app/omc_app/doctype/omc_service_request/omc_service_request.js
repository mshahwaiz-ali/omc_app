// Copyright (c) 2026, M.Shahwaiz.Ali and contributors
// For license information, please see license.txt


function omc_number(value) {
    const parsed = Number(value || 0);
    return Number.isFinite(parsed) ? parsed : 0;
}


async function omc_set_values(frm, values) {
    for (const [fieldname, value] of Object.entries(values)) {
        if (!frm.fields_dict[fieldname]) {
            continue;
        }

        if (frm.doc[fieldname] !== value) {
            await frm.set_value(fieldname, value);
        }
    }
}


function omc_desk_request_key() {
    const random = Math.random()
        .toString(36)
        .replace(/[^a-z0-9]/g, "")
        .padEnd(16, "0");

    return `desk-sr-${Date.now()}-${random}`;
}


function omc_configure_new_form(frm) {
    const editable_creation_fields = [
        "service",
        "customer_profile",
        "customer_consent_reference",
        "final_confirmation",
    ];

    editable_creation_fields.forEach((fieldname) => {
        if (frm.fields_dict[fieldname]) {
            frm.set_df_property(fieldname, "read_only", 0);
            frm.set_df_property(fieldname, "reqd", 1);
        }
    });

    [
        "discount_type",
        "discount_value",
        "discount_reason",
    ].forEach((fieldname) => {
        if (frm.fields_dict[fieldname]) {
            frm.set_df_property(fieldname, "read_only", 0);
            frm.set_df_property(fieldname, "reqd", 0);
        }
    });

    if (frm.fields_dict.discount_type) {
        frm.set_df_property(
            "discount_type",
            "description",
            __(
                "Optional customer discount. The server determines "
                + "whether approval is required."
            )
        );
    }

    if (frm.fields_dict.discount_reason) {
        frm.set_df_property(
            "discount_reason",
            "description",
            __(
                "Required whenever a non-zero discount is requested."
            )
        );
    }

    if (frm.fields_dict.proposed_final_price) {
        frm.set_df_property(
            "proposed_final_price",
            "description",
            __(
                "Preview only. Final pricing is recalculated "
                + "authoritatively by the server."
            )
        );
    }

    // These are derived from the selected authoritative customer/account.
    ["customer_account", "customer_name", "requested_by"].forEach(
        (fieldname) => {
            if (frm.fields_dict[fieldname]) {
                frm.set_df_property(fieldname, "read_only", 1);
            }
        }
    );

    // Request contact details are copied from the customer but may be
    // adjusted for this specific service request.
    ["contact_email", "contact_phone"].forEach((fieldname) => {
        if (frm.fields_dict[fieldname]) {
            frm.set_df_property(fieldname, "read_only", 0);
        }
    });

    if (frm.fields_dict.status) {
        frm.set_df_property("status", "read_only", 1);
    }

    const new_request_hidden_fields = [
        "request_state",
        "requested_for_customer",
        "customer_mode",
        "submission_mode",
        "submitted_by_user",
        "submitted_by_internal_user",
        "referral_owner",
        "referral_record",
        "referral_attribution",
        "created_on_behalf",
        "assigned_staff",
        "source_channel",
        "submission_integrity_section",
        "timeline_section",
        "erp_integration_section",
        "internal_section",
    ];

    new_request_hidden_fields.forEach((fieldname) => {
        if (frm.fields_dict[fieldname]) {
            frm.set_df_property(fieldname, "hidden", 1);
        }
    });

    if (frm.fields_dict.assisted_request_section) {
        frm.set_df_property(
            "assisted_request_section",
            "label",
            __("Desk Request Context")
        );
    }

    if (!frm.doc.requested_by) {
        frm.set_value("requested_by", frappe.session.user);
    }

    frm.set_df_property(
        "customer_consent_reference",
        "description",
        __(
            "Required for Desk creation. Enter the customer consent/evidence reference, such as a call, email, WhatsApp, ticket or other traceable reference."
        )
    );

    frm.set_df_property(
        "final_confirmation",
        "description",
        __(
            "Confirm that the selected customer, service and request details are correct."
        )
    );

    frm.set_query("customer_profile", () => ({
        query:
            "omc_app.api.assisted_service_policy.desk_customer_query",
    }));

    frm.set_query("service", () => ({
        filters: {
            is_active: 1,
            company: ["!=", ""],
        },
    }));

    frm.disable_save();

    frm.page.set_primary_action(
        __("Create Service Request"),
        () => omc_create_service_request(frm)
    );
}


async function omc_load_customer_preview(frm) {
    if (!frm.is_new()) {
        return;
    }

    if (!frm.doc.customer_profile) {
        await omc_set_values(frm, {
            customer_account: "",
            customer_name: "",
            contact_email: "",
            contact_phone: "",
            erp_customer: "",
            requested_for_customer: "",
        });
        return;
    }

    const profile_response = await frappe.db.get_value(
        "OMC Customer Profile",
        frm.doc.customer_profile,
        [
            "full_name",
            "email",
            "phone",
            "user",
            "linked_app_user",
        ]
    );

    const profile = profile_response.message || {};

    const account_response = await frappe.db.get_value(
        "OMC Customer Account",
        {
            legacy_customer_profile:
                frm.doc.customer_profile,
        },
        [
            "name",
            "user",
            "erp_customer",
            "identity_proof_status",
            "account_link_status",
            "service_access_status",
        ]
    );

    const account = account_response.message || {};

    if (!account.name) {
        await omc_set_values(frm, {
            customer_account: "",
            erp_customer: "",
        });

        frappe.msgprint({
            title: __("Customer Not Available"),
            message: __(
                "The selected customer does not have an approved OMC Customer Account."
            ),
            indicator: "red",
        });

        await frm.set_value("customer_profile", "");
        return;
    }

    const approved =
        account.identity_proof_status === "Verified" &&
        account.account_link_status === "Linked" &&
        account.service_access_status === "Approved";

    if (!approved) {
        await frm.set_value("customer_profile", "");

        frappe.msgprint({
            title: __("Customer Not Approved"),
            message: __(
                "Only Verified, Linked and Approved customers can be used for a Desk service request."
            ),
            indicator: "red",
        });

        return;
    }

    await omc_set_values(frm, {
        customer_name: profile.full_name || "",
        contact_email: profile.email || "",
        contact_phone: profile.phone || "",
        customer_account: account.name || "",
        erp_customer: account.erp_customer || "",
        requested_for_customer:
            profile.linked_app_user ||
            profile.user ||
            account.user ||
            "",
        requested_by: frappe.session.user,
        customer_mode: "Existing Customer",
        submission_mode: "Admin on Behalf",
        submitted_by_user: frappe.session.user,
        submitted_by_internal_user:
            frappe.session.user,
        created_on_behalf: 1,
        source_channel: "Desk",
    });
}


function omc_discount_preview_values(frm) {
    const originalPrice = omc_number(
        frm.doc.original_price
    );

    const discountType = String(
        frm.doc.discount_type || ""
    ).trim();

    const discountValue = omc_number(
        frm.doc.discount_value
    );

    let discountAmount = 0;

    if (
        discountValue > 0
        && discountType === "Percentage"
    ) {
        discountAmount =
            originalPrice * discountValue / 100;
    } else if (
        discountValue > 0
        && discountType === "Fixed Amount"
    ) {
        discountAmount = discountValue;
    }

    return {
        originalPrice,
        discountType,
        discountValue,
        discountAmount,
        proposedFinalPrice: Math.max(
            originalPrice - discountAmount,
            0
        ),
    };
}


async function omc_refresh_discount_preview(frm) {
    if (!frm.is_new()) {
        return;
    }

    const preview =
        omc_discount_preview_values(frm);

    await omc_set_values(frm, {
        discount_amount:
            preview.discountAmount,
        proposed_final_price:
            preview.proposedFinalPrice,
        discount_status:
            preview.discountAmount > 0
                ? "Pending Approval"
                : "None",
    });
}


function omc_validate_desk_discount(frm) {
    const preview =
        omc_discount_preview_values(frm);

    if (preview.discountValue < 0) {
        frappe.throw(
            __("Discount value cannot be negative.")
        );
    }

    if (preview.discountValue <= 0) {
        return {
            discountType: "",
            discountValue: 0,
            discountReason: "",
        };
    }

    if (
        ![
            "Percentage",
            "Fixed Amount",
        ].includes(preview.discountType)
    ) {
        frappe.throw(
            __(
                "Choose Percentage or Fixed Amount "
                + "for the discount type."
            )
        );
    }

    if (
        preview.discountType === "Percentage"
        && preview.discountValue > 100
    ) {
        frappe.throw(
            __(
                "Percentage discount cannot exceed 100%."
            )
        );
    }

    if (
        preview.discountType === "Fixed Amount"
        && preview.discountValue
            > preview.originalPrice
    ) {
        frappe.throw(
            __(
                "Fixed discount cannot exceed "
                + "the original service price."
            )
        );
    }

    const reason = String(
        frm.doc.discount_reason || ""
    ).trim();

    if (!reason) {
        frappe.throw(
            __(
                "Discount Reason is required "
                + "when a discount is applied."
            )
        );
    }

    return {
        discountType: preview.discountType,
        discountValue: preview.discountValue,
        discountReason: reason,
    };
}


async function omc_load_service_preview(frm) {
    if (!frm.is_new() || !frm.doc.service) {
        return;
    }

    const response = await frappe.db.get_value(
        "OMC Service",
        frm.doc.service,
        [
            "title",
            "is_active",
            "company",
            "base_price",
            "currency",
            "service_version",
            "pricing_version",
            "tax_policy",
            "tax_rate",
            "activation_policy",
        ]
    );

    const service = response.message || {};

    if (!service.is_active) {
        frappe.msgprint({
            title: __("Service Not Available"),
            message: __("The selected service is inactive."),
            indicator: "red",
        });

        await frm.set_value("service", "");
        return;
    }

    if (!service.company) {
        frappe.msgprint({
            title: __("Service Configuration Required"),
            message: __(
                "The selected service does not have an authoritative Company configured."
            ),
            indicator: "red",
        });

        await frm.set_value("service", "");
        return;
    }

    const originalPrice = omc_number(
        service.base_price
    );
    const taxRate = omc_number(service.tax_rate);

    let taxAmount = 0;
    let payableAmount = originalPrice;

    if (service.tax_policy === "Tax Exclusive") {
        taxAmount =
            originalPrice * taxRate / 100;

        payableAmount =
            originalPrice + taxAmount;
    } else if (
        service.tax_policy === "Tax Included" &&
        taxRate
    ) {
        taxAmount =
            originalPrice *
            taxRate /
            (100 + taxRate);
    }

    await omc_set_values(frm, {
        service_title: service.title || "",
        title:
            service.title ||
            frm.doc.title ||
            "Service Request",

        original_price: originalPrice,
        pricing_currency:
            service.currency || "PKR",
        company_snapshot:
            service.company || "",

        discount_type: "",
        discount_value: 0,
        discount_amount: 0,
        proposed_final_price: originalPrice,
        final_price: originalPrice,
        discount_status: "None",

        service_version_snapshot:
            service.service_version || 1,
        pricing_version_snapshot:
            service.pricing_version || "",

        payment_policy_snapshot:
            service.activation_policy ||
            "Full Settlement",

        tax_policy_snapshot:
            service.tax_policy || "No Tax",
        tax_rate_snapshot: taxRate,
        tax_amount: taxAmount,
        payable_amount: payableAmount,
    });
}


async function omc_create_service_request(frm) {
    if (frm.__omc_creating_request) {
        return;
    }

    const required = [
        ["customer_profile", __("Customer Profile")],
        [
            "customer_consent_reference",
            __("Customer Consent Reference"),
        ],
        ["service", __("Service")],
    ];

    for (const [fieldname, label] of required) {
        const value = String(
            frm.doc[fieldname] || ""
        ).trim();

        if (!value) {
            frappe.msgprint(
                __("{0} is required.", [label])
            );

            frm.scroll_to_field(fieldname);
            return;
        }
    }

    if (!frm.doc.final_confirmation) {
        frappe.msgprint(
            __("Final Confirmation is required.")
        );

        frm.scroll_to_field("final_confirmation");
        return;
    }

    const discount =
        omc_validate_desk_discount(frm);

    frm.__omc_creating_request = true;

    try {
        // Refresh the service versions immediately before creation.
        const service_response =
            await frappe.db.get_value(
                "OMC Service",
                frm.doc.service,
                [
                    "service_version",
                    "pricing_version",
                    "is_active",
                    "company",
                ]
            );

        const service =
            service_response.message || {};

        if (!service.is_active) {
            frappe.throw(
                __("The selected service is inactive.")
            );
        }

        if (!service.company) {
            frappe.throw(
                __(
                    "The selected service does not have an authoritative Company configured."
                )
            );
        }

        const idempotencyKey =
            frm.__omc_idempotency_key ||
            (frm.__omc_idempotency_key =
                omc_desk_request_key());

        const response = await frappe.call({
            method:
                "omc_app.api.assisted_service_policy.create_request",

            args: {
                customer_mode:
                    "Existing Customer",

                customer_profile:
                    frm.doc.customer_profile,

                customer_consent_reference:
                    frm.doc
                        .customer_consent_reference,

                service_id:
                    frm.doc.service,

                service_version:
                    service.service_version,

                pricing_version:
                    service.pricing_version || "",

                title:
                    frm.doc.title || "",

                description:
                    frm.doc.description || "",

                priority:
                    frm.doc.priority || "Medium",

                contact_email:
                    frm.doc.contact_email || "",

                contact_phone:
                    frm.doc.contact_phone || "",

                discount_type:
                    discount.discountType,

                discount_value:
                    discount.discountValue,

                discount_reason:
                    discount.discountReason,

                final_confirmation: 1,

                source_channel: "Desk",

                idempotency_key:
                    idempotencyKey,
            },

            freeze: true,
            freeze_message: __(
                "Creating service request..."
            ),
        });

        const result = response.message || {};

        const requestName =
            result.service_request ||
            result.request_id ||
            result.name ||
            (result.active_request || {}).name;

        if (!requestName) {
            frappe.throw(
                __(
                    "Service request reference was not returned."
                )
            );
        }

        frappe.show_alert({
            message: result.duplicate
                ? __(
                      "Existing active service request opened."
                  )
                : __(
                      "Service request created successfully."
                  ),
            indicator:
                result.duplicate
                    ? "orange"
                    : "green",
        });

        // The authoritative document was created through the guarded
        // backend API. Discard the temporary unsaved Desk shell before
        // routing to the real request.
        frm.doc.__unsaved = 0;
        frm.__omc_idempotency_key = null;

        frappe.set_route(
            "Form",
            "OMC Service Request",
            requestName
        );
    } finally {
        frm.__omc_creating_request = false;
    }
}


function omc_document_identity(value) {
    return String(value || "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ");
}

function omc_document_matches_requirement(document, requirement) {
    const documentKey = omc_document_identity(
        document.document_key
    );
    const requirementKey = omc_document_identity(
        requirement.document_key
    );

    if (documentKey && requirementKey) {
        return documentKey === requirementKey;
    }

    return (
        omc_document_identity(document.document_title)
            === omc_document_identity(requirement.document_title)
        && omc_document_identity(document.document_type)
            === omc_document_identity(requirement.document_type)
    );
}

function omc_document_requirement_is_available(
    requirement,
    documents
) {
    const activeStatuses = new Set([
        "Pending",
        "Uploaded",
        "Approved",
    ]);

    return !(documents || []).some((document) => {
        if (!omc_document_matches_requirement(
            document,
            requirement
        )) {
            return false;
        }

        const status = String(
            document.status || ""
        ).trim();

        const source = String(
            document.source || ""
        ).trim();

        // Reused approved evidence may be intentionally replaced
        // by a fresh customer-provided upload.
        if (source === "Existing Document") {
            return false;
        }

        return activeStatuses.has(status);
    });
}

function omc_document_upload_key(frm) {
    const randomPart = Math.random()
        .toString(36)
        .slice(2, 14);

    return [
        "desk-doc",
        frm.doc.name,
        Date.now(),
        randomPart,
    ].join(":");
}

function omc_upload_required_document_file(
    frm,
    requirement,
    remarks
) {
    const idempotencyKey = omc_document_upload_key(frm);

    new frappe.ui.FileUploader({
        folder: "Home/Attachments",
        allow_multiple: false,
        make_attachments_public: 0,
        disable_file_browser: true,
        dialog_title: __(
            "Upload {0}",
            [requirement.document_title]
        ),
        upload_notes: __(
            "Allowed files: PDF, JPG, JPEG, PNG, DOC and DOCX. "
            + "Maximum file size: 10 MB."
        ),
        restrictions: {
            allowed_file_types: [
                ".pdf",
                ".jpg",
                ".jpeg",
                ".png",
                ".doc",
                ".docx",
            ],
        },
        on_success(fileDoc) {
            const fileUrl = (
                fileDoc.file_url
                || fileDoc.file_name
                || ""
            );

            if (!fileUrl) {
                frappe.msgprint({
                    title: __("Document Upload"),
                    message: __(
                        "The uploaded File record did not return a file URL."
                    ),
                    indicator: "red",
                });
                return;
            }

            frappe.call({
                method:
                    "omc_app.api.document_upload"
                    + ".desk_upload_service_document",
                args: {
                    service_request: frm.doc.name,
                    document_key:
                        requirement.document_key || "",
                    document_title:
                        requirement.document_title || "",
                    document_type:
                        requirement.document_type || "General",
                    attachment: fileUrl,
                    remarks: remarks || "",
                    idempotency_key: idempotencyKey,
                },
                freeze: true,
                freeze_message: __(
                    "Registering customer document..."
                ),
            }).then((response) => {
                const result = response.message || {};
                const document = result.document || {};

                frappe.show_alert({
                    message: __(
                        "{0} uploaded successfully",
                        [
                            document.document_title
                            || requirement.document_title,
                        ]
                    ),
                    indicator: "green",
                });

                if (result.payment_id) {
                    frappe.show_alert({
                        message: __(
                            "Required documents are satisfied. "
                            + "The payment workflow is available."
                        ),
                        indicator: "green",
                    }, 7);
                }

                frm.reload_doc();
            });
        },
    });
}

async function omc_open_required_document_upload(frm) {
    const response = await frappe.call({
        method:
            "omc_app.api.document_upload"
            + ".get_desk_upload_context",
        args: {
            service_request: frm.doc.name,
        },
        freeze: true,
        freeze_message: __(
            "Loading document requirements..."
        ),
    });

    const context = response.message || {};

    if (
        frm.is_new()
        || context.service_request !== frm.doc.name
    ) {
        return;
    }

    const documents = context.documents || [];
    const requirements = (
        context.requirements || []
    ).filter((requirement) =>
        omc_document_requirement_is_available(
            requirement,
            documents
        )
    );

    if (!requirements.length) {
        frappe.msgprint({
            title: __("Required Documents"),
            message: __(
                "There is no required document currently available "
                + "for a new upload. Existing active submissions may "
                + "already satisfy the requirements or require review."
            ),
            indicator: "blue",
        });
        return;
    }

    const requirementByOption = {};
    const options = requirements.map(
        (requirement, index) => {
            const title = (
                requirement.document_title
                || requirement.document_key
                || __("Document")
            );

            const type = (
                requirement.document_type
                || __("General")
            );

            const option = (
                `${index + 1}. ${title} — ${type}`
            );

            requirementByOption[option] = requirement;
            return option;
        }
    );

    const dialog = new frappe.ui.Dialog({
        title: __("Upload Required Document"),
        fields: [
            {
                fieldname: "requirement",
                fieldtype: "Select",
                label: __("Required Document"),
                options,
                reqd: 1,
            },
            {
                fieldname: "remarks",
                fieldtype: "Small Text",
                label: __("Remarks"),
                description: __(
                    "Optional note about the document provided "
                    + "by the customer."
                ),
            },
            {
                fieldname: "upload_policy",
                fieldtype: "HTML",
                options: `
                    <div class="text-muted small">
                        ${__(
                            "Files are registered through the guarded "
                            + "document workflow and are subject to "
                            + "type, size and security validation."
                        )}
                    </div>
                `,
            },
        ],
        primary_action_label: __("Choose File"),
        primary_action(values) {
            const requirement = requirementByOption[
                values.requirement
            ];

            if (!requirement) {
                frappe.msgprint(
                    __("Select a required document.")
                );
                return;
            }

            dialog.hide();

            omc_upload_required_document_file(
                frm,
                requirement,
                values.remarks || ""
            );
        },
    });

    dialog.show();
}


function omc_open_request_documents(frm) {
    frappe.route_options = {
        service_request: frm.doc.name,
    };

    frappe.set_route(
        "List",
        "OMC Service Document"
    );
}


function omc_open_request_payments(frm) {
    frappe.route_options = {
        service_request: frm.doc.name,
    };

    frappe.set_route(
        "List",
        "OMC Service Payment"
    );
}


function omc_payment_amount_label(currency, amount) {
    const value = omc_number(amount);

    return `${currency || "PKR"} ${value.toLocaleString(
        undefined,
        {
            minimumFractionDigits: 0,
            maximumFractionDigits: 6,
        }
    )}`;
}


async function omc_get_request_accounting_summary(frm) {
    const response = await frappe.call({
        method: "omc_app.api.payment_installments.get_accounting_summary",
        args: {
            service_request: frm.doc.name,
        },
    });

    return response.message || {};
}


async function omc_open_remaining_payment(frm, summary) {
    const amountLabel = omc_payment_amount_label(
        summary.currency,
        summary.maximum_payment_amount
    );

    frappe.confirm(
        __(
            "Open the next payment installment for {0}? "
            + "The server will recalculate the authoritative ERP outstanding "
            + "balance before creating the payment.",
            [amountLabel]
        ),
        async () => {
            const response = await frappe.call({
                method: "omc_app.api.payment_installments.create_installment",
                args: {
                    service_request: frm.doc.name,
                },
                freeze: true,
                freeze_message: __("Opening payment installment..."),
            });

            const result = response.message || {};
            const paymentName = result.payment;

            if (!paymentName) {
                frappe.msgprint({
                    title: __("Payment"),
                    message: __(
                        "The payment workflow did not return a payment record."
                    ),
                    indicator: "orange",
                });
                return;
            }

            frappe.show_alert({
                message: result.created
                    ? __("Payment installment opened")
                    : __("Existing open payment found"),
                indicator: "green",
            });

            frappe.set_route(
                "Form",
                "OMC Service Payment",
                paymentName
            );
        }
    );
}


async function omc_add_request_payment_action(frm) {
    try {
        const summary = await omc_get_request_accounting_summary(frm);

        // Ignore a stale async response if the user navigated elsewhere.
        if (
            frm.is_new()
            || summary.request !== frm.doc.name
        ) {
            return;
        }

        if (summary.open_payment) {
            frm.add_custom_button(
                __("Open Current Payment"),
                () => frappe.set_route(
                    "Form",
                    "OMC Service Payment",
                    summary.open_payment
                ),
                __("Operations")
            );
            return;
        }

        if (!summary.can_make_payment) {
            return;
        }

        const amountLabel = omc_payment_amount_label(
            summary.currency,
            summary.maximum_payment_amount
        );

        frm.add_custom_button(
            __("Open Remaining Payment ({0})", [amountLabel]),
            () => omc_open_remaining_payment(frm, summary),
            __("Operations")
        );
    } catch (error) {
        console.warn(
            "Unable to load OMC payment action",
            error
        );
    }
}


async function omc_reuse_approved_documents(frm) {
    frappe.confirm(
        __(
            "Reuse any eligible approved documents already on file "
            + "for this customer and service?"
        ),
        async () => {
            const response = await frappe.call({
                method:
                    "omc_app.api.document_reuse"
                    + ".reuse_existing_documents",
                type: "POST",
                args: {
                    service_request: frm.doc.name,
                },
                freeze: true,
                freeze_message: __(
                    "Checking approved customer documents..."
                ),
            });

            const result = response.message || {};
            const reused = Number(result.reused || 0);
            const skipped = result.skipped || [];

            if (reused > 0) {
                frappe.show_alert({
                    message: __(
                        "{0} approved document(s) reused",
                        [reused]
                    ),
                    indicator: "green",
                }, 7);

                if (result.payment_id) {
                    frappe.show_alert({
                        message: __(
                            "Document requirements are satisfied. "
                            + "The payment workflow is available."
                        ),
                        indicator: "green",
                    }, 7);
                }
            } else {
                const detail = skipped.length
                    ? `<br><br>${skipped
                        .map((item) =>
                            frappe.utils.escape_html(item)
                        )
                        .join("<br>")}`
                    : "";

                frappe.msgprint({
                    title: __("Reuse Approved Documents"),
                    message:
                        __(
                            "No eligible approved documents "
                            + "were available for reuse."
                        )
                        + detail,
                    indicator: "blue",
                });
            }

            await frm.reload_doc();
        }
    );
}


async function omc_submit_discount_review(
    frm,
    decision,
    reason = ""
) {
    const response = await frappe.call({
        method:
            "omc_app.api.admin_control.review_discount",
        type: "POST",
        args: {
            service_request: frm.doc.name,
            decision,
            reason,
        },
        freeze: true,
        freeze_message:
            decision === "approve"
                ? __("Approving discount...")
                : __("Rejecting discount..."),
    });

    const result = response.message || {};

    frappe.show_alert({
        message:
            decision === "approve"
                ? __("Discount approved")
                : __("Discount rejected"),
        indicator:
            decision === "approve"
                ? "green"
                : "orange",
    });

    if (result.payment_id) {
        frappe.show_alert({
            message: __(
                "Pricing finalized and payment workflow opened."
            ),
            indicator: "green",
        }, 7);
    }

    await frm.reload_doc();
}


function omc_approve_request_discount(frm) {
    frappe.confirm(
        __(
            "Approve this discount and finalize "
            + "the authoritative request pricing?"
        ),
        () => omc_submit_discount_review(
            frm,
            "approve"
        )
    );
}


function omc_reject_request_discount(frm) {
    frappe.prompt(
        [
            {
                fieldname: "reason",
                fieldtype: "Small Text",
                label: __("Rejection Reason"),
                reqd: 1,
            },
        ],
        (values) => omc_submit_discount_review(
            frm,
            "reject",
            values.reason || ""
        ),
        __("Reject Discount"),
        __("Reject")
    );
}


async function omc_add_request_discount_actions(frm) {
    if (
        String(frm.doc.discount_status || "").trim()
        !== "Pending Approval"
    ) {
        return;
    }

    try {
        const response = await frappe.call({
            method:
                "omc_app.api.admin_control"
                + ".get_case_admin_options",
            args: {
                service_request: frm.doc.name,
            },
        });

        const options = response.message || {};

        if (
            frm.is_new()
            || options.service_request !== frm.doc.name
            || String(
                frm.doc.discount_status || ""
            ).trim() !== "Pending Approval"
        ) {
            return;
        }

        const capabilities =
            options.capabilities || {};

        if (!capabilities.can_review_discount) {
            return;
        }

        frm.add_custom_button(
            __("Approve Discount"),
            () => omc_approve_request_discount(frm),
            __("Operations")
        );

        frm.add_custom_button(
            __("Reject Discount"),
            () => omc_reject_request_discount(frm),
            __("Operations")
        );
    } catch (error) {
        console.warn(
            "Unable to load OMC discount actions",
            error
        );
    }
}


function omc_open_erp_task(taskName) {
    const cleanTask = String(taskName || "").trim();

    if (!cleanTask) {
        frappe.msgprint({
            title: __("ERP Task"),
            message: __(
                "No authoritative ERP Task is linked to this request."
            ),
            indicator: "orange",
        });
        return;
    }

    frappe.set_route("Form", "Task", cleanTask);
}


function omc_reassign_service_request(frm, options) {
    const candidates =
        options.assignment_candidates || [];

    if (!candidates.length) {
        frappe.msgprint({
            title: __("Reassign Service Request"),
            message: __(
                "No eligible active staff members are available "
                + "for this service request."
            ),
            indicator: "orange",
        });
        return;
    }

    const candidateIds = candidates
        .map((row) => String(row.user_id || "").trim())
        .filter(Boolean);

    const current = String(
        options.assigned_staff || frm.doc.assigned_staff || ""
    ).trim();

    const defaultValue = candidateIds.includes(current)
        ? current
        : candidateIds[0];

    const candidateSummary = candidates
        .map((row) => {
            const user = String(row.user_id || "").trim();
            const name = String(row.full_name || "").trim();

            if (!user) {
                return "";
            }

            return name && name !== user
                ? `${frappe.utils.escape_html(name)} — ${
                    frappe.utils.escape_html(user)
                }`
                : frappe.utils.escape_html(user);
        })
        .filter(Boolean)
        .join("<br>");

    const dialog = new frappe.ui.Dialog({
        title: __("Reassign Service Request"),
        fields: [
            {
                fieldname: "assigned_staff",
                fieldtype: "Select",
                label: __("Assign To"),
                options: candidateIds,
                default: defaultValue,
                reqd: 1,
            },
            {
                fieldname: "candidate_summary",
                fieldtype: "HTML",
                options:
                    `<div class="text-muted small">${candidateSummary}</div>`,
            },
            {
                fieldname: "reason",
                fieldtype: "Small Text",
                label: __("Reason"),
                description: __(
                    "Optional operational reason recorded in the request audit trail."
                ),
            },
        ],
        primary_action_label: __("Reassign"),
        primary_action: async (values) => {
            dialog.disable_primary_action();

            try {
                await frappe.call({
                    method:
                        "omc_app.api.admin_control"
                        + ".reassign_service_request",
                    type: "POST",
                    args: {
                        service_request: frm.doc.name,
                        assigned_staff:
                            values.assigned_staff,
                        reason:
                            values.reason || "",
                    },
                    freeze: true,
                    freeze_message: __(
                        "Reassigning service request..."
                    ),
                });

                dialog.hide();

                frappe.show_alert({
                    message: __(
                        "Service request reassigned successfully."
                    ),
                    indicator: "green",
                });

                await frm.reload_doc();
            } finally {
                dialog.enable_primary_action();
            }
        },
    });

    dialog.show();
}


function omc_retry_erp_sync(frm) {
    frappe.confirm(
        __(
            "Retry the guarded ERP activation/synchronization "
            + "workflow for this request?"
        ),
        async () => {
            const response = await frappe.call({
                method:
                    "omc_app.api.admin_control"
                    + ".retry_service_sync",
                type: "POST",
                args: {
                    service_request: frm.doc.name,
                },
                freeze: true,
                freeze_message: __(
                    "Requesting ERP synchronization recovery..."
                ),
            });

            const result = response.message || {};

            frappe.show_alert({
                message: result.recovered
                    ? __(
                        "ERP synchronization recovery was requested."
                    )
                    : __(
                        "ERP synchronization state was refreshed."
                    ),
                indicator: "green",
            }, 7);

            await frm.reload_doc();
        }
    );
}


async function omc_add_request_erp_actions(frm) {
    if (frm.is_new()) {
        return;
    }

    try {
        const response = await frappe.call({
            method:
                "omc_app.api.admin_control"
                + ".get_case_admin_options",
            args: {
                service_request: frm.doc.name,
            },
        });

        const options = response.message || {};

        if (
            frm.is_new()
            || options.service_request !== frm.doc.name
        ) {
            return;
        }

        const capabilities =
            options.capabilities || {};

        const requestState = String(
            frm.doc.request_state || ""
        ).trim();

        const requestStatus = String(
            frm.doc.status || ""
        ).trim();

        const erpSyncStatus = String(
            options.erp_sync_status || ""
        ).trim();

        const terminal = [
            "Historical",
            "Expired",
            "Cancelled",
        ].includes(requestState)
            || [
                "Completed",
                "Cancelled",
            ].includes(requestStatus);

        const taskName = String(
            options.erp_task || frm.doc.erp_task || ""
        ).trim();

        if (taskName) {
            frm.add_custom_button(
                __("Open ERP Task"),
                () => omc_open_erp_task(taskName),
                __("Operations")
            );
        }

        if (
            capabilities.can_reassign
            && !terminal
        ) {
            frm.add_custom_button(
                __("Reassign Service Request"),
                () => omc_reassign_service_request(
                    frm,
                    options
                ),
                __("Operations")
            );
        }

        const retryableSync =
            requestState === "Activation Failed"
            || [
                "Pending Configuration",
                "Repair Required",
                "Failed",
            ].includes(erpSyncStatus)
            || Boolean(
                String(
                    options.erp_retry_exhausted_at || ""
                ).trim()
            );

        if (
            capabilities.can_retry_sync
            && !terminal
            && retryableSync
        ) {
            frm.add_custom_button(
                __("Retry ERP Sync"),
                () => omc_retry_erp_sync(frm),
                __("Operations")
            );
        }
    } catch (error) {
        console.warn(
            "Unable to load OMC ERP operations",
            error
        );
    }
}


function omc_add_request_operation_buttons(frm) {
    frm.add_custom_button(
        __("Documents"),
        () => omc_open_request_documents(frm),
        __("Operations")
    );

    frm.add_custom_button(
        __("Payments"),
        () => omc_open_request_payments(frm),
        __("Operations")
    );

    const documentActionsBlocked = [
        "Completed",
        "Cancelled",
    ].includes(String(frm.doc.status || "").trim())
        || [
            "Historical",
            "Expired",
            "Cancelled",
        ].includes(
            String(frm.doc.request_state || "").trim()
        );

    if (!documentActionsBlocked) {
        frm.add_custom_button(
            __("Reuse Approved Documents"),
            () => omc_reuse_approved_documents(frm),
            __("Operations")
        );
    }

    void omc_add_request_erp_actions(frm);
    void omc_add_request_discount_actions(frm);
    void omc_add_request_payment_action(frm);
}


frappe.ui.form.on("OMC Service Request", {
    setup(frm) {
        frm.set_query("customer_profile", () => ({
            query:
                "omc_app.api.assisted_service_policy.desk_customer_query",
        }));

        frm.set_query("service", () => ({
            filters: {
                is_active: 1,
                company: ["!=", ""],
            },
        }));
    },

    refresh(frm) {
        if (frm.is_new()) {
            omc_configure_new_form(frm);
            return;
        }

        omc_add_request_operation_buttons(frm);

        // Restore the normal full record view for saved requests.
        ["service", "customer_profile", "customer_consent_reference", "final_confirmation"].forEach(
            (fieldname) => {
                if (frm.fields_dict[fieldname]) {
                    frm.set_df_property(fieldname, "read_only", 1);
                }
            }
        );

        const saved_request_visible_fields = [
            "request_state",
            "requested_for_customer",
            "customer_mode",
            "submission_mode",
            "submitted_by_user",
            "submitted_by_internal_user",
            "referral_owner",
            "referral_record",
            "referral_attribution",
            "created_on_behalf",
            "assigned_staff",
            "source_channel",
            "submission_integrity_section",
            "timeline_section",
            "erp_integration_section",
            "internal_section",
        ];

        saved_request_visible_fields.forEach((fieldname) => {
            if (frm.fields_dict[fieldname]) {
                frm.set_df_property(fieldname, "hidden", 0);
            }
        });

        if (frm.fields_dict.assisted_request_section) {
            frm.set_df_property(
                "assisted_request_section",
                "label",
                __("Assisted Request Context")
            );
        }
    },

    async customer_profile(frm) {
        await omc_load_customer_preview(frm);
    },

    async service(frm) {
        await omc_load_service_preview(frm);
    },

    async discount_type(frm) {
        await omc_refresh_discount_preview(frm);
    },

    async discount_value(frm) {
        await omc_refresh_discount_preview(frm);
    },
});
