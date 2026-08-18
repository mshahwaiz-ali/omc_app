"""Canonical OMC referral and assisted-service capability declarations."""

from __future__ import annotations

REFERRAL_OWNER_ROLES = frozenset({
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
})

WALK_IN_CUSTOMER_ROLES = frozenset({
    "OMC Admin",
    "OMC Manager",
    "OMC Support Agent",
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
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
