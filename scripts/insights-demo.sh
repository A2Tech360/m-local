#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"
port="${MLOCAL_INSIGHTS_PORT:-8400}"
api=$((port + 1))
demo="${MLOCAL_INSIGHTS_DIR:-$(mktemp -d /tmp/m-local-insights-demo.XXXXXX)}"
python3 scripts/insights-demo-guard.py "$demo" "$PROJECT_ROOT" "$port"
git ls-files | tar -cf - -T - | tar -xf - -C "$demo"
unset JAC_DB_URL MLOCAL_ONBOARDING_DIR MLOCAL_MERCHANT_OWNERS MLOCAL_DEMO_STUDENTS MLOCAL_HOSTED_DATASET
cd "$demo"
wait_up() {
    for _ in $(seq 1 240); do
        if ! kill -0 "$1" 2>/dev/null; then
            echo "The demo process exited; refusing to use another server. See $demo/server.log" >&2
            exit 1
        fi
        if curl -fsS -o /dev/null "http://127.0.0.1:$api/functions" 2>/dev/null && curl -fsS -o /dev/null "http://localhost:$port/" 2>/dev/null; then return 0; fi
        sleep 1
    done
    echo "The app did not start; see $demo/server.log" >&2
    exit 1
}
if [[ ! -f .jac/qr-demo-accounts.json ]]; then
    "$JAC_BIN" run --dev --host 127.0.0.1 --port "$port" < /dev/null > server.log 2>&1 &
    first=$!
    trap 'kill "$first" 2>/dev/null || true' EXIT
    wait_up "$first"
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
wait_up "$server"
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
python3 - "$api" <<'PY'
import json, sys, urllib.request
from pathlib import Path
api = 'http://127.0.0.1:' + sys.argv[1]
accounts = json.loads(Path('.jac/qr-demo-accounts.json').read_text())
names = {'merchant_leaf': ['Arbor Leaf Kitchen', 'Restaurant', 'business'], 'merchant_noodle': ['Maize Street Noodle Lab', 'Restaurant', 'business'],
         'student_a': ['Student A', 'Student', 'student'], 'student_b': ['Student B', 'Student', 'student']}
entries = []
for key, (name, role, audience) in names.items():
    body = json.dumps({'identity': {'type': 'email', 'value': accounts[key]['email']},
                       'credential': {'type': 'password', 'password': accounts[key]['password']}}).encode()
    with urllib.request.urlopen(urllib.request.Request(api + '/user/login', body, {'Content-Type': 'application/json'}), timeout=60) as response:
        reply = json.load(response)
    entries.append({'name': name, 'role': role, 'audience': audience, 'token': (reply.get('data') or reply)['token']})
folder = Path('assets/demo-login')
folder.mkdir(parents=True, exist_ok=True)
(folder / 'tokens.json').write_text(json.dumps(entries))
(folder / 'index.html').write_text("""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>M-Local local demo sign-in</title>
<style>body{font:16px/1.5 system-ui,sans-serif;background:#F9F6F0;color:#0B1F38;margin:0;padding:32px 20px}main{max-width:460px;margin:0 auto;display:grid;gap:12px}
h1{font-size:24px;margin:0}p{margin:0;color:#5F6B7A}button{font:700 16px system-ui,sans-serif;text-align:left;padding:16px;border:1px solid #DDD5C7;border-radius:14px;background:#fff;color:#0B1F38;cursor:pointer}
button span{display:block;font-weight:400;font-size:13px;color:#5F6B7A}button:focus-visible{outline:3px solid #02305C;outline-offset:3px}</style></head>
<body><main><h1>Local demo sign-in</h1><p>Test accounts for this local copy only. No email is sent. All activity here is simulated.</p><div id="list" style="display:grid;gap:12px"></div>
<button id="out">Sign out<span>Return to the welcome screen</span></button></main>
<script>
const list=document.getElementById('list');
fetch('tokens.json').then(r=>r.json()).then(entries=>{for(const entry of entries){const b=document.createElement('button');b.textContent=entry.name;const s=document.createElement('span');s.textContent=entry.role;b.append(s);
b.onclick=()=>{localStorage.clear();localStorage.setItem('jac_token',entry.token);localStorage.setItem('mlocal_audience',entry.audience);location.href='/';};list.append(b);}});
document.getElementById('out').onclick=()=>{localStorage.clear();location.href='/';};
</script></body></html>
""")
PY
echo "Open http://localhost:$port/static/assets/demo-login/index.html and pick an account. No email or code is needed."
echo "These test sign-ins exist only in $demo. Never deploy that folder."
echo "Stop with Ctrl+C."
wait "$server"
