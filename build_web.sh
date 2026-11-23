#!/usr/bin/env bash
# Julia engine + game/game.c → game_wasm/game.js
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v emcc >/dev/null 2>&1; then
    echo "❌ emcc not in PATH — install Emscripten and run: source emsdk_env.sh"
    exit 1
fi

if [[ -n "${JULIA:-}" ]]; then
    read -ra JULIA_CMD <<< "$JULIA"
elif julia +1.11 --version &>/dev/null; then
    JULIA_CMD=(julia +1.11)
else
    JULIA_CMD=(julia)
fi

echo "Using: ${JULIA_CMD[*]} ($("${JULIA_CMD[@]}" --version))"
echo "=== compile_library.jl web ==="
"${JULIA_CMD[@]}" --project=. compile_library.jl web

echo ""
echo "✅ Web build complete. Serve and open index.html:"
echo "   python3 -m http.server"
echo "   http://localhost:8000/index.html"
