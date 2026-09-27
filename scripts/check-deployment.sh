#!/usr/bin/env bash
# Build an archived candidate away from the live source and database.
set -euo pipefail
if [[ "${MLOCAL_BUILD_TIMED:-0}" != 1 ]]; then
    exec timeout --signal=TERM --kill-after=10s 540s env MLOCAL_BUILD_TIMED=1 bash "$0" "$@"
fi
archive="$1"
cache="$(realpath -m "$HOME/.cache/m-local")"
mkdir -p "$cache"
stage="$(mktemp -d "$cache/deploy-check-XXXXXXXX")"
cleanup() {
    [[ "$stage" == "$cache"/deploy-check-* && -d "$stage" ]] && rm -rf -- "$stage"
}
trap cleanup EXIT
tar -xf "$archive" -C "$stage"
cd "$stage"
source scripts/runtime.sh
"$JAC_BIN" install
bash scripts/check.sh
bash scripts/build.sh
echo 'Candidate check and build passed.'
