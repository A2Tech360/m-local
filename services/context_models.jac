"""Graph and transfer types for reviewed, location-specific access context."""

import from services.models { Location }


class ContextValidationError(Exception) {}


node ContextNotice {
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
        original_evidence: dict = {},
        normalized_evidence: dict = {};
}


edge Affects: ContextNotice --> Location {}


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
