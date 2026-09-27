# Test the app with the Ann Arbor dataset

From this repository in PowerShell:

```powershell
wsl --exec bash scripts/dataset-test.sh
```

The launcher copies the current app into a fresh WSL temporary workspace and
imports all 841 source-backed places during warm-up at http://localhost:8300.
Wait for `Dataset feed ready` before opening the app.
It generates fictional offers for unrestricted food venues, using ordinary
business names and offer copy in the UI. Internal `is_demo` flags and
`dataset-test:` source identifiers retain the fixture provenance.
The existing offer feed, filters, favorites and claims use these test records.
Prices range from $3 to $15, with scheduled, sold-out and vegetarian fixtures.
Offers expire seven days after import. No real business participation is implied.

Verified September 27: 841 places and 495 sample offers loaded through the
web API, 47 results for a combined $3–$6/vegetarian/now filter, repeat reads without
duplicates, guest claim rejection, and authenticated claim/retry/cancellation.
The project check passed with existing warnings; 18 place tests passed.
Receipt: `data/simulation/verification/app-dataset.json`.

The full place catalog is available through `list_places` (500 per page maximum)
and `nearby_places`. The current UI displays food offers, not a directory of all
841 places. OpenStreetMap source links and ODbL attribution stay in the catalog.
For raw HTTP calls to `list_places`, pass both `limit` and `offset` explicitly;
this runtime does not reliably supply omitted numeric defaults over HTTP.

**Local test sign-in:** choose a synthetic U-M uniqname and name in the ordinary
signup screen. No email is sent. Read the generated code from the printed test
workspace's `.jac/test-outbox/latest.json`, then enter it in the app. This local
delivery fixture is applied only to the copied test app. Never deploy that copy.
These accounts are fictional fixtures, not proof of a real verified inbox.

The launcher prints its isolated workspace path. It leaves the workspace and
database available after Ctrl+C. Running the launcher again creates a fresh
store; it never resets the existing phone demo or production source files.
To resume the retained store, in WSL Bash:

```bash
cd /tmp/m-local-dataset-test.REPLACE_WITH_PRINTED_SUFFIX
MLOCAL_DEMO_MODE=1 JAC_CACHE_HOME="$HOME/.cache/m-local" ~/.local/share/m-local/runtimes/0.37.23/jac run --no-dev --host 127.0.0.1 --port 8300
```

Use `MLOCAL_DATASET_PORT` to select another port. Set `MLOCAL_DATASET_OFFERS=0`
to load only place records. That mode leaves the ordinary small demo offer seed
in place because places alone do not populate the offer feed.

The test copy has no separate import HTTP endpoint. A single warm-up feed request
loads the fixed local dataset through the existing trusted place importer and
typed fixture constructors. This uses the server's graph root and serialization
context; ordinary CLI imports do not share both of those conventions. Optional
precomputed Nearby edges are omitted; nearby queries still calculate distances.
It does not copy existing accounts, claims or credentials.

Presentation update: existing dataset stores migrate display names, offer titles,
descriptions and terms once, without replacing IDs, accounts, inventory or claims.
Previously saved claim snapshots retain their original terms.
