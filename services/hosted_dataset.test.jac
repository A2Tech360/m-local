"""Additive fixture import regression tests; isolated by scripts/test.sh."""
import from unittest.mock { patch }

def _dataset_record(identity: int, category: str = "cafe", restricted: bool = False) -> dict[str, any] {
    return {"id": "osm:node:" + str(identity), "name": "Fixture cafe", "category": category,
        "source_type": "node", "source_id": str(identity),
        "source_url": "https://www.openstreetmap.org/node/" + str(identity),
        "lat": 42.28, "lon": -83.74, "coordinate_method": "osm_node",
        "retrieved_at": "2026-09-27T00:00:00+00:00", "address": {},
        "quality_flags": ["restricted_access_tag"] if restricted else []};
}

test "hosted seed is opt in and does not read files when disabled" {
    with patch.dict(os.environ, {"MLOCAL_HOSTED_DATASET": ""}) {
        assert not hosted_dataset_enabled();
        ensure_hosted_dataset();
        assert not [root.shared -->[?:HostedDatasetLoaded]];
    }
}

test "month old promo timeline contains expired active ending soon and upcoming windows" {
    now = 2000000000.0;
    windows = [promo_timeline(i, now) for i in range(10)];
    assert len([w for w in windows if w[1] < now]) == 2;
    assert len([w for w in windows if w[0] <= now and w[1] > now]) == 6;
    assert len([w for w in windows if w[0] > now]) == 2;
    assert min([w[1] - now for w in windows if w[1] > now]) == 21600.0;
    assert all(w[0] < w[1] and w[2] <= w[0] for w in windows);
}

test "dataset import adds only eligible offers and repeat preserves inventory and identity" {
    real = Restaurant(slug="keep-existing-merchant", name="Existing business", owner_actor_id="existing-owner");
    root.shared ++> real;
    original = Offer(title="Existing offer", quantity=17, price=4.0, start_ts=1.0, end_ts=9999999999.0);
    real +>:Publishes():+> original;
    records = [_dataset_record(990001), _dataset_record(990002, "park"), _dataset_record(990003, "cafe", True)];
    assert _add_hosted_dataset(records) == 1;
    seeded = [r for r in [root.shared -->[?:Restaurant]] if r.slug == "dataset-test-osm-node-990001"][0];
    offer = [seeded ->:Publishes:->][0];
    identity = jid(offer);
    expiry = offer.end_ts;
    offer.quantity = 9;
    assert seeded.is_demo and seeded.name == "Fixture cafe";
    assert offer.is_demo and offer.title == "Coffee and a study break";
    assert _add_hosted_dataset(records) == 0;
    assert jid([seeded ->:Publishes:->][0]) == identity;
    assert offer.quantity == 9 and offer.end_ts == expiry;
    assert real.owner_actor_id == "existing-owner" and original.quantity == 17;
    assert len([p for p in [root.shared -->[?:Place]] if p.place_id in [rec["id"] for rec in records]]) == 3;
}
