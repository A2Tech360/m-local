#!/usr/bin/env bash
# An independent, persistent demo store in this checkout. No existing stores reset.
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"
state="$PROJECT_ROOT/.jac/phone-share"
mkdir -p "$state"
# Native Linux storage avoids very slow compiler/dependency I/O across /mnt/c.
# A stable per-checkout directory keeps this demo's database across restarts.
key="$(printf '%s' "$PROJECT_ROOT" | sha256sum | cut -c1-16)"
demo="$HOME/.local/share/m-local/phone-demos/$key"
mkdir -p "$demo/scripts"
tar -cf - main.jac theme.jac jac.toml .jac-version services client scripts/provision-demo.py scripts/enable-demo-students.py | tar -xf - -C "$demo"
printf '%s\n' "$demo" > "$state/runtime-path.txt"
cd "$demo"
app_pid=''
cleanup() {
    if [[ -n "$app_pid" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM
start_app() {
    "$JAC_BIN" run --no-dev --host 127.0.0.1 --port 8200 &
    app_pid=$!
}
wait_ready() {
    for ((attempt = 0; attempt < 300; attempt++)); do
        [[ ! -f "$state/stop" ]] || exit 0
        kill -0 "$app_pid" 2>/dev/null || { wait "$app_pid"; exit 1; }
        if curl -fsS http://127.0.0.1:8200/ -o /dev/null 2>/dev/null; then return; fi
        sleep 2
    done
    echo 'App startup timed out. See .jac/phone-share/server.log.' >&2
    exit 1
}
if [[ -f "$PROJECT_ROOT/.jac/onboarding.env" ]]; then source "$PROJECT_ROOT/.jac/onboarding.env"; fi
if [[ -f .jac/qr-demo.env ]]; then
    python3 scripts/enable-demo-students.py --state-dir .jac
    source .jac/qr-demo.env
fi
start_app
wait_ready
if [[ ! -f .jac/qr-demo-accounts.json ]]; then
    python3 scripts/provision-demo.py --api http://127.0.0.1:8200
    cleanup
    source .jac/qr-demo.env
    start_app
    wait_ready
fi
if [[ ! -f .jac/qr-demo.env ]]; then
    echo 'Demo account ownership file is missing. Restore qr-demo.env from this demo; do not reset its database.' >&2
    exit 1
fi
cp .jac/qr-demo-accounts.json "$state/accounts.json"
echo 'Phone demo ready. Private accounts: .jac/qr-demo-accounts.json'
touch "$state/ready"
while [[ ! -f "$state/stop" ]]; do
    kill -0 "$app_pid" 2>/dev/null || { wait "$app_pid"; exit 1; }
    sleep 2
done
