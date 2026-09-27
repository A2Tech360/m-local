"""Graph and transfer types for reviewed, location-specific access context."""

import from services.models { Location }


class ContextValidationError(Exception) {}


node ContextNotice {
    # Source records are public to read; only the owner/system may refresh them.
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
    has source_id: str,
        external_id: str,
        version: str,
        summary: str,
        publisher: str,
        source_url: str,
        checked_at: float,
        valid_from: float,
        valid_until: float,
        is_demo: bool = False,
        entrance_instruction: str = "",
        original_evidence: dict[str, any] = {},
        normalized_evidence: dict[str, any] = {};
}


edge Affects: ContextNotice --> Location {
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
}


obj AccessNoticeView {
    has id: str = "",
        summary: str = "",
        publisher: str = "",
        source_url: str = "",
        checked_at: float = 0.0,
        valid_from: float = 0.0,
        valid_until: float = 0.0,
        state: str = "needs_recheck",
        is_demo: bool = False,
        entrance_instruction: str = "";
}


obj AccessContextView {
    has state: str = "none",
        notices: list[AccessNoticeView] = [];
}
