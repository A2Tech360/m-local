"""Clearly fictional demo businesses. Every name ends in "(Demo)" and every
offer is flagged is_demo, so nothing here can be mistaken for a real Ann Arbor
business. Loaded through the importer, the same path real sources will use."""

import time;
import from services.importer { import_restaurant, import_access_notices }
import from services.models { Restaurant }


glob:pub DEMO_RECORDS: list[dict[str, any]] = [
    {
        "slug": "maize-noodle-lab",
        "name": "Maize Street Noodle Lab (Demo)",
        "cuisine": "Noodles and dumplings",
        "blurb": "Fictional demo shop. Hand-pulled noodles, quick counter service.",
        "is_demo": True,
        "source": "demo-seed",
        "location": {
            "address": "100 Example Ave, Ann Arbor (fictional)",
            "neighborhood": "State Street",
            "entrance_note": "",
            "note_date": ""
        },
        "menu": [
            {"name": "Veggie Dan Dan Noodles", "price": 11.5, "dietary": ["vegetarian"]},
            {"name": "Pork Dumplings (8)", "price": 9.0, "dietary": []}
        ],
        "offers": [
            {
                "title": "Lunch noodle bowl for $7",
                "description": "A full bowl of Veggie Dan Dan Noodles at a student price.",
                "price": 7.0,
                "regular_price": 11.5,
                "start_in_h": -1,
                "end_in_h": 5,
                "quantity": 15,
                "eligibility": "Students with a valid university ID",
                "terms": "One bowl per student. Dine-in or takeout. Not combinable with other deals.",
                "dietary": ["vegetarian"],
                "menu_item": "Veggie Dan Dan Noodles"
            },
            {
                "title": "Late-night dumplings, 2 for 1",
                "description": "Two orders of pork dumplings for the price of one.",
                "price": 9.0,
                "regular_price": 18.0,
                "start_in_h": 6,
                "end_in_h": 10,
                "quantity": 10,
                "eligibility": "Students with a valid university ID",
                "terms": "Evenings only. Show your claim code at the counter.",
                "dietary": [],
                "menu_item": "Pork Dumplings (8)"
            }
        ]
    },
    {
        "slug": "arbor-leaf-kitchen",
        "name": "Arbor Leaf Kitchen (Demo)",
        "cuisine": "Plant-based bowls",
        "blurb": "Fictional demo cafe. Vegan and gluten-free grain bowls.",
        "is_demo": True,
        "source": "demo-seed",
        "location": {
            "address": "200 Sample St, Ann Arbor (fictional)",
            "neighborhood": "Kerrytown",
            "entrance_note": "",
            "note_date": ""
        },
        "menu": [
            {"name": "Harvest Grain Bowl", "price": 12.0, "dietary": ["vegan", "gluten-free"]},
            {"name": "Oat Latte", "price": 5.0, "dietary": ["vegan"]}
        ],
        "offers": [
            {
                "title": "Harvest bowl for $8",
                "description": "Our most popular vegan, gluten-free bowl.",
                "price": 8.0,
                "regular_price": 12.0,
                "start_in_h": -2,
                "end_in_h": 3,
                "quantity": 8,
                "eligibility": "Students with a valid university ID",
                "terms": "One per student per day. While supplies last.",
                "dietary": ["vegan", "gluten-free", "vegetarian"],
                "menu_item": "Harvest Grain Bowl"
            },
            {
                "title": "$3 oat latte study break",
                "description": "Any size oat latte.",
                "price": 3.0,
                "regular_price": 5.0,
                "start_in_h": -1,
                "end_in_h": 8,
                "quantity": 25,
                "eligibility": "Any student",
                "terms": "Hot or iced. Limit one.",
                "dietary": ["vegan", "vegetarian", "gluten-free"],
                "menu_item": "Oat Latte"
            }
        ]
    },
    {
        "slug": "diag-dough-co",
        "name": "Diag Dough Co. (Demo)",
        "cuisine": "Pizza by the slice",
        "blurb": "Fictional demo pizzeria. Big slices, halal toppings available.",
        "is_demo": True,
        "source": "demo-seed",
        "location": {
            "address": "300 Placeholder Rd, Ann Arbor (fictional)",
            "neighborhood": "South University",
            "entrance_note": "",
            "note_date": ""
        },
        "menu": [
            {"name": "Halal Chicken Slice", "price": 6.0, "dietary": ["halal"]},
            {"name": "Cheese Slice", "price": 4.5, "dietary": ["vegetarian"]}
        ],
        "offers": [
            {
                "title": "Slice + drink for $5",
                "description": "One halal chicken slice and a fountain drink.",
                "price": 5.0,
                "regular_price": 8.5,
                "start_in_h": -3,
                "end_in_h": 4,
                "quantity": 3,
                "eligibility": "Students with a valid university ID",
                "terms": "Takeout only. Limited quantity.",
                "dietary": ["halal"],
                "menu_item": "Halal Chicken Slice"
            },
            {
                "title": "Weekend cheese slice deal",
                "description": "Two cheese slices for $6. Paused by the merchant for this demo.",
                "price": 6.0,
                "regular_price": 9.0,
                "start_in_h": -1,
                "end_in_h": 30,
                "quantity": 20,
                "eligibility": "Any student",
                "terms": "Weekends only.",
                "dietary": ["vegetarian"],
                "menu_item": "Cheese Slice",
                "status": "paused"
            }
        ]
    }
];


"""Create relative fixture timestamps once for a new isolated demo store.

The record is deliberately simulated and names a fictional store. It does not
claim a real construction event, route, or confirmed alternate entrance.
"""
def demo_access_notice_records(now_ts: float = 0.0) -> list[dict[str, any]] {
    now = now_ts if now_ts > 0 else time.time();
    return [{
        "source_id": "m-local-demo",
        "external_id": "maize-access-demo-1",
        "location_slug": "maize-noodle-lab",
        "version": "1",
        "publisher": "M-Local simulated fixture",
        "source_url": "",
        "checked_at": now,
        "valid_from": now - 60,
        "valid_until": now + 6 * 3600,
        "summary": "Demo access context for a fictional storefront. Confirm access before visiting.",
        "is_demo": True,
        "entrance_instruction": "",
        "original_evidence": {"fixture": "data/demo/access-notices.json", "simulated": True},
        "normalized_evidence": {"review_status": "simulated", "association": "fictional demo only"}
    }];
}


def seed_demo_access_notices(now_ts: float = 0.0) -> list[str] {
    """Callable fresh-fixture path for an isolated store (for example demo.sh).""";
    return import_access_notices(demo_access_notice_records(now_ts));
}


"""Load demo records once. Safe to call repeatedly (importer skips known slugs)."""
def seed_demo() -> int {
    was_empty = not [root-->[?:Restaurant]];
    for rec in DEMO_RECORDS {
        import_restaurant(rec);
    }
    # Do not rewrite timestamps in an existing store: the first seed anchors them.
    if was_empty {
        seed_demo_access_notices();
    }
    return len(DEMO_RECORDS);
}
