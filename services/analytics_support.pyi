from typing import Any

def build_insights(records: list[dict[str, Any]], business_name: str,
                   is_demo: bool, days: int, now: float) -> dict[str, Any]: ...
