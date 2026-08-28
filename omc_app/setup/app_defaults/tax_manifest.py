from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


VERIFIED_ON = "2026-08-28"
DEFAULT_TAX_YEAR = "2026-27"


@dataclass(frozen=True)
class SlabSpec:
    from_amount: float
    to_amount: float | None
    fixed_tax: float
    rate_percent: float
    amount_over: float


@dataclass(frozen=True)
class TaxYearSpec:
    tax_year: str
    title: str
    effective_from: str
    effective_to: str
    source_reference: str
    public_note: str
    salary_slabs: tuple[SlabSpec, ...]
    non_salaried_slabs: tuple[SlabSpec, ...]
    surcharge_threshold: float = 0
    salary_surcharge_percent: float = 0
    non_salaried_surcharge_percent: float = 0


@dataclass(frozen=True)
class TaxInputSpec:
    field_key: str
    label: str
    income_type: str
    help_text: str
    sort_order: int
    input_type: str = "Number"
    mode: str = "Advanced"
    is_required: int = 0
    default_value: str = ""
    options_json: str = "[]"


def _slab(
    from_amount: float,
    to_amount: float | None,
    fixed_tax: float,
    rate_percent: float,
    amount_over: float | None = None,
) -> SlabSpec:
    return SlabSpec(
        from_amount=from_amount,
        to_amount=to_amount,
        fixed_tax=fixed_tax,
        rate_percent=rate_percent,
        amount_over=(from_amount if amount_over is None else amount_over),
    )


SALARY_2021_2022 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 5),
    _slab(1_200_000, 1_800_000, 30_000, 10),
    _slab(1_800_000, 2_500_000, 90_000, 15),
    _slab(2_500_000, 3_500_000, 195_000, 17.5),
    _slab(3_500_000, 5_000_000, 370_000, 20),
    _slab(5_000_000, 8_000_000, 670_000, 22.5),
    _slab(8_000_000, 12_000_000, 1_345_000, 25),
    _slab(12_000_000, 30_000_000, 2_345_000, 27.5),
    _slab(30_000_000, 50_000_000, 7_295_000, 30),
    _slab(50_000_000, 75_000_000, 13_295_000, 32.5),
    _slab(75_000_000, None, 21_420_000, 35),
)

NON_SALARIED_2021_2022 = (
    _slab(0, 400_000, 0, 0),
    _slab(400_000, 600_000, 0, 5),
    _slab(600_000, 1_200_000, 10_000, 10),
    _slab(1_200_000, 2_400_000, 70_000, 15),
    _slab(2_400_000, 3_000_000, 250_000, 20),
    _slab(3_000_000, 4_000_000, 370_000, 25),
    _slab(4_000_000, 6_000_000, 620_000, 30),
    _slab(6_000_000, None, 1_220_000, 35),
)

SALARY_2023 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 2.5),
    _slab(1_200_000, 2_400_000, 15_000, 12.5),
    _slab(2_400_000, 3_600_000, 165_000, 20),
    _slab(3_600_000, 6_000_000, 405_000, 25),
    _slab(6_000_000, 12_000_000, 1_005_000, 32.5),
    _slab(12_000_000, None, 2_955_000, 35),
)

NON_SALARIED_2023_2024 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 800_000, 0, 5),
    _slab(800_000, 1_200_000, 10_000, 12.5),
    _slab(1_200_000, 2_400_000, 60_000, 17.5),
    _slab(2_400_000, 3_000_000, 270_000, 22.5),
    _slab(3_000_000, 4_000_000, 405_000, 27.5),
    _slab(4_000_000, 6_000_000, 680_000, 32.5),
    _slab(6_000_000, None, 1_330_000, 35),
)

SALARY_2024 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 2.5),
    _slab(1_200_000, 2_400_000, 15_000, 12.5),
    _slab(2_400_000, 3_600_000, 165_000, 22.5),
    _slab(3_600_000, 6_000_000, 435_000, 27.5),
    _slab(6_000_000, None, 1_095_000, 35),
)

NON_SALARIED_2025_ONWARD = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 15),
    _slab(1_200_000, 1_600_000, 90_000, 20),
    _slab(1_600_000, 3_200_000, 170_000, 30),
    _slab(3_200_000, 5_600_000, 650_000, 40),
    _slab(5_600_000, None, 1_610_000, 45),
)

SALARY_2025 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 5),
    _slab(1_200_000, 2_200_000, 30_000, 15),
    _slab(2_200_000, 3_200_000, 180_000, 25),
    _slab(3_200_000, 4_100_000, 430_000, 30),
    _slab(4_100_000, None, 700_000, 35),
)

SALARY_2026 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 1),
    _slab(1_200_000, 2_200_000, 6_000, 11),
    _slab(2_200_000, 3_200_000, 116_000, 23),
    _slab(3_200_000, 4_100_000, 346_000, 30),
    _slab(4_100_000, None, 616_000, 35),
)

SALARY_2027 = (
    _slab(0, 600_000, 0, 0),
    _slab(600_000, 1_200_000, 0, 1),
    _slab(1_200_000, 2_200_000, 6_000, 11),
    _slab(2_200_000, 3_200_000, 116_000, 20),
    _slab(3_200_000, 4_100_000, 316_000, 25),
    _slab(4_100_000, 5_600_000, 541_000, 29),
    _slab(5_600_000, 7_000_000, 976_000, 32),
    _slab(7_000_000, None, 1_424_000, 35),
)


_COMMON_LIMITATION = (
    "Estimate for a resident individual under the ordinary progressive regime. "
    "It does not by itself determine final filing liability and does not model "
    "every exemption, tax credit, special/final regime, super tax or "
    "transaction-specific withholding consequence."
)

_RENTAL_2021_NOTE = (
    " For rental income in 2020-21, OMC models the normal-regime election "
    "available to an individual/AOP after admissible deductions; the separate "
    "gross-rent block treatment is outside this estimate."
)

_RENTAL_NORMAL_NOTE = (
    " Rental estimates treat the entered amount as taxable property income "
    "under the normal regime after admissible deductions."
)


TAX_YEARS = (
    TaxYearSpec(
        tax_year="2020-21",
        title="Tax Year 2021 (2020-21)",
        effective_from="2020-07-01",
        effective_to="2021-06-30",
        source_reference="FBR Finance Act 2020 / WHT Rate Card TY2021",
        public_note=_COMMON_LIMITATION + _RENTAL_2021_NOTE,
        salary_slabs=SALARY_2021_2022,
        non_salaried_slabs=NON_SALARIED_2021_2022,
    ),
    TaxYearSpec(
        tax_year="2021-22",
        title="Tax Year 2022 (2021-22)",
        effective_from="2021-07-01",
        effective_to="2022-06-30",
        source_reference="FBR Finance Act 2021 / WHT Rate Card TY2022",
        public_note=_COMMON_LIMITATION + _RENTAL_NORMAL_NOTE,
        salary_slabs=SALARY_2021_2022,
        non_salaried_slabs=NON_SALARIED_2021_2022,
    ),
    TaxYearSpec(
        tax_year="2022-23",
        title="Tax Year 2023 (2022-23)",
        effective_from="2022-07-01",
        effective_to="2023-06-30",
        source_reference="FBR Finance Act 2022 / WHT Rate Card TY2023",
        public_note=_COMMON_LIMITATION + _RENTAL_NORMAL_NOTE,
        salary_slabs=SALARY_2023,
        non_salaried_slabs=NON_SALARIED_2023_2024,
    ),
    TaxYearSpec(
        tax_year="2023-24",
        title="Tax Year 2024 (2023-24)",
        effective_from="2023-07-01",
        effective_to="2024-06-30",
        source_reference="FBR Finance Act 2023 / WHT Rate Card TY2024",
        public_note=_COMMON_LIMITATION + _RENTAL_NORMAL_NOTE,
        salary_slabs=SALARY_2024,
        non_salaried_slabs=NON_SALARIED_2023_2024,
    ),
    TaxYearSpec(
        tax_year="2024-25",
        title="Tax Year 2025 (2024-25)",
        effective_from="2024-07-01",
        effective_to="2025-06-30",
        source_reference="FBR Finance Act 2024 / Circular 01 of 2024-25",
        public_note=(
            _COMMON_LIMITATION
            + _RENTAL_NORMAL_NOTE
            + " Section 4AB surcharge is included above the configured threshold."
        ),
        salary_slabs=SALARY_2025,
        non_salaried_slabs=NON_SALARIED_2025_ONWARD,
        surcharge_threshold=10_000_000,
        salary_surcharge_percent=10,
        non_salaried_surcharge_percent=10,
    ),
    TaxYearSpec(
        tax_year="2025-26",
        title="Tax Year 2026 (2025-26)",
        effective_from="2025-07-01",
        effective_to="2026-06-30",
        source_reference="FBR Finance Act 2025 / Circular 01 of 2025-26",
        public_note=(
            _COMMON_LIMITATION
            + _RENTAL_NORMAL_NOTE
            + " Section 4AB surcharge is included above the configured threshold; "
            "the salary rate differs from the ordinary non-salaried rate."
        ),
        salary_slabs=SALARY_2026,
        non_salaried_slabs=NON_SALARIED_2025_ONWARD,
        surcharge_threshold=10_000_000,
        salary_surcharge_percent=9,
        non_salaried_surcharge_percent=10,
    ),
    TaxYearSpec(
        tax_year="2026-27",
        title="Tax Year 2027 (2026-27)",
        effective_from="2026-07-01",
        effective_to="2027-06-30",
        source_reference="FBR Finance Act 2026 / WHT Rate Card TY2027",
        public_note=(
            _COMMON_LIMITATION
            + _RENTAL_NORMAL_NOTE
            + " Finance Act 2026 removes the salary-specific section 4AB surcharge; "
            "the ordinary non-salaried section 4AB surcharge remains configured."
        ),
        salary_slabs=SALARY_2027,
        non_salaried_slabs=NON_SALARIED_2025_ONWARD,
        surcharge_threshold=10_000_000,
        salary_surcharge_percent=0,
        non_salaried_surcharge_percent=10,
    ),
)


TAX_INPUT_FIELDS = (
    TaxInputSpec(
        field_key="bonus_income",
        label="Bonus / additional annual income",
        income_type="Salary",
        help_text="Reserved for advanced-mode salary adjustments after rule review.",
        sort_order=10,
    ),
    TaxInputSpec(
        field_key="tax_already_deducted",
        label="Tax already deducted",
        income_type="Salary",
        help_text="Reserved for advanced-mode tax-credit handling after source-document review.",
        sort_order=20,
    ),
    TaxInputSpec(
        field_key="other_income",
        label="Other income",
        income_type="All",
        help_text="Reserved for advanced-mode multi-head income handling.",
        sort_order=30,
    ),
    TaxInputSpec(
        field_key="approved_deductions",
        label="Approved deductions",
        income_type="All",
        help_text="Reserved for advanced-mode deductions that are verified for the selected tax year.",
        sort_order=40,
    ),
    TaxInputSpec(
        field_key="business_turnover",
        label="Business turnover",
        income_type="Business",
        help_text="Reference input for future advanced business-tax handling.",
        sort_order=50,
    ),
    TaxInputSpec(
        field_key="deductible_expenses",
        label="Deductible expenses",
        income_type="Business",
        help_text="Reserved for advanced-mode expense deductions after rule verification.",
        sort_order=60,
    ),
    TaxInputSpec(
        field_key="withholding_tax_paid",
        label="Withholding tax paid",
        income_type="All",
        help_text="Reserved for advanced-mode credit handling after certificate review.",
        sort_order=70,
    ),
    TaxInputSpec(
        field_key="rental_annual_income",
        label="Rental annual income",
        income_type="Rental",
        help_text="Reference input for future advanced property-income handling.",
        sort_order=80,
    ),
    TaxInputSpec(
        field_key="province_city",
        label="Province / city",
        income_type="All",
        input_type="Text",
        help_text="Reference context only; it does not change the federal estimate.",
        sort_order=90,
    ),
)


def tax_year_spec(tax_year: str) -> TaxYearSpec | None:
    return next((row for row in TAX_YEARS if row.tax_year == tax_year), None)


def _tax_at(income: float, slab: SlabSpec) -> float:
    return slab.fixed_tax + max(0.0, income - slab.amount_over) * slab.rate_percent / 100


def calculate_schedule_tax(income: float, slabs: Iterable[SlabSpec]) -> float:
    amount = max(0.0, float(income or 0))
    for slab in slabs:
        if amount >= slab.from_amount and (
            slab.to_amount is None or amount <= slab.to_amount
        ):
            return _tax_at(amount, slab)
    raise ValueError(f"No tax slab covers income {amount}")


def surcharge_rate_for(tax_year: str, income_type: str, taxable_income: float) -> float:
    year = tax_year_spec(tax_year)
    if not year or not year.surcharge_threshold:
        return 0.0
    if float(taxable_income or 0) <= year.surcharge_threshold:
        return 0.0
    if str(income_type or "").strip().lower() == "salary":
        return float(year.salary_surcharge_percent or 0)
    return float(year.non_salaried_surcharge_percent or 0)


def _validate_schedule(name: str, slabs: tuple[SlabSpec, ...]) -> None:
    if not slabs or slabs[0].from_amount != 0 or slabs[-1].to_amount is not None:
        raise ValueError(f"{name} must cover zero through an open-ended final slab")

    for index, slab in enumerate(slabs):
        if slab.from_amount < 0 or slab.fixed_tax < 0 or slab.rate_percent < 0:
            raise ValueError(f"{name} contains a negative tax value")
        if not 0 <= slab.rate_percent <= 100:
            raise ValueError(f"{name} contains an invalid percentage")
        if slab.amount_over != slab.from_amount:
            raise ValueError(f"{name} amount_over must equal from_amount")
        if slab.to_amount is not None and slab.to_amount < slab.from_amount:
            raise ValueError(f"{name} has an inverted amount range")

        if index == 0:
            continue

        previous = slabs[index - 1]
        if previous.to_amount is None or previous.to_amount != slab.from_amount:
            raise ValueError(f"{name} has a gap or overlap at slab {index + 1}")

        expected_fixed = _tax_at(slab.from_amount, previous)
        if abs(expected_fixed - slab.fixed_tax) > 0.01:
            raise ValueError(
                f"{name} is discontinuous at {slab.from_amount}: "
                f"expected fixed tax {expected_fixed}, found {slab.fixed_tax}"
            )


def validate_tax_manifest() -> dict[str, object]:
    if len(TAX_YEARS) != 7:
        raise ValueError("Tax manifest must contain exactly seven tax years")

    years = [row.tax_year for row in TAX_YEARS]
    if years != [
        "2020-21",
        "2021-22",
        "2022-23",
        "2023-24",
        "2024-25",
        "2025-26",
        "2026-27",
    ]:
        raise ValueError("Tax years are missing or out of canonical order")

    for year in TAX_YEARS:
        _validate_schedule(f"{year.tax_year} Salary", year.salary_slabs)
        _validate_schedule(
            f"{year.tax_year} Business/Rental",
            year.non_salaried_slabs,
        )
        if not year.source_reference or not year.public_note:
            raise ValueError(f"{year.tax_year} is missing verification metadata")
        if not 0 <= year.salary_surcharge_percent <= 100:
            raise ValueError(f"{year.tax_year} salary surcharge is invalid")
        if not 0 <= year.non_salaried_surcharge_percent <= 100:
            raise ValueError(f"{year.tax_year} non-salaried surcharge is invalid")

    keys = [row.field_key for row in TAX_INPUT_FIELDS]
    if len(keys) != len(set(keys)):
        raise ValueError("Tax input field keys must be unique")

    return {
        "tax_years": len(TAX_YEARS),
        "income_types": 3,
        "input_fields": len(TAX_INPUT_FIELDS),
        "default_tax_year": DEFAULT_TAX_YEAR,
        "verified_on": VERIFIED_ON,
        "valid": True,
    }
