"""Test-only entry point, copied into an isolated HTTP fixture. Not imported by the app."""

import time;
import from services.promo { list_offers }
import from services.session { current_session }
import from services.context { get_access_context }
import from services.context_models { AccessContextView }

def:pub probe_context(location_id: str) -> AccessContextView {
    return get_access_context(location_id, time.time());
}
