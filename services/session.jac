"""Application identity comes only from the authenticated Jac request root."""

import from services.models { Restaurant }
import from services.qr_auth { merchant_owner }
import from services.qr_catalog { _ensure_seed }

obj SessionView {
    has authenticated: bool = False,
        actor_id: str = "",
        role: str = "guest",
        restaurant_id: str = "",
        display_name: str = "",
        is_demo: bool = False;
}

def _actor_id() -> str {
    # Anonymous requests use precisely the public commons root.
    return "" if jid(root) == jid(root.shared) else jid(root);
}

def _merchant_for_actor(actor: str) -> Restaurant | None {
    if not actor {
        return None;
    }
    for r in [root.shared -->[?:Restaurant]] {
        if merchant_owner(r.slug) == actor {
            return r;
        }
    }
    return None;
}

def:pub current_session() -> SessionView {
    _ensure_seed();
    actor = _actor_id();
    if not actor {
        return SessionView();
    }
    r = _merchant_for_actor(actor);
    if r is not None {
        return SessionView(authenticated=True, actor_id=actor, role="merchant",
            restaurant_id=jid(r), display_name=r.name, is_demo=r.is_demo);
    }
    return SessionView(authenticated=True, actor_id=actor, role="student", display_name="Student");
}
