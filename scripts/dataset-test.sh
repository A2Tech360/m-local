#!/usr/bin/env bash
# Dedicated local test app. Never copies credentials or touches another store.
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"
port="${MLOCAL_DATASET_PORT:-8300}"
demo="$(mktemp -d /tmp/m-local-dataset-test.XXXXXX)"
tar -cf - main.jac theme.jac jac.toml .jac-version services client scripts tools/simulation/app_dataset.jac tools/simulation/test_delivery.py data/simulation/places.json | tar -xf - -C "$demo"
for resource in public assets; do
    if [[ -d "$resource" ]]; then cp -r "$resource" "$demo/"; fi
done
export MLOCAL_DEMO_MODE=1
export MLOCAL_DATASET_OFFERS="${MLOCAL_DATASET_OFFERS:-1}"
# Do not inherit a live database, onboarding store or merchant grants.
unset JAC_DB_URL MLOCAL_ONBOARDING_DIR MLOCAL_MERCHANT_OWNERS MLOCAL_DEMO_STUDENTS
cd "$demo"
python3 - <<'PY'
from pathlib import Path
p = Path('main.jac')
p.write_text(p.read_text().replace('import from services.promo', 'import from services.places { list_places, nearby_places }\nimport from services.promo', 1))
p = Path('services/qr_catalog.jac')
text = p.read_text().replace('import from services.models', 'import from tools.simulation.app_dataset { ensure_test_dataset }\nimport from services.models', 1)
p.write_text(text.replace('def _ensure_seed {', 'def _ensure_seed {\n    ensure_test_dataset();', 1))
p = Path('services/email_codes.py')
p.write_text(p.read_text() + '\n' + Path('tools/simulation/test_delivery.py').read_text())
# Nearby queries compute distances directly; the feed does not use the optional
# materialized edges. Avoid building thousands of unused edges in this test app.
p = Path('services/places.jac')
text = p.read_text()
needle = 'if validated and materialize_nearby { _rebuild_nearby(list(indexed.values())); }'
assert text.count(needle) == 1
p.write_text(text.replace(needle, '# Nearby queries remain computed from catalog coordinates.'))
PY
echo "Dataset test workspace: $demo"
echo "Dataset test app: http://localhost:$port"
echo "Retained after exit for inspection; rerunning creates a fresh isolated store."
echo "TEST sign-in: email is captured locally in $demo/.jac/test-outbox/latest.json. No mail is sent."
"$JAC_BIN" run --no-dev --host 127.0.0.1 --port "$port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
python3 - "$port" <<'PY'
import json, sys, time, urllib.request, urllib.error
origin = 'http://127.0.0.1:' + sys.argv[1]
for attempt in range(180):
    try:
        urllib.request.urlopen(origin, timeout=2).close()
        break
    except (OSError, urllib.error.URLError):
        time.sleep(1)
else:
    raise SystemExit('Server did not start')
request = urllib.request.Request(origin + '/function/home_feed', b'{}', {'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=180) as response:
    result = json.load(response)
assert result['ok'], result
print('Dataset feed ready:', result['data']['result']['total_deals'], 'offers')
PY
"$JAC_BIN" db sql "ANALYZE anchors"
wait "$server_pid"
