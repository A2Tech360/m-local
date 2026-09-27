"""Convert input dollars to exact integer cents; floats are display only."""

import re;

def money_to_cents(text: str) -> int {
    amount = text.strip();
    if re.fullmatch(r"[0-9]+(?:\.[0-9]{1,2})?", amount) is None {
        raise ValueError("Use a nonnegative dollar amount with at most two decimal places.");
    }
    parts = amount.split(".");
    cents = int(parts[0]) * 100;
    if len(parts) == 2 {
        cents += int(parts[1].ljust(2, "0"));
    }
    return cents;
}
