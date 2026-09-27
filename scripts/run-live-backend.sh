#!/usr/bin/env bash
set -euo pipefail
helpers="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd -- "$1" && pwd)"
revision="$2"
[[ "$revision" =~ ^[a-f0-9]{40}$ ]] || { echo 'Invalid backend revision' >&2; exit 2; }
key="$(printf '%s' "$source_root" | sha256sum | cut -c1-16)"
runtime="$HOME/.local/share/m-local/phone-demos/$key"
mkdir -p "$runtime"
# Removed/renamed source must not linger in the persistent runtime directory.
python3 "$helpers/sync-phone-source.py" "$source_root" "$runtime"
mkdir -p "$runtime/.jac"
printf '%s\n' "$revision" > "$runtime/.jac/hosted-revision"
cd "$source_root"
exec bash scripts/phone-server.sh
