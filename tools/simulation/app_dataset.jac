"""Local dataset-test bootstrap. Only imported by the isolated test launcher."""
import json;
import os;
import time;
import from services.places { Place, import_places, LocatedAt }
import from services.models { Restaurant, Location, Offer, HasLocation, Publishes }

node DatasetLoaded {
    has count: int, presentation_version: int = 0;
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
}

def offer_title(category: str) -> str {
    titles = {"restaurant": "Student lunch special", "fast_food": "Quick bite special",
        "cafe": "Coffee break special", "bakery": "Bakery pick of the day",
        "ice_cream": "Afternoon treat", "bar": "After-class food special", "pub": "After-class food special"};
    return titles.get(category, "Student special");
}

def refresh_dataset_presentation {
    markers = [root.shared -->[?:DatasetLoaded]];
    if not markers or markers[0].presentation_version >= 1 { return; }
    for r in [root.shared -->[?:Restaurant]] {
        if not r.slug.startswith("dataset-test-") { continue; }
        r.name = r.name.removesuffix(" (Test)");
        r.blurb = "Discover a local favorite in Ann Arbor.";
        for loc in [r ->:HasLocation:->] { loc.neighborhood = "Ann Arbor"; }
        for offer in [r ->:Publishes:->] {
            category = offer.title.removeprefix("TEST ONLY: ").removesuffix(" special").replace(" ", "_");
            offer.title = offer_title(category);
            offer.description = "Make time for a local favorite at a student-friendly price.";
            offer.eligibility = "Students with a valid university ID";
            offer.terms = "One per student. Show your claim QR at the counter. While supplies last. Price excludes tax.";
        }
    }
    markers[0].presentation_version = 1;
}

def ensure_test_dataset {
    if [root.shared -->[?:DatasetLoaded]] {
        refresh_dataset_presentation();
        return;
    }
    with open("data/simulation/places.json") as stream {
        records = json.load(stream) as list[dict[str, any]];
    }
    print("Importing place catalog...");
    count = import_places(records);
    print("Place catalog imported; creating labeled offers...");
    catalog = {p.place_id: p for p in [root.shared -->[?:Place]]};
    now = time.time();
    if os.environ.get("MLOCAL_DATASET_OFFERS", "") == "1" {
        for (i, rec) in enumerate(records) {
            category = str(rec["category"]);
            if category not in ["restaurant", "fast_food", "cafe", "bakery", "ice_cream", "bar", "pub"] { continue; }
            if "restricted_access_tag" in rec.get("quality_flags", []) { continue; }
            price = 3 + i % 13;
            addr = rec.get("address", {}) as dict[str, any];
            address = " ".join([str(addr.get(k) or "") for k in ["housenumber", "street", "city"]]).strip();
            r = Restaurant(
                slug="dataset-test-" + str(rec["id"]).replace(":", "-"),
                name=str(rec["name"]),
                cuisine=str(rec.get("cuisine") or category).replace("_", " "),
                blurb="Discover a local favorite in Ann Arbor.",
                is_demo=True, source="dataset-test:" + str(rec["source_url"])
            );
            root.shared ++> r;
            loc = Location(address=address or "Address unknown", neighborhood="Ann Arbor");
            r +>:HasLocation():+> loc;
            loc +>:LocatedAt():+> catalog[str(rec["id"])];
            r +>:Publishes():+> Offer(
                title=offer_title(category),
                description="Make time for a local favorite at a student-friendly price.",
                price=float(price), regular_price=float(price + 5),
                price_cents=price * 100, regular_price_cents=(price + 5) * 100,
                start_ts=now + (7200 if i % 10 == 0 else -3600),
                end_ts=now + 168 * 3600, quantity=0 if i % 17 == 0 else 25,
                dietary=["vegetarian"] if i % 3 == 0 else [],
                eligibility="Students with a valid university ID", is_demo=True, qr_ready=True,
                terms="One per student. Show your claim QR at the counter. While supplies last. Price excludes tax.",
                created_ts=now
            );
        }
    }
    assert len([root.shared -->[?:Place]]) == count;
    root.shared ++> DatasetLoaded(count=count, presentation_version=1);
    print("Dataset ready: " + str(count) + " places.");
}
