import frappe


FILER_STATUSES = ("Active Filer", "Late Filer", "Non-Filer")
INCOME_TYPES = ("Business", "Rental")

NON_SALARIED_SCHEDULES = {
    "2020-21": [
        (0, 600000, 0, 0, 0),
        (600000, 800000, 0, 5, 600000),
        (800000, 1200000, 10000, 12.5, 800000),
        (1200000, 2400000, 60000, 17.5, 1200000),
        (2400000, 3000000, 270000, 22.5, 2400000),
        (3000000, 4000000, 405000, 27.5, 3000000),
        (4000000, 6000000, 680000, 32.5, 4000000),
        (6000000, None, 1330000, 35, 6000000),
    ],
    "2021-22": [
        (0, 600000, 0, 0, 0),
        (600000, 800000, 0, 5, 600000),
        (800000, 1200000, 10000, 12.5, 800000),
        (1200000, 2400000, 60000, 17.5, 1200000),
        (2400000, 3000000, 270000, 22.5, 2400000),
        (3000000, 4000000, 405000, 27.5, 3000000),
        (4000000, 6000000, 680000, 32.5, 4000000),
        (6000000, None, 1330000, 35, 6000000),
    ],
    "2022-23": [
        (0, 600000, 0, 0, 0),
        (600000, 800000, 0, 7.5, 600000),
        (800000, 1200000, 15000, 15, 800000),
        (1200000, 2400000, 75000, 20, 1200000),
        (2400000, 3000000, 315000, 25, 2400000),
        (3000000, 4000000, 465000, 30, 3000000),
        (4000000, 6000000, 765000, 32.5, 4000000),
        (6000000, None, 1415000, 35, 6000000),
    ],
    "2023-24": [
        (0, 600000, 0, 0, 0),
        (600000, 800000, 0, 7.5, 600000),
        (800000, 1200000, 15000, 15, 800000),
        (1200000, 2400000, 75000, 20, 1200000),
        (2400000, 3000000, 315000, 25, 2400000),
        (3000000, 4000000, 465000, 30, 3000000),
        (4000000, 6000000, 765000, 32.5, 4000000),
        (6000000, None, 1415000, 35, 6000000),
    ],
    "2024-25": [
        (0, 600000, 0, 0, 0),
        (600000, 1200000, 0, 15, 600000),
        (1200000, 1600000, 90000, 20, 1200000),
        (1600000, 3200000, 170000, 30, 1600000),
        (3200000, 5600000, 650000, 40, 3200000),
        (5600000, None, 1610000, 45, 5600000),
    ],
    "2025-26": [
        (0, 600000, 0, 0, 0),
        (600000, 1200000, 0, 15, 600000),
        (1200000, 1600000, 90000, 20, 1200000),
        (1600000, 3200000, 170000, 30, 1600000),
        (3200000, 5600000, 650000, 40, 3200000),
        (5600000, None, 1610000, 45, 5600000),
    ],
    "2026-27": [
        (0, 600000, 0, 0, 0),
        (600000, 1200000, 0, 15, 600000),
        (1200000, 1600000, 90000, 20, 1200000),
        (1600000, 3200000, 170000, 30, 1600000),
        (3200000, 5600000, 650000, 40, 3200000),
        (5600000, None, 1610000, 45, 5600000),
    ],
}


def execute():
    missing_years = [
        tax_year
        for tax_year in NON_SALARIED_SCHEDULES
        if not frappe.db.exists("OMC Tax Year", tax_year)
    ]
    if missing_years:
        frappe.throw(
            "Cannot seed Business/Rental slabs. Missing OMC Tax Year records: "
            + ", ".join(missing_years)
        )

    inserted = 0

    for tax_year, schedule in NON_SALARIED_SCHEDULES.items():
        year_doc = frappe.get_doc("OMC Tax Year", tax_year)

        retained_rows = [
            row.as_dict()
            for row in year_doc.slabs
            if row.income_type not in INCOME_TYPES
        ]
        year_doc.set("slabs", [])

        for row in retained_rows:
            for internal_field in (
                "name",
                "owner",
                "creation",
                "modified",
                "modified_by",
                "docstatus",
                "idx",
                "parent",
                "parentfield",
                "parenttype",
                "doctype",
            ):
                row.pop(internal_field, None)
            year_doc.append("slabs", row)

        next_sort_order = max(
            [int(row.sort_order or 0) for row in year_doc.slabs] or [0]
        ) + 100

        for income_type in INCOME_TYPES:
            for filer_status in FILER_STATUSES:
                for index, values in enumerate(schedule, start=1):
                    from_amount, to_amount, fixed_tax, rate_percent, amount_over = values

                    if to_amount:
                        amount_label = (
                            f"PKR {from_amount:,.0f} to PKR {to_amount:,.0f}"
                        )
                    elif from_amount:
                        amount_label = f"Above PKR {from_amount:,.0f}"
                    else:
                        amount_label = "No taxable income"

                    year_doc.append(
                        "slabs",
                        {
                            "income_type": income_type,
                            "filer_status": filer_status,
                            "taxpayer_type": "Individual",
                            "from_amount": from_amount,
                            "to_amount": to_amount,
                            "fixed_tax": fixed_tax,
                            "rate_percent": rate_percent,
                            "amount_over": amount_over,
                            "sort_order": next_sort_order + index,
                            "label": (
                                f"{income_type} · {filer_status} · {amount_label}"
                            ),
                        },
                    )
                    inserted += 1

                next_sort_order += 100

        existing_note = (year_doc.public_note or "").strip()
        extra_note = (
            "Business estimates use taxable business profit after allowable "
            "expenses. Rental estimates use taxable property income after "
            "allowable deductions. Filer status does not change the base "
            "annual progressive schedule; transaction-specific withholding "
            "rates may differ."
        )
        if extra_note not in existing_note:
            year_doc.public_note = (
                f"{existing_note}\n\n{extra_note}".strip()
            )

        year_doc.save(ignore_permissions=True)

    frappe.db.commit()

    expected = sum(
        len(schedule) * len(INCOME_TYPES) * len(FILER_STATUSES)
        for schedule in NON_SALARIED_SCHEDULES.values()
    )
    actual = frappe.db.count(
        "OMC Tax Slab",
        filters={
            "parent": ["in", list(NON_SALARIED_SCHEDULES)],
            "income_type": ["in", list(INCOME_TYPES)],
        },
    )

    if actual != expected:
        frappe.throw(
            f"Business/Rental slab verification failed: "
            f"expected {expected}, found {actual}."
        )

    print(
        f"Seeded {inserted} Business/Rental slab rows "
        f"across {len(NON_SALARIED_SCHEDULES)} tax years."
    )
