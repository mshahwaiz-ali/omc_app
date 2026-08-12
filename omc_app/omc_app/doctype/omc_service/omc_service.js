frappe.ui.form.on("OMC Service", {
	refresh(frm) {
		render_service_icon_preview(frm);
	},

	icon(frm) {
		render_service_icon_preview(frm);
	},

	color_family(frm) {
		render_service_icon_preview(frm);
	},
});

function render_service_icon_preview(frm) {
	const field = frm.get_field("icon_preview");
	if (!field || !field.$wrapper) {
		return;
	}

	const icon_key = (frm.doc.icon || "general_service").trim();
	const accent = normalize_hex_color(frm.doc.color_family) || "#526173";

	const labels = {
		business_setup: "Business Setup",
		company_registration: "Company Registration",
		tax_filing: "Tax Filing",
		tax_registration: "Tax Registration",
		gst: "GST",
		accounting: "Accounting",
		audit: "Audit",
		documents: "Documents",
		certificate: "Certificate",
		legal: "Legal",
		visa: "Visa",
		payroll: "Payroll",
		payments: "Payments",
		compliance: "Compliance",
		consultation: "Consultation",
		licensing: "Licensing",
		trademark: "Trademark",
		bookkeeping: "Bookkeeping",
		banking: "Banking",
		general_service: "General Service",
	};

	const glyphs = {
		business_setup: "🏢",
		company_registration: "🏛️",
		tax_filing: "🧾",
		tax_registration: "🪪",
		gst: "📄",
		accounting: "🧮",
		audit: "✅",
		documents: "📑",
		certificate: "🎖️",
		legal: "⚖️",
		visa: "✈️",
		payroll: "👥",
		payments: "💳",
		compliance: "🛡️",
		consultation: "🎧",
		licensing: "🪪",
		trademark: "✔️",
		bookkeeping: "📚",
		banking: "🏦",
		general_service: "▦",
	};

	const label = labels[icon_key] || labels.general_service;
	const glyph = glyphs[icon_key] || glyphs.general_service;

	field.$wrapper.html(`
		<div style="display:flex;align-items:center;gap:14px;padding:14px 0 4px;">
			<div style="
				width:64px;
				height:64px;
				border-radius:18px;
				display:flex;
				align-items:center;
				justify-content:center;
				font-size:30px;
				background:${accent}18;
				border:1px solid ${accent}2A;
				color:${accent};
			">
				${glyph}
			</div>

			<div>
				<div style="font-size:14px;font-weight:600;color:var(--text-color);">
					${frappe.utils.escape_html(label)}
				</div>

				<div style="margin-top:3px;font-size:12px;color:var(--text-muted);">
					${frappe.utils.escape_html(icon_key)} · ${frappe.utils.escape_html(accent)}
				</div>
			</div>
		</div>
	`);
}

function normalize_hex_color(value) {
	const raw = (value || "").trim();

	if (/^#[0-9a-fA-F]{6}$/.test(raw)) {
		return raw;
	}

	if (/^[0-9a-fA-F]{6}$/.test(raw)) {
		return `#${raw}`;
	}

	return null;
}
