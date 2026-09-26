"""PromoPusher graph schema.

Restaurant -HasLocation-> Location
Restaurant -Serves-> MenuItem
Restaurant -Publishes-> Offer -Features-> MenuItem
Offer -ClaimedAs-> Redemption

Times are epoch seconds (float); display is converted to Ann Arbor local time.
"""

node Restaurant {
    has slug: str,
        name: str,
        cuisine: str = "",
        blurb: str = "",
        merchant_key: str = "",
        is_demo: bool = False,
        source: str = "manual";
}

node Location {
    has address: str,
        neighborhood: str = "",
        entrance_note: str = "",
        note_date: str = "";
}

node MenuItem {
    has name: str,
        price: float = 0.0,
        dietary: list[str] = [];
}

node Offer {
    has title: str,
        description: str = "",
        price: float = 0.0,
        regular_price: float = 0.0,
        start_ts: float = 0.0,
        end_ts: float = 0.0,
        quantity: int = 0,
        eligibility: str = "Any student with a valid student ID",
        terms: str = "",
        dietary: list[str] = [],
        status: str = "active",
        is_demo: bool = False,
        menu_item: str = "",
        created_ts: float = 0.0;
}

node Redemption {
    has student_id: str,
        code: str,
        status: str = "claimed",
        claimed_ts: float = 0.0,
        expires_ts: float = 0.0,
        redeemed_ts: float = 0.0;
}

edge HasLocation: Restaurant --> Location {}

edge Serves: Restaurant --> MenuItem {}

edge Publishes: Restaurant --> Offer {}

edge Features: Offer --> MenuItem {}

edge ClaimedAs: Offer --> Redemption {}

"""Minutes a claim holds a unit before it is released back to availability."""
glob:pub CLAIM_HOLD_MINUTES: int = 20;

glob:pub DIET_TAGS: list[str] = ["vegetarian", "vegan", "gluten-free", "halal"];
