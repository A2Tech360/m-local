"""Exercise the real aggregate-only HTML exporter in an independent offline browser.

Run from the repository root with Windows Python: python tests/analytics/test_recap_browser.py
The fixture is generated in a temporary directory and never touches app data.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile


def main() -> None:
    from playwright.sync_api import sync_playwright

    root = Path(__file__).resolve().parents[2]
    keys = "claims redemptions unique_customers returning_customers value_cents savings_cents savings_known cohort_redeemed cancelled expired pending unknown_outcomes".split()
    frames = []
    for day in range(8):
        totals = dict.fromkeys(keys, 0)
        totals.update(claims=day * 2, redemptions=day, cohort_redeemed=day,
                      expired=day, value_cents=day * 600,
                      unique_customers=min(day, 2), returning_customers=int(day > 2))
        daily = dict.fromkeys(keys, 0)
        daily.update(redemptions=int(day > 0), claims=2 if day else 0)
        frames.append(dict(day=day, date=f"2026-09-{20+day}", daily=daily,
                           totals=totals, offers=[dict(title='<img src=x onerror="window.PWNED=1">',
                                                       redemptions=day, value_cents=day*600,
                                                       customer_id="SECRET-ACCOUNT")] if day else []))
    data = dict(ok=True, business_name="Fixture café", is_demo=True, period_days=7,
                start_date="2026-09-21", end_date="2026-09-27", as_of=1790553600,
                coverage_start_date="2026-09-21", warnings=[], frames=frames,
                actor_id="SECRET-ROOT", qr_token="SECRET-QR")
    script = "import {normalizeInsights,buildRecapHtml} from './client/insights-support.mjs'; let input=''; for await (const chunk of process.stdin) input+=chunk; process.stdout.write(buildRecapHtml(normalizeInsights(JSON.parse(input))));"
    built = subprocess.run(["node", "--input-type=module", "-e", script], cwd=root,
                           input=json.dumps(data), text=True, capture_output=True, check=True)
    assert "SECRET-" not in built.stdout
    with tempfile.TemporaryDirectory(prefix="m-local-recap-") as folder:
        artifact = Path(folder) / "recap.html"
        artifact.write_text(built.stdout, encoding="utf-8")
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True, channel="chrome")
            page = browser.new_page(viewport={"width": 1280, "height": 900}, reduced_motion="reduce")
            errors: list[str] = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.route("http://**/*", lambda route: route.abort())
            page.route("https://**/*", lambda route: route.abort())
            page.goto(artifact.as_uri())
            assert page.locator("#redemptions").inner_text() == "7"
            assert page.locator("#offers img").count() == 0
            assert page.evaluate("window.PWNED || null") is None
            page.get_by_role("button", name="Reset", exact=True).click()
            assert page.locator("#redemptions").inner_text() == "0"
            assert page.locator("#offers").inner_text() == "Redeemed offers will appear here."
            page.locator("#seek").fill("2")
            assert page.locator("#redemptions").inner_text() == "2"
            assert page.locator("#returning_customers").inner_text() == "0"
            assert page.locator("#maximum").inner_text() == "Chart scale: 0 to 2 redemptions"
            page.get_by_role("button", name="Play period", exact=True).click()
            page.wait_for_function("document.getElementById('redemptions').textContent === '7'")
            assert page.get_by_role("button", name="Play period", exact=True).is_visible()
            page.set_viewport_size({"width": 390, "height": 844})
            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
            page.get_by_role("button", name="Reset", exact=True).click()
            page.locator("#seek").focus()
            page.keyboard.press("ArrowRight")
            assert page.locator("#redemptions").inner_text() == "1"
            page.get_by_role("button", name="Period totals", exact=True).click()
            assert page.locator("#redemptions").inner_text() == "7"
            assert not errors, errors
            browser.close()
    print("PASS: offline recap, reset/seek/play, cutoff metrics, hostile text, privacy, keyboard and 390px layout")


if __name__ == "__main__":
    main()
