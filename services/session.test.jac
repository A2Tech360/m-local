import from services.qr_auth { configured_owners }

test "merchant provisioning accepts only trusted UUID mappings" {
    actor = "a1c7350c-5be2-4b78-aef1-905e7e1b6fe4";
    owners = configured_owners('{"cafe":"' + actor + '"}');
    assert owners.get("cafe") == actor;
    for bad in ["", "null", "[]", "invalid json", '{"cafe":"merchant"}',
                '{"cafe":true}', '{"cafe":"' + actor + '","other":"' + actor + '"}'] {
        assert configured_owners(bad) == {};
    }
}

test "default session contains no identity or merchant authority" {
    s = SessionView();
    assert not s.authenticated;
    assert s.role == "guest" and s.actor_id == "" and s.restaurant_id == "";
}
