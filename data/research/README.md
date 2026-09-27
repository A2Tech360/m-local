# Food-business contact research

Research date: September 27, 2026. This is a local research database, **not a live registration allowlist**. No businesses were contacted and no ownership permissions were changed.

## Results

| Measure | Result |
|---|---:|
| Food-related catalog listings represented | 516 |
| Listings with a catalog website | 378 |
| Distinct catalog website URLs checked | 373 |
| Listings without a website manually researched | 138 |
| Businesses with potentially relevant contact leads after basic exclusions | 157 |
| Distinct email addresses in that review queue | 185 |
| Businesses without a contact in that queue | 359 |
| Source-linked candidate rows retained, including rejected evidence | 362 |
| Rows excluded for another location, vendor, or placeholder | 27 |
| Verified business owners / enabled claims | **0 / 0** |

These are coverage counts, not an estimate of current operating businesses. The catalog contains stale businesses, duplicate/ambiguous entities, university outlets, chains, and concession stands. The review queue still includes shared inboxes, third-party leads, and identity questions. It is **not** a list of approved registration emails.

## Files to use

- `food-business-contacts.sqlite3`: SQLite database with all 516 listings, candidate contacts, source evidence, research notes, and structured review flags.
- `food-contact-review-queue.csv`: deduplicated business/email review queue with source links and a count of businesses sharing the address.
- `food-business-contacts.csv`: full export, including businesses without emails and excluded evidence.
- `food-research-summary.json`: machine-readable counts.
- `food-website-checks.jsonl`: resumable website checks, requested/final URLs, page hashes, extraction evidence, and retrieval failures.
- `manual-food-*.json`: manual research, including unresolved businesses and recovered websites. A `website` here is a research observation, not a trusted replacement for the catalog URL. Honor `rejected_identity_mismatch` and other negative findings.
- `contact-review-decisions.json`: independent review decisions for misleading contacts and uncertain business identities.

The database is a generated snapshot. Make research corrections in the input JSON or review decisions and rebuild it; do not hand-edit the SQLite export expecting those changes to survive a rebuild.

## Evidence and limitations

The website pass checked up to four linked public pages per distinct catalog URL, prioritizing contact, about, and location pages. It extracted visible email text, `mailto` links, and publicly obfuscated email links. It recorded blocked requests, unavailable robots files, timeouts, and missing pages. It did not bypass login or access restrictions, submit contact forms, send email, test mailbox delivery, or verify who controls an inbox. A missing result means no email found in the checked material, not that the business has no email.

Manual searches investigated the 138 missing-site records and selected failed website lookups. Published official contacts receive stronger provenance than directory-only leads. Automated site extraction remains source-review-required even when the catalog points to an apparently official domain. Domains can be stale, redirected, or compromised.

Important findings:

- Public business inboxes exist: [Frita Batidos](https://fritabatidos.com/ann-arbor/contact/), [Sava's](https://www.savasannarbor.com/contact), and [Baba Dari](https://babadari.com/page/contact-us) publish business contact addresses. Publication does not prove that only an owner can access them.
- Multi-location pages produce false matches. The research excludes other-city Chop House, Anna's House, Mr. Spots, and bb.q contacts. Corporate and shared local-group inboxes remain flagged.
- Business identity can change. [Local reporting says Isalita closed and its space was to become Mani Next Door](https://www.ecurrent.com/food/isalita-cantina-mexicana-closes-in-ann-arbor-to-turn-into-new-concept/). This is a review flag, not permission to assign the replacement business to an old email.
- Ginger Deli's public email evidence matches its Liberty Street listing, not the separate Plymouth Road catalog listing. The latter requires identity review.
- Alpha Koney Island's researched `alphakoneyisland.com` site represents Adrian, not the Ann Arbor catalog listing. Its negative identity finding must prevent reuse of that domain as verified evidence.
- University dining outlets need institutional authorization; they should not be treated as independently owned restaurants.

## Registration recommendation

Keep research evidence separate from approved claim recipients. Before enabling a business claim:

1. Review the exact business and location, current operating identity, source freshness, and the contact's intended role. An email domain match alone is insufficient.
2. Store approved recipients privately against a stable business ID. Treat approval as an explicit decision, separate from finding an email on a web page.
3. Require the registrant to prove control of an approved inbox using an expiring, single-use challenge bound to that business and account. Apply attempt limits and prevent concurrent/double claims.
4. For shared/corporate inboxes, disputed listings, transfers, and missing contacts, require a separate authority review. Inbox possession supports access verification; it does not establish legal ownership.
5. Enforce the binding on every server-side merchant operation and prevent name/website edits from switching the account to a different business.

The current application's self-service registration behavior is unchanged. This research alone does not close its business-association gap.

## Database use

Tables: `businesses`, `contact_candidates`, `research_notes`, `business_research_flags`, `metadata`.

Views: `contact_review_queue`, `unresolved_businesses`.

Every candidate has `ownership_verified = 0` and `claim_enabled = 0`, enforced with SQLite constraints. Review statuses are evidence classifications, not permission grants. Several source rows can support the same email.

```sql
SELECT name, email, contact_role, review_status, source_url
FROM contact_review_queue
ORDER BY name, email;

SELECT name, category, research_status
FROM unresolved_businesses
ORDER BY name;

SELECT b.name, f.flag, f.reason, f.source_url
FROM business_research_flags f JOIN businesses b USING (place_id)
ORDER BY b.name;
```

From the repository root, in PowerShell:

```powershell
python tools/research/food_contacts.py scan
python tools/research/food_contacts.py build
```

The scanner resumes the existing snapshot and does not re-fetch completed URLs. Start a separately named research snapshot for a future refresh rather than treating this date's results as perpetually current. Python dependencies: `requests` and `beautifulsoup4`.

Place identities and addresses derive from the existing OpenStreetMap catalog. © OpenStreetMap contributors, database licensed under [ODbL 1.0](https://www.openstreetmap.org/copyright). Preserve that attribution and the catalog's original source provenance when reusing the dataset. Website excerpts are short evidence snippets, not copies of the underlying sites.
