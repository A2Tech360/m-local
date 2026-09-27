"""Sample places for the What now? suggestions.

Every place here is invented. Names end in (Sample) and coordinates are
fictional points inside Ann Arbor. Rows: kind, what it is, name, latitude,
longitude, sample deal (blank when it has none). Real places will replace
these once local business data is collected.
"""

glob:pub AREA_CENTERS: dict[str, list[float]] = {
    "central campus": [42.2770, -83.7382],
    "state street": [42.2790, -83.7409],
    "south university": [42.2748, -83.7335],
    "main street": [42.2800, -83.7485],
    "kerrytown": [42.2850, -83.7470],
    "north campus": [42.2920, -83.7160]
};

glob:pub DEFAULT_AREA: str = "central campus";

glob:pub SAMPLE_PLACES: list[list[any]] = [
    ["activity", "Bookstore", "Paper Lantern Books (Sample)", 42.2794, -83.7418, ""],
    ["activity", "Thrift shop", "Second Spin Thrift (Sample)", 42.2806, -83.7476, "10% off with a student ID"],
    ["activity", "Record store", "Huron Groove Records (Sample)", 42.2812, -83.7490, ""],
    ["activity", "Board game cafe", "Dice Tower Cafe (Sample)", 42.2781, -83.7401, "Free table for the first hour"],
    ["activity", "Gallery", "Cedar Street Gallery (Sample)", 42.2846, -83.7462, ""],
    ["activity", "Climbing gym", "Maize Wall Climbing (Sample)", 42.2752, -83.7349, "$5 off a day pass"],
    ["activity", "Pop-up market", "Kerrytown Night Market (Sample)", 42.2856, -83.7478, ""],
    ["activity", "Arcade", "Atlas Arcade (Sample)", 42.2745, -83.7328, ""],
    ["coffee", "Coffee shop", "Juniper Coffee (Sample)", 42.2787, -83.7413, "$1 off any latte"],
    ["coffee", "Espresso bar", "Lantern Espresso (Sample)", 42.2772, -83.7390, ""],
    ["coffee", "Tea house", "Copper Kettle Tea (Sample)", 42.2803, -83.7481, ""],
    ["coffee", "Cafe", "Diag Corner Cafe (Sample)", 42.2766, -83.7376, "Free refill after 2 PM"],
    ["coffee", "Coffee shop", "Fig Leaf Roasters (Sample)", 42.2851, -83.7465, ""],
    ["coffee", "Boba", "Blue Pearl Boba (Sample)", 42.2750, -83.7341, "Second drink half off"],
    ["coffee", "Coffee cart", "Harbor Cold Brew (Sample)", 42.2759, -83.7360, ""],
    ["coffee", "Cafe", "Velvet Cup Cafe (Sample)", 42.2798, -83.7470, ""],
    ["dessert", "Ice cream", "Maize Creamery (Sample)", 42.2792, -83.7405, "Free topping with a cone"],
    ["dessert", "Bakery", "Crumb and Co. Bakery (Sample)", 42.2848, -83.7473, ""],
    ["dessert", "Cookies", "Ember Cookie Bar (Sample)", 42.2747, -83.7331, "3 cookies for $5"],
    ["dessert", "Gelato", "Arbor Gelato (Sample)", 42.2805, -83.7487, ""],
    ["dessert", "Donuts", "Golden Ring Donuts (Sample)", 42.2776, -83.7395, ""],
    ["dessert", "Crepes", "Tinder Crepe Stand (Sample)", 42.2764, -83.7369, ""],
    ["dessert", "Frozen yogurt", "Cedar Swirl Yogurt (Sample)", 42.2755, -83.7352, "$1 off a large cup"],
    ["dessert", "Bakery", "Huron Pie Shop (Sample)", 42.2810, -83.7479, ""],
    ["bars", "Pub", "Blue Door Pub (Sample)", 42.2801, -83.7483, "Half-price appetizers until 7 PM"],
    ["bars", "Sports bar", "Maize Tap Room (Sample)", 42.2749, -83.7338, ""],
    ["bars", "Cocktail bar", "Velvet Hour (Sample)", 42.2808, -83.7492, ""],
    ["bars", "Brewery", "Huron River Brewing (Sample)", 42.2853, -83.7481, "$2 off a flight"],
    ["bars", "Wine bar", "Fig and Vine (Sample)", 42.2843, -83.7459, ""],
    ["bars", "Dive bar", "Copper Rail (Sample)", 42.2789, -83.7420, ""],
    ["bars", "Beer garden", "Juniper Beer Garden (Sample)", 42.2757, -83.7345, ""],
    ["bars", "Karaoke bar", "Atlas Karaoke (Sample)", 42.2779, -83.7399, "No cover before 9 PM"]
];
