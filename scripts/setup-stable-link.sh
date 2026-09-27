#!/usr/bin/env bash
# Unprivileged WSL install from Tailscale's official, checksum-verified archive.
set -euo pipefail
umask 077
version=1.102.4
expected=50748df1045e60b5b695f19f4c56b0da36c019948b440fb456b6584a50f0d8b9
install_dir="$HOME/.local/share/m-local/tailscale/$version"
mkdir -p "$install_dir"
if [[ ! -x "$install_dir/tailscaled" || ! -x "$install_dir/tailscale" ]]; then
    archive="$(mktemp)"
    trap 'rm -f "$archive"' EXIT
    curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_${version}_amd64.tgz" -o "$archive"
    actual="$(sha256sum "$archive" | cut -d ' ' -f1)"
    [[ "$actual" == "$expected" ]] || { echo 'Tailscale checksum verification failed.' >&2; exit 1; }
    tar -xzf "$archive" --strip-components=1 -C "$install_dir" \
        "tailscale_${version}_amd64/tailscale" "tailscale_${version}_amd64/tailscaled"
fi
"$install_dir/tailscale" version
