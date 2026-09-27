#!/usr/bin/env bash
# A persistent HTTPS identity for the laptop's existing, guarded Jac backend.
set -euo pipefail
umask 077
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
state="$HOME/.local/state/m-local/tailscale"
bin="$HOME/.local/share/m-local/tailscale/1.102.4"
socket="$state/tailscaled.sock"
mkdir -p "$state"
ts() { "$bin/tailscale" --socket="$socket" "$@"; }
case "${1:-status}" in
  login) exec "$bin/tailscale" --socket="$socket" up --hostname=mlocal --accept-dns=false --accept-routes=false --timeout=60s ;;
  publish) exec "$bin/tailscale" --socket="$socket" funnel --bg http://127.0.0.1:8765 ;;
  status) ts status; ts funnel status; exit ;;
  address) ts status --json | node --input-type=module -e 'let text="";for await(const part of process.stdin)text+=part;const state=JSON.parse(text);if(state.BackendState!=="Running"||!state.Self?.DNSName)process.exit(1);console.log("https://"+state.Self.DNSName.replace(/\.$/,""));'; exit ;;
  stop) touch "$state/stop"; exit ;;
  start) ;;
  *) echo 'Usage: bash scripts/stable-link.sh start|login|publish|status|address|stop' >&2; exit 2 ;;
esac
[[ -x "$bin/tailscaled" ]] || { echo 'Run bash scripts/setup-stable-link.sh first.' >&2; exit 2; }
exec 9>"$state/launcher.lock"
flock -n 9 || { echo 'The stable-link launcher is already running.'; exit 0; }
rm -f "$state/stop"
# The app is intentionally a separate process, so relinking never resets data.
node --input-type=module -e '
  const response=await fetch("http://127.0.0.1:8200/function/list_offers",{
    method:"POST",headers:{"content-type":"application/json"},body:"{}",signal:AbortSignal.timeout(15000)});
  const body=await response.json();
  if(!response.ok || !body.ok || !Array.isArray(body.data?.result)) throw new Error("Start the M-Local app on port 8200 first.");
  console.log("Backend ready; existing accounts and data are preserved.");
'
daemon_pid=''
gateway_pid=''
stop() {
  trap - EXIT INT TERM
  [[ -z "$gateway_pid" ]] || kill -TERM "$gateway_pid" 2>/dev/null || true
  [[ -z "$daemon_pid" ]] || kill -TERM "$daemon_pid" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap stop EXIT
trap 'exit 0' INT TERM
PORT=8765 MLOCAL_BACKEND_PORT=8200 MLOCAL_INGRESS=funnel node scripts/hosted-gateway.mjs &
gateway_pid=$!
"$bin/tailscaled" --tun=userspace-networking --statedir="$state" --socket="$socket" --port=0 >>"$state/daemon.log" 2>&1 &
daemon_pid=$!
echo 'Stable-link service running. Keep this process and the app running.'
echo 'First setup: login, then publish. Later starts retain the same address.'
while [[ ! -f "$state/stop" ]]; do
  kill -0 "$gateway_pid" 2>/dev/null && kill -0 "$daemon_pid" 2>/dev/null || exit 1
  sleep 2
done
