#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"
port="${MLOCAL_INSIGHTS_PORT:-8400}"
api=$((port + 1))
demo="${MLOCAL_INSIGHTS_DIR:-$(mktemp -d /tmp/m-local-insights-demo.XXXXXX)}"
git ls-files | tar -cf - -T - | tar -xf - -C "$demo"
unset JAC_DB_URL MLOCAL_ONBOARDING_DIR MLOCAL_MERCHANT_OWNERS MLOCAL_DEMO_STUDENTS
cd "$demo"
wait_up() {
    for _ in $(seq 1 240); do
        if curl -s -o /dev/null "http://127.0.0.1:$api/functions" && curl -s -o /dev/null "http://localhost:$port/"; then return 0; fi
        sleep 1
    done
    echo "The app did not start; see $demo/server.log" >&2
    exit 1
}
if [[ ! -f .jac/qr-demo-accounts.json ]]; then
    "$JAC_BIN" run --dev --host 127.0.0.1 --port "$port" < /dev/null > server.log 2>&1 &
    first=$!
    wait_up
    python3 scripts/provision-demo.py --api "http://localhost:$api"
    kill "$first" 2>/dev/null || true
    sleep 3
fi
python3 - <<'PY'
from pathlib import Path
p = Path('services/foryou.jac')
text = p.read_text()
if 'ensure_local_activity' not in text:
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    text = text.replace('import from services.taste_sandbox', 'import from tools.simulation.local_activity { ensure_local_activity }\nimport from services.taste_sandbox', 1)
    marker = 'def:pub prepare_demo_catalog() -> int {\n    _ensure_seed();\n'
    assert text.count(marker) == 1
    text = text.replace(marker, marker + '    ensure_local_activity();\n', 1)
    assert 'ensure_local_activity();' in text and text.count('import from tools.simulation.local_activity') == 1
    p.write_text(text.replace('\n', '\r\n') if crlf else text)
PY
set -a
. ./.jac/qr-demo.env
MLOCAL_DEMO_MODE=1
set +a
echo "Insights demo workspace: $demo"
"$JAC_BIN" run --dev --host 127.0.0.1 --port "$port" < /dev/null > server.log 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
wait_up
echo "Simulating local activity through the real claim and redeem code. This takes a few minutes."
python3 - "$api" <<'PY'
import json, sys, urllib.request
request = urllib.request.Request('http://127.0.0.1:' + sys.argv[1] + '/function/prepare_demo_catalog', b'{}', {'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=1500) as response:
    result = json.load(response)
assert result['ok'], result
print('Catalog ready.')
PY
grep -h "Local activity ready" server.log | tail -1 || true
echo "Open http://localhost:$port and sign in as a restaurant from $demo/.jac/qr-demo-accounts.json (keep that file private)."
echo "Stop with Ctrl+C."
wait "$server"
