#!/usr/bin/env bash
set -Eeuo pipefail

# Backwards-compatible entry point. The implementation lives in install.sh
# so both legacy setup commands use the same OS checks and license gate.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/install.sh" "$@"