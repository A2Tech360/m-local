#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/runtime.sh"
ROOT_DIR="$PROJECT_ROOT"

run_in_isolated_copy() {
    local isolated_dir exit_code
    isolated_dir="$(mktemp -d "${TMPDIR:-/tmp}/m-local-test.XXXXXX")"
    tar --exclude='./.git' --exclude='./.jac' -cf - . | tar -xf - -C "$isolated_dir"
    set +e
    (cd "$isolated_dir" && "$@")
    exit_code=$?
    set -e
    rm -rf "$isolated_dir"
    return "$exit_code"
}
