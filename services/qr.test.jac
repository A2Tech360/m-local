import from services.money { money_to_cents }

test "money accepts only nonnegative decimal cents" {
    assert money_to_cents("0") == 0;
    assert money_to_cents("12.3") == 1230;
    assert money_to_cents("12.34") == 1234;
    assert money_to_cents(" 7.00 ") == 700;
    for bad in ["", "NaN", "Infinity", "-1", "1.234", "1e3", "$5", ".25"] {
        rejected = False;
        try { _ = money_to_cents(bad); } except ValueError { rejected = True; }
        assert rejected, bad;
    }
}

test "QR payload is canonical 32 random bytes" {
    first = new_qr_payload();
    second = new_qr_payload();
    assert len(first) == 53;
    assert first.startswith("mlocal:v1:");
    assert first != second;
    assert valid_qr_payload(first);
    assert valid_qr_payload(second);
}

test "QR rejects malformed version oversized URL and noncanonical padding bits" {
    good = "mlocal:v1:" + "A" * 43;
    assert valid_qr_payload(good);
    for bad in ["", "https://example.com/claim", good + "=", " " + good,
                good + "\n", good.replace("v1", "v2"), "mlocal:v1:" + "A" * 42,
                "mlocal:v1:" + "A" * 10000, "mlocal:v1:" + "A" * 42 + "B",
                "mlocal:v1:" + "A" * 42 + "+", "mlocal:v1:" + "é" * 43] {
        assert not valid_qr_payload(bad), bad;
    }
}
