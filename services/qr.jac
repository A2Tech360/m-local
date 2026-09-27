"""Versioned opaque claim credential codec."""

import secrets;
import base64;
import re;

def new_qr_payload() -> str {
    return "mlocal:v1:" + secrets.token_urlsafe(32);
}

def valid_qr_payload(payload: str) -> bool {
    if len(payload) != 53 or re.fullmatch(r"mlocal:v1:[A-Za-z0-9_-]{43}", payload) is None {
        return False;
    }
    token = payload[10:];
    try {
        decoded = base64.urlsafe_b64decode(token + "=");
        canonical = base64.urlsafe_b64encode(decoded).decode("ascii").rstrip("=");
        return len(decoded) == 32 and canonical == token;
    } except Exception {
        return False;
    }
}
