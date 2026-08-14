"""Central role capability declarations for referral/assisted services.

These declarations are intentionally non-operative in Batch 1. Later API batches
must use them together with record-level permission and consent checks.
"""

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
