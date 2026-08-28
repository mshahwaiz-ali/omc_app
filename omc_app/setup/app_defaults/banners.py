from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class BannerSpec:
    banner_id: str
    title: str
    subtitle: str
    action_label: str
    mobile_route: str
    sort_order: int
    status: str = "Published"
    image: str = ""
    starts_on: str = ""
    ends_on: str = ""


BANNERS = (
    BannerSpec(
        banner_id="omc-home-services",
        title="Your OMC services, all in one place",
        subtitle=(
            "Explore professional services, review requirements and understand "
            "the next step before you start."
        ),
        action_label="Explore Services",
        mobile_route="/services",
        sort_order=10,
    ),
    BannerSpec(
        banner_id="omc-home-business-ready",
        title="Stay ready for your next filing",
        subtitle=(
            "Keep records organised, review practical guides and prepare the "
            "information your next service may require."
        ),
        action_label="Open Knowledge",
        mobile_route="/knowledge",
        sort_order=20,
    ),
)


def validate_banner_manifest() -> dict[str, object]:
    if len(BANNERS) != 2:
        raise ValueError("Banner manifest must contain exactly 2 evergreen banners.")
    ids = [banner.banner_id for banner in BANNERS]
    if len(ids) != len(set(ids)):
        raise ValueError("Banner IDs must be unique.")
    orders = [banner.sort_order for banner in BANNERS]
    if orders != sorted(orders) or len(orders) != len(set(orders)):
        raise ValueError("Banner sort orders must be unique and increasing.")
    for banner in BANNERS:
        if not banner.banner_id or not banner.title.strip():
            raise ValueError("Banner identity and title are required.")
        if not banner.subtitle.strip() or not banner.mobile_route.startswith("/"):
            raise ValueError(f"Banner {banner.banner_id} requires safe app copy and route.")
        if banner.status != "Published":
            raise ValueError("Managed banners must be Published.")
    return {"banners": len(BANNERS), "valid": True}
