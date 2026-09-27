"""Private, reviewable business applications. No public listing or merchant grant."""
import os;
import from services.email_codes { store }
import from services.website_import { collect_website }
import from services.onboarding_support { read_draft, persist_draft }
import from services.session { _actor_id }
import from services.onboarding { verified_account }

obj BusinessDraftView {
    has ok: bool = False, message: str = "", name: str = "", cuisine: str = "",
        description: str = "", address: str = "", website: str = "", menu_text: str = "",
        menu_url: str = "", image_url: str = "", status: str = "draft",
        image_urls: list[str] = [], menu_urls: list[str] = [], sources: list[str] = [],
        ai_used: bool = False;
}

def _draft_view(raw: dict[str, any], message: str = "") -> BusinessDraftView {
    return BusinessDraftView(ok=True, message=message,
        name=str(raw.get("name", "")), cuisine=str(raw.get("cuisine", "")),
        description=str(raw.get("description", "")), address=str(raw.get("address", "")),
        website=str(raw.get("website", "")), menu_text=str(raw.get("menu_text", "")),
        menu_url=str(raw.get("menu_url", "")), image_url=str(raw.get("image_url", "")),
        status=str(raw.get("status", "draft")),
        image_urls=raw.get("image_urls", []) as list[str],
        menu_urls=raw.get("menu_urls", []) as list[str],
        sources=raw.get("sources", []) as list[str]);
}

def:protect get_business_draft() -> BusinessDraftView {
    if not verified_account(_actor_id()) {
        return BusinessDraftView(message="Verify an email address to create a business profile.");
    }
    return _draft_view(read_draft(_actor_id()));
}

def:protect import_business_website(website: str) -> BusinessDraftView {
    if not verified_account(_actor_id()) {
        return BusinessDraftView(message="Verify an email address before importing a website.");
    }
    try {
        store().reserve_import(_actor_id());
        raw = collect_website(website);
        view = _draft_view(raw, "Website details imported. Review each field before saving.");
        if os.environ.get("MLOCAL_IMPORT_MODEL", "") {
            try {
                import from services.business_ai { extract_business }
                facts = extract_business(str(raw.get("text", "")));
                view.name = facts.name[:160] or view.name;
                view.cuisine = facts.cuisine[:120] or view.cuisine;
                view.description = facts.description[:1000] or view.description;
                view.address = facts.address[:500] or view.address;
                view.menu_text = facts.menu_text[:4000] or view.menu_text;
                view.ai_used = True;
                view.message = "AI organized the website details. Check the facts and menu prices before saving.";
            } except Exception {
                view.message = "Website details imported. AI was unavailable; review or fill the remaining fields.";
            }
        }
        return view;
    } except ValueError as e {
        return BusinessDraftView(message=str(e));
    } except Exception {
        return BusinessDraftView(message="Could not read this website. Check the address or enter the details manually.");
    }
}

def:protect save_business_draft(name: str, cuisine: str, description: str, address: str,
    website: str, menu_text: str, menu_url: str, image_url: str, confirmed: bool) -> BusinessDraftView {
    if not confirmed {
        return BusinessDraftView(message="Confirm you may represent this business and use the selected content.");
    }
    try {
        raw = persist_draft(_actor_id(), {"name": name, "cuisine": cuisine, "description": description,
            "address": address, "website": website, "menu_text": menu_text, "menu_url": menu_url, "image_url": image_url});
        return _draft_view(raw, "Business profile saved for review. Publishing and restaurant access remain pending.");
    } except ValueError as e {
        return BusinessDraftView(message=str(e));
    } except Exception {
        return BusinessDraftView(message="Could not save your business profile. Your entries are kept; please retry.");
    }
}
