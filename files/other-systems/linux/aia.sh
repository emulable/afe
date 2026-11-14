#!/usr/bin/env bash
# AI Audio on Linux: starts aia.py with a Python that lives inside the kit.
# UNTESTED on Linux (written on Windows). See the notes at the top of aia.py.
#
#   ./aia.sh list
#   ./aia.sh install recommended
#   ./aia.sh start narrate my-document.pdf
#   ./aia.sh stop
#
# Nothing is installed system-wide: uv, its Pythons and its caches all go into the kit folder.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$ROOT/tools/_bin"
mkdir -p "$BIN"

export UV_PYTHON_INSTALL_DIR="$ROOT/python"
export UV_CACHE_DIR="$ROOT/.cache/uv"
export UV_PYTHON_PREFERENCE="only-managed"
export PATH="$BIN:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found: downloading a private copy into $BIN"
    # The official installer, told to put uv in the kit and to leave the shell profile alone.
    curl -LsSf https://astral.sh/uv/0.12.5/install.sh | env UV_INSTALL_DIR="$BIN" UV_NO_MODIFY_PATH=1 sh
fi

exec uv run --no-project --python 3.12 "$HERE/aia.py" "$@"
