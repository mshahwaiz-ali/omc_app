// Copyright (c) 2026, M.Shahwaiz.Ali and contributors
// For license information, please see license.txt

frappe.ui.form.on("OMC Customer Profile", {
    refresh(frm) {
        const latitude = Number(frm.doc.work_latitude);
        const longitude = Number(frm.doc.work_longitude);

        const address = String(frm.doc.work_address || "").trim();

        const hasGeolocation = Boolean(frm.doc.work_geolocation);

        if (
            !address ||
            !hasGeolocation ||
            !Number.isFinite(latitude) ||
            !Number.isFinite(longitude)
        ) {
            return;
        }

        frm.add_custom_button(
            __("Open in Google Maps"),
            () => {
                const query = encodeURIComponent(
                    `${latitude},${longitude}`
                );
                window.open(
                    `https://www.google.com/maps/search/?api=1&query=${query}`,
                    "_blank",
                    "noopener,noreferrer"
                );
            },
            __("Address")
        );
    },
});
