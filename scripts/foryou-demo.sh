#!/usr/bin/env bash
# Lab only: run the For you demo (tastes, favorites, price ranges, food labels)
# in its own copy with its own store and random fictional companies.
# Usage: bash scripts/foryou-demo.sh [companies]   (default 30)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAC_BIN="${JAC_BIN:-$HOME/jachacks/bin/jac-0.37.23}"
RUN_DIR="${MLOCAL_LAB_DIR:-$HOME/jachacks/foryou-run}"
COMPANIES="${1:-30}"
mkdir -p "$RUN_DIR"
cd "$ROOT"
git ls-files | tar -cf - -T - | tar -xf - -C "$RUN_DIR"
cd "$RUN_DIR"
wait_up() {
    for _ in $(seq 1 240); do
        if curl -s -o /dev/null http://127.0.0.1:8001/functions && curl -s -o /dev/null http://localhost:8000/; then return 0; fi
        sleep 1
    done
    echo "The app did not start; see $RUN_DIR/server.log" >&2
    exit 1
}
pkill -f "jac-0.37.23 run --dev" 2>/dev/null || true
if [[ ! -f .jac/qr-demo-accounts.json ]]; then
    "$JAC_BIN" run --dev --host 127.0.0.1 --port 8000 < /dev/null > server.log 2>&1 &
    wait_up
    python3 scripts/provision-demo.py --api http://localhost:8001
    pkill -f "jac-0.37.23 run --dev" || true
    sleep 3
fi
set -a
. ./.jac/qr-demo.env
MLOCAL_DEMO_COMPANIES="$COMPANIES"
set +a
"$JAC_BIN" run --dev --host 127.0.0.1 --port 8000 < /dev/null > server.log 2>&1 &
wait_up
echo "Demo companies in the catalog: $(curl -s -X POST http://127.0.0.1:8001/function/prepare_demo_catalog -H 'Content-Type: application/json' -d '{}' | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['result'])")"
echo "Open http://localhost:8000  (test accounts: $RUN_DIR/.jac/qr-demo-accounts.json; keep that file private)"
echo "Stop with: pkill -f 'jac-0.37.23 run --dev'"
wait
