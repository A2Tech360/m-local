"""Trusted local provisioning. No HTTP endpoint can write this mapping.

MLOCAL_MERCHANT_OWNERS is a server environment JSON object mapping restaurant
slug to the root_id returned by Jac's pre-provisioned account login. Never put
passwords or tokens in this map. Missing/invalid config grants no merchant role.
Changing a mapping requires a server restart and reassigns that restaurant.
"""

import os;
import json;
import from uuid { UUID }

def configured_owners(text: str) -> dict[str, str] {
    result: dict[str, str] = {};
    try {
        raw = json.loads(text);
        if not isinstance(raw, dict) {
            return result;
        }
        for (slug, actor) in raw.items() {
            if not isinstance(slug, str) or not isinstance(actor, str) or not slug {
                return {};
            }
            if str(UUID(actor)) != actor {
                return {};
            }
            result[slug] = actor;
        }
        # This slice permits one restaurant per merchant account.
        if len(set(result.values())) != len(result) {
            return {};
        }
        return result;
    } except Exception {
        return {};
    }
}

def merchant_owner(slug: str) -> str {
    return configured_owners(os.environ.get("MLOCAL_MERCHANT_OWNERS", "{}")).get(slug, "");
}
