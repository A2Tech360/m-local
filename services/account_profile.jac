"""Private account preferences; identity and role stay server controlled."""
import from services.session { current_session }
import from services.onboarding { verified_account }
import from services.onboarding_support { save_account_name }

obj AccountProfileView {
    has ok: bool = False, message: str = "", display_name: str = "",
        email: str = "", role: str = "guest", email_verified: bool = False,
        is_demo: bool = False;
}

def _account_profile(message: str = "") -> AccountProfileView {
    session = current_session();
    if not session.authenticated {
        return AccountProfileView(message="Sign in to view your profile.");
    }
    account = verified_account(session.actor_id);
    return AccountProfileView(ok=True, message=message,
        display_name=session.display_name, email=str(account.get("email", "")),
        role=session.role, email_verified=session.email_verified, is_demo=session.is_demo);
}

def:protect get_account_profile() -> AccountProfileView {
    try {
        return _account_profile();
    } except Exception {
        return AccountProfileView(message="Could not load your profile. Please try again.");
    }
}

def:protect save_account_profile(display_name: str) -> AccountProfileView {
    try {
        session = current_session();
        if not session.authenticated {
            return AccountProfileView(message="Sign in before editing your profile.");
        }
        _ = save_account_name(session.actor_id, display_name);
        return _account_profile("Profile saved.");
    } except ValueError as error {
        return AccountProfileView(message=str(error));
    } except Exception {
        return AccountProfileView(message="Could not save your profile. Please try again.");
    }
}
