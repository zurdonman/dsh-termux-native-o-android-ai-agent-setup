#!/data/data/com.termux/files/usr/bin/bash
# Fix for dsh's session writes on Termux.
#
# dsh locks a session's write handle with flock(2), through the package
# @deepseek-ai/node-addon-system. That package only accepts process.platform
# "linux" and "darwin". On Termux, process.platform is "android", so every turn
# that writes to an existing session fails with:
#   "This turn failed: flock is not supported on android-arm64"
#
# This script makes tryLockExclusive() return at once when the platform is
# "android", the same way dsh's browser worker already stubs it. Termux runs one
# dsh process at a time, so the lock is not needed. Caveat: two dsh processes
# writing the same session would no longer exclude each other.
#
# The original file is kept as flock.js.orig. Running the script again is safe.
# It must be run again after dsh is reinstalled or updated (install-termux.sh does this).
#
# Usage:  bash termux-verify/fix-flock.sh
set -eu

MARK='termux-verify/fix-flock.sh'
GLOBAL_NM="${DSH_GLOBAL_NM:-$(npm root -g)}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

# Every copy of the package: the global install and any copy under ~/.dsh.
FILES="$(find "$GLOBAL_NM" "$HOME_DIR/.dsh" -path '*node-addon-system/lib/flock.js' 2>/dev/null | sort -u || true)"
if [ -z "$FILES" ]; then
  echo "flock.js not found under $GLOBAL_NM or $HOME_DIR/.dsh (is dsh installed?)"
  exit 1
fi

for f in $FILES; do
  if grep -q "$MARK" "$f"; then
    echo "already patched: $f"
    continue
  fi
  if ! grep -q '^export async function tryLockExclusive(fd) {$' "$f"; then
    echo "error: unexpected layout in $f, not patched"
    exit 1
  fi
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
  sed -i '/^export async function tryLockExclusive(fd) {$/a\    if (process.platform === "android") return; // '"$MARK"': no kernel flock on Termux' "$f"
  echo "patched: $f"
done
echo "flock fix applied."
