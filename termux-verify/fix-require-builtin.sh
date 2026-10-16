#!/data/data/com.termux/files/usr/bin/bash
# Fix for: "dsh: host preparation failed: No usable native binding found for
#           node-addon-require-builtin-android-arm64"
#
# node-addon-require-builtin ships native binaries only for desktop/server
# platforms. Termux (android-arm64) has none, so `dsh web` cannot boot.
# This replaces every copy of its lib/index.js inside the dsh install with a
# pure-JavaScript stub (termux-verify/stubs/...). The original file is kept as
# index.js.orig. Running it again is safe.
#
# Requires dsh to run with --expose-internals, which the lilyco installer sets
# in the dsh launcher shebang (install.sh step 7). This script checks that too.
#
# Usage:  bash termux-verify/fix-require-builtin.sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
STUB="$HERE/stubs/node-addon-require-builtin/lib/index.js"
ROOT="${DSH_ROOT:-$(npm root -g)/@deepseek-ai/dsh}"

[ -f "$STUB" ] || { echo "error: stub not found: $STUB"; exit 1; }
[ -d "$ROOT" ] || { echo "error: dsh not found at $ROOT (run the installer first)"; exit 1; }
# The addon may be nested inside dsh/node_modules or hoisted next to it, so search
# the whole node_modules tree that contains @deepseek-ai/dsh.
NM_BASE="$(dirname "$(dirname "$ROOT")")"

if [ -f "$ROOT/lib/bin.js" ] && ! head -1 "$ROOT/lib/bin.js" | grep -q -- "--expose-internals"; then
  echo "warning: $ROOT/lib/bin.js shebang lacks --expose-internals; dsh web may fail"
fi

count=0
while IFS= read -r dir; do
  f="$dir/lib/index.js"
  [ -f "$f" ] || continue
  if grep -q "termux-verify stub" "$f"; then
    echo "already stubbed: $dir"
    continue
  fi
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
  cp "$STUB" "$f"
  echo "stubbed: $dir"
  count=$((count + 1))
done < <(find "$NM_BASE" -type d -name node-addon-require-builtin -not -path '*/.cache/*')

echo "done: $count file(s) replaced under $ROOT"
echo "now run: dsh web"
