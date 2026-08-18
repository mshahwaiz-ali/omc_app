"""Canonical OMC referral and assisted-service capability declarations."""

from __future__ import annotations

from omc_app.setup.roles import (
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    TAX_ASSOCIATE_ROLE,
)

REFERRAL_OWNER_ROLES = frozenset({
    CONSULTANT_ROLE,
    TAX_ASSOCIATE_ROLE,
    BUSINESS_PARTNER_ROLE,
})

WALK_IN_CUSTOMER_ROLES = frozenset({
    "OMC Admin",
    "OMC Manager",
    "OMC Support Agent",
    CONSULTANT_ROLE,
    TAX_ASSOCIATE_ROLE,
    BUSINESS_PARTNER_ROLE,
    "System Manager",
})

ALL_CUSTOMER_ASSIST_ROLES = frozenset({
    "OMC Admin",
    "OMC Manager",
    "System Manager",
})

REFERRAL_ADMIN_ROLES = frozenset({
    "OMC Admin",
    "OMC Manager",
    "System Manager",
})
