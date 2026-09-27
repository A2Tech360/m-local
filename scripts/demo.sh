#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

port="${MLOCAL_PORT:-8000}"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/m-local-demo.XXXXXX")"
cleanup() {
    rm -rf "$fixture_dir"
}
trap cleanup EXIT INT TERM

cd "$ROOT_DIR"
tar --exclude='./.git' --exclude='./.jac' -cf - . | tar -xf - -C "$fixture_dir"
cd "$fixture_dir"
printf 'Starting an isolated M-Local demo store on http://127.0.0.1:%s\n' "$port"
"$JAC_BIN" run --dev --host 127.0.0.1 --port "$port"
