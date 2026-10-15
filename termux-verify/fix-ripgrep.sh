#!/data/data/com.termux/files/usr/bin/bash
# Fix for dsh's glob/grep tools on Termux.
#
# @vscode/ripgrep resolves the binary from a package named
# @vscode/ripgrep-<platform>-<arch>. On Termux, process.platform is "android",
# and no such package exists on npm, so the tools fail with
# "Could not find @vscode/ripgrep-android-arm64".
#
# This script installs Termux's own ripgrep (pkg install ripgrep) and creates a
# local shim package @vscode/ripgrep-android-arm64 whose bin/rg runs it.
# The shim lives in the global node_modules, next to dsh, so it survives
# dsh reinstalls. Running it again is safe.
#
# Usage:  bash termux-verify/fix-ripgrep.sh
set -eu

PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
RG_BIN="${RG_BIN:-$PREFIX_DIR/bin/rg}"
GLOBAL_NM="${DSH_GLOBAL_NM:-$(npm root -g)}"
SHIM="$GLOBAL_NM/@vscode/ripgrep-android-arm64"

if [ ! -x "$RG_BIN" ]; then
  echo "ripgrep not found at $RG_BIN, installing it with pkg..."
  pkg install -y ripgrep
fi
[ -x "$RG_BIN" ] || { echo "error: $RG_BIN still missing after pkg install ripgrep"; exit 1; }

mkdir -p "$SHIM/bin"
printf '%s\n' '{"name":"@vscode/ripgrep-android-arm64","version":"1.18.0","description":"Local shim: runs Termux ripgrep (termux-verify/fix-ripgrep.sh)","main":"bin/rg"}' > "$SHIM/package.json"
printf '#!/data/data/com.termux/files/usr/bin/sh\nexec "%s" "$@"\n' "$RG_BIN" > "$SHIM/bin/rg"
chmod +x "$SHIM/bin/rg"

echo "shim written: $SHIM -> $RG_BIN"
"$SHIM/bin/rg" --version | head -1
