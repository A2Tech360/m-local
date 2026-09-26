"""PromoPusher business logic and API.

Rules enforced here (never in the client):
- Ownership: every merchant call carries a merchant key; offers, profiles and
  claim codes are only reachable through the restaurant that owns that key.
- Expiration: offers outside [start, end] or paused cannot be claimed.
- Quantity: remaining = quantity - redeemed - live (unexpired) claims.
- Claim hold: a claim reserves one unit for CLAIM_HOLD_MINUTES (or until the
  offer ends, whichever is sooner). Unredeemed claims past that time become
  "expired" and the unit is released automatically.
- Duplicates: one live or redeemed claim per student per offer; a code can be
  redeemed exactly once.

Internal f"_" helpers take an explicit f"now" so checks can simulate time.
"""

import time;
import random;
import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }
import from services.models {
    Restaurant,
    Location,
    MenuItem,
    Offer,
    Redemption,
    HasLocation,
    Serves,
    Publishes,
    Features,
    ClaimedAs,
    CLAIM_HOLD_MINUTES
}
import from services.seed { seed_demo }


obj OfferView {
    has id: str = "",
        title: str = "",
        description: str = "",
        restaurant: str = "",
        cuisine: str = "",
        address: str = "",
        neighborhood: str = "",
        entrance_note: str = "",
        note_date: str = "",
        price: float = 0.0,
        regular_price: float = 0.0,
        start_input: str = "",
        end_input: str = "",
        time_label: str = "",
        state: str = "",
        remaining: int = 0,
        quantity: int = 0,
        eligibility: str = "",
        terms: str = "",
        dietary: list[str] = [],
        menu_item: str = "",
        is_demo: bool = False,
        fits: bool = True,
        reasons: list[str] = [],
        my_code: str = "",
        my_status: str = "",
        my_expires: str = "";
}

obj ClaimView {
    has code: str = "",
        student_id: str = "",
        offer_title: str = "",
        status: str = "",
        claimed_label: str = "",
        expires_label: str = "";
}

obj ActionResult {
    has ok: bool = False,
        message: str = "",
        code: str = "";
}

obj MerchantView {
    has ok: bool = False,
        message: str = "",
        name: str = "",
        cuisine: str = "",
        blurb: str = "",
        address: str = "",
        neighborhood: str = "",
        entrance_note: str = "",
        note_date: str = "",
        is_demo: bool = False,
        offers: list[OfferView] = [],
        claims: list[ClaimView] = [];
}


# ---------------------------------------------------------------- helpers ---

def _tz -> any {
    try {
        return ZoneInfo("America/Detroit");
    } except Exception {
        return None;
    }
}


def _local(ts: float) -> datetime {
    return datetime.fromtimestamp(ts, _tz());
}


def _clock(ts: float) -> str {
    return _local(ts).strftime("%-I:%M %p");
}


def _day_clock(ts: float) -> str {
    return _local(ts).strftime("%a %-I:%M %p");
}


def _input_fmt(ts: float) -> str {
    return _local(ts).strftime("%Y-%m-%d %H:%M");
}


def _parse_local(text: str) -> float | None {
    try {
        dt = datetime.strptime(text.strip(), "%Y-%m-%d %H:%M");
        return dt.replace(tzinfo=_tz()).timestamp();
    } except Exception {
        return None;
    }
}


def _span(seconds: float) -> str {
    mins = int(max(seconds, 0) // 60);
    if mins >= 60 {
        return f"{mins // 60}h {mins % 60}m";
    }
    return f"{mins}m";
}


def _money(v: float) -> str {
    return f"${v:.2f}";
}


def _ensure_seed -> None {
    if not [root-->[?:Restaurant]] {
        seed_demo();
    }
}


def _restaurant_of(o: Offer) -> Restaurant | None {
    owners = [o <-:Publishes:<-];
    return owners[0] if owners else None;
}


def _location_of(r: Restaurant) -> Location | None {
    locs = [r ->:HasLocation:->];
    return locs[0] if locs else None;
}


def _find_offer(offer_id: str) -> Offer | None {
    for r in [root-->[?:Restaurant]] {
        for o in [r ->:Publishes:->] {
            if jid(o) == offer_id {
                return o;
            }
        }
    }
    return None;
}


def _merchant(key: str) -> Restaurant | None {
    k = key.strip();
    if not k {
        return None;
    }
    found = [root-->[?:Restaurant, merchant_key == k]];
    return found[0] if found else None;
}


def _owned_offer(r: Restaurant, offer_id: str) -> Offer | None {
    for o in [r ->:Publishes:->] {
        if jid(o) == offer_id {
            return o;
        }
    }
    return None;
}


"""Release abandoned claims: live claims past their hold become expired."""
def _sweep(o: Offer, now: float) -> None {
    for c in [o ->:ClaimedAs:->] {
        if c.status == "claimed" and now > c.expires_ts {
            c.status = "expired";
        }
    }
}


def _remaining(o: Offer, now: float) -> int {
    _sweep(o, now);
    held = len([c for c in [o ->:ClaimedAs:->] if c.status in ["claimed", "redeemed"]]);
    return max(o.quantity - held, 0);
}


def _state(o: Offer, now: float) -> str {
    if o.status == "paused" {
        return "paused";
    }
    if now >= o.end_ts {
        return "expired";
    }
    if now < o.start_ts {
        return "scheduled";
    }
    if _remaining(o, now) <= 0 {
        return "sold out";
    }
    return "active";
}


def _parse_diets(diets: str) -> list[str] {
    return [d.strip().lower() for d in diets.split(",") if d.strip()];
}


def _parse_budget(max_price: str) -> float | None {
    try {
        return float(max_price.strip().lstrip("$")) if max_price.strip() else None;
    } except Exception {
        return None;
    }
}


def _end_of_today(now: float) -> float {
    d = _local(now);
    nxt = (d + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0);
    return nxt.timestamp();
}


"""Plain-language reasons + whether the offer fits all active filters."""
def _explain(
    o: Offer,
    state: str,
    remaining: int,
    budget: float | None,
    window: str,
    wanted: list[str],
    now: float
) -> tuple[bool, list[str]] {
    # Short match tags only for the student's own filters; price, time and
    # stock are already shown on screen, so they are not repeated here.
    reasons: list[str] = [];
    fits = True;
    if budget is not None {
        if o.price <= budget {
            reasons.append(f"Under your {_money(budget)} budget");
        } else {
            fits = False;
            reasons.append(f"Over your {_money(budget)} budget");
        }
    }
    if window == "now" and state == "active" {
        reasons.append("Open right now");
    } elif window == "today" and state in ["active", "scheduled"] {
        reasons.append("Available today");
    }
    if state == "scheduled" and window == "now" {
        fits = False;
    }
    if state in ["sold out", "paused", "expired"] {
        fits = False;
    }
    for w in wanted {
        if w in o.dietary {
            reasons.append(w.capitalize());
        } else {
            fits = False;
            reasons.append(f"Not marked {w}");
        }
    }
    _ = (remaining, now);
    return (fits, reasons);
}


def _view(
    o: Offer,
    now: float,
    student_id: str = "",
    budget: float | None = None,
    window: str = "any",
    wanted: list[str] = []
) -> OfferView {
    r = _restaurant_of(o);
    loc = _location_of(r) if r else None;
    state = _state(o, now);
    remaining = _remaining(o, now);
    (fits, reasons) = _explain(o, state, remaining, budget, window, wanted, now);
    if state == "active" {
        tlabel = f"Until {_clock(o.end_ts)} · {_span(o.end_ts - now)} left";
    } elif state == "scheduled" {
        tlabel = f"Starts {_day_clock(o.start_ts)}";
    } elif state == "expired" {
        tlabel = f"Ended {_day_clock(o.end_ts)}";
    } else {
        tlabel = f"{_day_clock(o.start_ts)} - {_clock(o.end_ts)}";
    }
    v = OfferView(
        id=jid(o),
        title=o.title,
        description=o.description,
        restaurant=r.name if r else "",
        cuisine=r.cuisine if r else "",
        address=loc.address if loc else "",
        neighborhood=loc.neighborhood if loc else "",
        entrance_note=loc.entrance_note if loc else "",
        note_date=loc.note_date if loc else "",
        price=o.price,
        regular_price=o.regular_price,
        start_input=_input_fmt(o.start_ts),
        end_input=_input_fmt(o.end_ts),
        time_label=tlabel,
        state=state,
        remaining=remaining,
        quantity=o.quantity,
        eligibility=o.eligibility,
        terms=o.terms,
        dietary=o.dietary,
        menu_item=o.menu_item,
        is_demo=o.is_demo,
        fits=fits,
        reasons=reasons
    );
    sid = student_id.strip().lower();
    if sid {
        for c in [o ->:ClaimedAs:->[?student_id == sid]] {
            if c.status in ["claimed", "redeemed"] {
                v.my_code = c.code;
                v.my_status = c.status;
                v.my_expires = _clock(c.expires_ts);
            }
        }
    }
    return v;
}


def _new_code -> str {
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    taken: list[str] = [];
    for r in [root-->[?:Restaurant]] {
        for o in [r ->:Publishes:->] {
            taken.extend([c.code for c in [o ->:ClaimedAs:->]]);
        }
    }
    code = "".join([random.choice(alphabet) for _ in range(6)]);
    while code in taken {
        code = "".join([random.choice(alphabet) for _ in range(6)]);
    }
    return code;
}


def _claim(offer_id: str, student_id: str, now: float) -> ActionResult {
    sid = student_id.strip().lower();
    if not sid {
        return ActionResult(ok=False, message="Enter your student name or ID first.");
    }
    o = _find_offer(offer_id);
    if o is None {
        return ActionResult(ok=False, message="That offer no longer exists.");
    }
    for c in [o ->:ClaimedAs:->[?student_id == sid]] {
        _sweep(o, now);
        if c.status == "redeemed" {
            return ActionResult(ok=False, message="You already redeemed this offer.", code=c.code);
        }
        if c.status == "claimed" {
            return ActionResult(
                ok=False,
                message=f"You already hold this offer. Show code {c.code} before {_clock(c.expires_ts)}.",
                code=c.code
            );
        }
    }
    state = _state(o, now);
    if state != "active" {
        msgs = {
            "paused": "This offer is paused by the restaurant.",
            "expired": "This offer has expired.",
            "scheduled": "This offer has not started yet.",
            "sold out": "This offer is sold out right now."
        };
        return ActionResult(ok=False, message=msgs[state]);
    }
    expires = min(now + CLAIM_HOLD_MINUTES * 60, o.end_ts);
    code = _new_code();
    o +>:ClaimedAs():+> Redemption(
        student_id=sid, code=code, status="claimed", claimed_ts=now, expires_ts=expires
    );
    return ActionResult(
        ok=True,
        message=f"Claimed. Show code {code} at the counter before {_clock(expires)}.",
        code=code
    );
}


def _redeem(merchant_key: str, code: str, now: float) -> ActionResult {
    r = _merchant(merchant_key);
    if r is None {
        return ActionResult(ok=False, message="Unknown merchant key.");
    }
    want = code.strip().upper();
    if not want {
        return ActionResult(ok=False, message="Enter a claim code.");
    }
    for o in [r ->:Publishes:->] {
        for c in [o ->:ClaimedAs:->[?code == want]] {
            if c.status == "redeemed" {
                return ActionResult(
                    ok=False,
                    message=f"Code {want} was already redeemed at {_day_clock(c.redeemed_ts)}.",
                    code=want
                );
            }
            if c.status == "expired" or now > c.expires_ts {
                c.status = "expired";
                return ActionResult(
                    ok=False,
                    message=f"Code {want} expired at {_clock(c.expires_ts)}. The unit was released.",
                    code=want
                );
            }
            c.status = "redeemed";
            c.redeemed_ts = now;
            return ActionResult(
                ok=True,
                message=f"Redeemed: {o.title} for {c.student_id}. Charge {_money(o.price)}.",
                code=want
            );
        }
    }
    return ActionResult(ok=False, message=f"No claim {want} found for {r.name}.");
}


def _save_offer(
    r: Restaurant,
    offer_id: str,
    title: str,
    description: str,
    price: str,
    regular_price: str,
    start_local: str,
    end_local: str,
    quantity: str,
    eligibility: str,
    terms: str,
    dietary: str,
    menu_item: str,
    now: float
) -> ActionResult {
    errors: list[str] = [];
    p = _parse_budget(price);
    rp = _parse_budget(regular_price) if regular_price.strip() else 0.0;
    st = _parse_local(start_local);
    en = _parse_local(end_local);
    qty = -1;
    try {
        qty = int(quantity.strip());
    } except Exception {
        qty = -1;
    }
    if not title.strip() {
        errors.append("title is required");
    }
    if p is None or p < 0 {
        errors.append("price must be a number");
    }
    if rp is None or rp < 0 {
        errors.append("regular price must be a number");
    }
    if st is None or en is None {
        errors.append("times must look like 2026-09-26 14:00");
    } elif en <= st {
        errors.append("end must be after start");
    }
    if qty < 1 {
        errors.append("quantity must be at least 1");
    }
    if not eligibility.strip() {
        errors.append("eligibility is required");
    }
    if not terms.strip() {
        errors.append("terms are required");
    }
    o: Offer | None = None;
    if offer_id {
        o = _owned_offer(r, offer_id);
        if o is None {
            return ActionResult(ok=False, message="That offer does not belong to your restaurant.");
        }
        held = o.quantity - _remaining(o, now);
        if qty >= 1 and qty < held {
            errors.append(f"quantity cannot go below {held} already claimed or redeemed");
        }
    }
    if errors {
        return ActionResult(ok=False, message="Fix: " + "; ".join(errors) + ".");
    }
    if o is None {
        o = Offer(title=title.strip(), created_ts=now, is_demo=r.is_demo);
        r +>:Publishes():+> o;
    }
    o.title = title.strip();
    o.description = description.strip();
    o.price = p or 0.0;
    o.regular_price = rp or 0.0;
    o.start_ts = st or now;
    o.end_ts = en or now;
    o.quantity = qty;
    o.eligibility = eligibility.strip();
    o.terms = terms.strip();
    o.dietary = _parse_diets(dietary);
    o.menu_item = menu_item.strip();
    for e in [edge o ->:Features:->] {
        del e;
    }
    if o.menu_item {
        items = [m for m in [r ->:Serves:->] if m.name == o.menu_item];
        item = items[0] if items else None;
        if item is None {
            item = MenuItem(name=o.menu_item, price=o.regular_price, dietary=o.dietary);
            r +>:Serves():+> item;
        }
        o +>:Features():+> item;
    }
    return ActionResult(ok=True, message="Offer saved.", code=jid(o));
}


def _portal(r: Restaurant, now: float, message: str = "") -> MerchantView {
    loc = _location_of(r);
    offers = [o for o in [r ->:Publishes:->]];
    offers.sort(key=lambda (o: Offer) -> float { return o.start_ts; });
    claims: list[tuple[float, ClaimView]] = [];
    for o in offers {
        _sweep(o, now);
        for c in [o ->:ClaimedAs:->] {
            claims.append((c.claimed_ts, ClaimView(
                code=c.code,
                student_id=c.student_id,
                offer_title=o.title,
                status=c.status,
                claimed_label=_day_clock(c.claimed_ts),
                expires_label=_clock(c.expires_ts)
            )));
        }
    }
    claims.sort(key=lambda (t: tuple[float, ClaimView]) -> float { return t[0]; }, reverse=True);
    return MerchantView(
        ok=True,
        message=message,
        name=r.name,
        cuisine=r.cuisine,
        blurb=r.blurb,
        address=loc.address if loc else "",
        neighborhood=loc.neighborhood if loc else "",
        entrance_note=loc.entrance_note if loc else "",
        note_date=loc.note_date if loc else "",
        is_demo=r.is_demo,
        offers=[_view(o, now) for o in offers],
        claims=[t[1] for t in claims[:30]]
    );
}


# --------------------------------------------------------------- endpoints ---

"""Student discovery: filter by budget ($), time window (now|today|any) and
comma-separated dietary tags. Paused and ended offers are hidden."""
def:pub list_offers(
    student_id: str = "", max_price: str = "", window: str = "any", diets: str = ""
) -> list[OfferView] {
    _ensure_seed();
    now = time.time();
    budget = _parse_budget(max_price);
    wanted = _parse_diets(diets);
    eod = _end_of_today(now);
    out: list[OfferView] = [];
    for r in [root-->[?:Restaurant]] {
        for o in [r ->:Publishes:->] {
            if o.status == "paused" or now >= o.end_ts {
                continue;
            }
            if budget is not None and o.price > budget {
                continue;
            }
            if window == "now" and o.start_ts > now {
                continue;
            }
            if window == "today" and o.start_ts >= eod {
                continue;
            }
            if wanted and [w for w in wanted if w not in o.dietary] {
                continue;
            }
            out.append(_view(o, now, student_id, budget, window, wanted));
        }
    }
    rank = {"active": 0, "scheduled": 1, "sold out": 2};
    out.sort(key=lambda (v: OfferView) -> int { return rank.get(v.state, 3); });
    return out;
}


def:pub get_offer(
    offer_id: str,
    student_id: str = "",
    max_price: str = "",
    window: str = "any",
    diets: str = ""
) -> OfferView | None {
    _ensure_seed();
    o = _find_offer(offer_id);
    if o is None {
        return None;
    }
    return _view(
        o, time.time(), student_id, _parse_budget(max_price), window, _parse_diets(diets)
    );
}


def:pub claim_offer(offer_id: str, student_id: str) -> ActionResult {
    _ensure_seed();
    return _claim(offer_id, student_id, time.time());
}


def:pub merchant_portal(merchant_key: str) -> MerchantView {
    _ensure_seed();
    r = _merchant(merchant_key);
    if r is None {
        return MerchantView(ok=False, message="Unknown merchant key.");
    }
    return _portal(r, time.time());
}


def:pub update_profile(
    merchant_key: str,
    name: str,
    cuisine: str,
    blurb: str,
    address: str,
    neighborhood: str,
    entrance_note: str,
    note_date: str
) -> MerchantView {
    r = _merchant(merchant_key);
    if r is None {
        return MerchantView(ok=False, message="Unknown merchant key.");
    }
    if not name.strip() or not address.strip() {
        return _portal(r, time.time(), "Name and address are required.");
    }
    r.name = name.strip();
    r.cuisine = cuisine.strip();
    r.blurb = blurb.strip();
    loc = _location_of(r);
    if loc is None {
        loc = Location(address="");
        r +>:HasLocation():+> loc;
    }
    loc.address = address.strip();
    loc.neighborhood = neighborhood.strip();
    loc.entrance_note = entrance_note.strip();
    loc.note_date = note_date.strip();
    return _portal(r, time.time(), "Profile saved.");
}


def:pub save_offer(
    merchant_key: str,
    offer_id: str,
    title: str,
    description: str,
    price: str,
    regular_price: str,
    start_local: str,
    end_local: str,
    quantity: str,
    eligibility: str,
    terms: str,
    dietary: str,
    menu_item: str
) -> ActionResult {
    r = _merchant(merchant_key);
    if r is None {
        return ActionResult(ok=False, message="Unknown merchant key.");
    }
    return _save_offer(
        r,
        offer_id,
        title,
        description,
        price,
        regular_price,
        start_local,
        end_local,
        quantity,
        eligibility,
        terms,
        dietary,
        menu_item,
        time.time()
    );
}


def:pub set_offer_status(merchant_key: str, offer_id: str, status: str) -> ActionResult {
    r = _merchant(merchant_key);
    if r is None {
        return ActionResult(ok=False, message="Unknown merchant key.");
    }
    if status not in ["active", "paused"] {
        return ActionResult(ok=False, message="Status must be active or paused.");
    }
    o = _owned_offer(r, offer_id);
    if o is None {
        return ActionResult(ok=False, message="That offer does not belong to your restaurant.");
    }
    o.status = status;
    return ActionResult(ok=True, message="Offer resumed." if status == "active" else "Offer paused.");
}


def:pub redeem_code(merchant_key: str, code: str) -> ActionResult {
    return _redeem(merchant_key, code, time.time());
}


"""Default start/end strings for a new offer in the editor (now .. now+3h)."""
def:pub offer_defaults() -> list[str] {
    now = time.time();
    return [_input_fmt(now), _input_fmt(now + 3 * 3600)];
}
