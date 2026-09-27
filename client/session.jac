"""Use the runtime-owned session; roles and merchant membership come from Jac."""
import from "@jac/runtime" { jacLogout, jacSetToken }
import from ..services.session { current_session, SessionView }

async def:pub loadSession() -> SessionView {
    return await current_session();
}

def:pub signOut() {
    jacLogout();
}

async def:pub acceptEmailToken(token: str) -> SessionView {
    if not token { raise Exception("Verification did not return a session."); }
    jacSetToken(token);
    return await current_session();
}
