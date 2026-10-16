#!/data/data/com.termux/files/usr/bin/bash
# Fix for "rename is not defined" in dsh's installed packages on Termux.
#
# Some builds of @deepseek-ai/dsh call rename() without importing it. The
# session writer does this when it creates a new session (materializePosix in
# dsh-session-persistence-jsonl), so the turn fails. This script adds
# `import { rename } from "node:fs/promises";` to each ES module under the
# global dsh install (and ~/.dsh) that calls rename() without binding it.
#
# Only files that already use import statements are changed, and only when
# rename is not declared in the file. The original is kept as <file>.orig.
# Running the script again is safe. Re-run it after updating dsh.
#
# Usage:  bash termux-verify/fix-rename-import.sh
set -eu

MARK='termux-verify/fix-rename-import.sh'
GLOBAL_NM="${DSH_GLOBAL_NM:-$(npm root -g)}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
LINE='import { rename } from "node:fs/promises"; // '"$MARK"

ROOTS=""
[ -d "$GLOBAL_NM/@deepseek-ai/dsh" ] && ROOTS="$ROOTS $GLOBAL_NM/@deepseek-ai/dsh"
[ -d "$HOME_DIR/.dsh/profiles/node_modules/@deepseek-ai" ] && ROOTS="$ROOTS $HOME_DIR/.dsh/profiles/node_modules/@deepseek-ai"
if [ -z "$ROOTS" ]; then
  echo "dsh not found under $GLOBAL_NM or $HOME_DIR/.dsh (is dsh installed?)"
  exit 1
fi

changed=0
# Files that call rename( with a prefix that is not "." (so not a method call).
FILES="$(grep -rl --include='*.js' --include='*.mjs' -E '(^|[^.A-Za-z0-9_$"'\''`-])rename\(' $ROOTS 2>/dev/null | sort -u || true)"
for f in $FILES; do
  grep -q "$MARK" "$f" && { echo "already patched: $f"; continue; }
  # Only ES modules: the new line is an import, so the file must already use imports.
  grep -q '^import ' "$f" || continue
  # Skip if rename is already imported, or declared at top level.
  if grep -E '^import .*\brename\b' "$f" >/dev/null 2>&1; then continue; fi
  if grep -E '^(export )?(async )?(function|const|let|var|class) +rename\b' "$f" >/dev/null 2>&1; then continue; fi
  # Only call sites that are not a method definition like "rename(x) {" or "async rename(x) {".
  if ! grep -E '(await |return |= |\(|!|&&|\? |: |, )rename\(' "$f" >/dev/null 2>&1; then continue; fi
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
  { printf '%s\n' "$LINE"; cat "$f.orig"; } > "$f"
  echo "patched: $f"
  changed=$((changed + 1))
done
echo "rename import fix: $changed file(s) changed."
