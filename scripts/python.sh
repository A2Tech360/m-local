#!/usr/bin/env bash
# Run Python fixtures with the same Jac import support as the application.
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"
JAC_PYTHON="${JAC_BIN}python"
if [[ ! -x "$JAC_PYTHON" ]]; then
    echo "Pinned jacpython is missing. Run bash scripts/setup.sh." >&2
    exit 2
fi
exec "$JAC_PYTHON" "$@"
