#!/data/data/com.termux/files/usr/bin/bash
# Debug session for dsh web on Termux. Runs dsh web, records everything it prints,
# and leaves a redacted report in the phone's Download folder, so you can share
# the .txt directly from the Android file manager or from this chat.
#
#   bash termux-debug/dsh-debug.sh
#
# Output: /storage/emulated/0/Download/dsh-log/<session>/
#   report.txt     system and version info, file NAMES only, last startup logs
#   terminal.txt   everything dsh web printed (redacted)
# Nothing is uploaded anywhere. Stop dsh with Ctrl+C; the report is written on exit.
#
# Redaction removes API keys, bearer/JWT tokens, token= query values and e-mail
# addresses. It does NOT copy ~/.codex/auth.json or any credentials file.
#
# Overrides (for testing): DSH_DEBUG_OUT, DSH_HOME_DIR, DSH_BIN.

set -u

OUT_ROOT="${DSH_DEBUG_OUT:-/storage/emulated/0/Download/dsh-log}"
DSH_HOME_DIR="${DSH_HOME_DIR:-$HOME/.dsh}"
DSH_BIN="${DSH_BIN:-dsh}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SESSION="$OUT_ROOT/session-$STAMP"
RAW="$HOME/.dsh-debug-raw-$STAMP.txt"   # unredacted, stays inside Termux and is deleted

if [ ! -d "$(dirname "$OUT_ROOT")" ]; then
  echo "Download folder not reachable. Run this once, then start again:"
  echo "  termux-setup-storage"
  exit 1
fi
mkdir -p "$SESSION" || { echo "could not create $SESSION"; exit 1; }
: > "$RAW"

redact() {
  sed -E \
    -e 's/(sk-)[A-Za-z0-9_-]{6,}/\1REDACTED/g' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1REDACTED/g' \
    -e 's/(token=)[A-Za-z0-9_.-]+/\1REDACTED/g' \
    -e 's/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.?[A-Za-z0-9_-]*/JWT_REDACTED/g' \
    -e 's/([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/EMAIL_REDACTED/g' \
    -e 's/("?(access_token|refresh_token|id_token|api_key|apiKey|DEEPSEEK_API_KEY|OPENAI_API_KEY)"?[[:space:]]*[:=][[:space:]]*"?)[^"[:space:],}]+/\1REDACTED/g'
}

write_report() {
  local r="$SESSION/report.txt"
  {
    echo "dsh debug report  $(date)"
    echo "=================================================="
    echo "Device: $(getprop ro.product.model 2>/dev/null) / Android $(getprop ro.build.version.release 2>/dev/null) (sdk $(getprop ro.build.version.sdk 2>/dev/null))"
    echo "Arch: $(uname -m 2>/dev/null)"
    echo "node: $(node -v 2>/dev/null || echo missing)   npm: $(npm -v 2>/dev/null || echo missing)   pnpm: $(pnpm -v 2>/dev/null || echo missing)"
    echo "dsh: $($DSH_BIN --version 2>/dev/null | head -1 || echo missing)"
    echo "rg: $(command -v rg >/dev/null 2>&1 && rg --version | head -1 || echo missing)"
    echo
    echo "--- Files in $DSH_HOME_DIR (names and sizes only) ---"
    find "$DSH_HOME_DIR" -maxdepth 3 -printf '%M %s %p\n' 2>/dev/null | sed "s#$HOME#~#"
    echo
    echo "--- Files in ~/.codex (names and sizes only; auth.json is never copied) ---"
    ls -la "$HOME/.codex" 2>&1 | sed "s#$HOME#~#"
    echo
    echo "--- Latest startup logs written by dsh (redacted) ---"
    local latest
    for latest in $(ls -t "$DSH_HOME_DIR"/logs/startup-*.log 2>/dev/null | head -3); do
      echo "## $(basename "$latest")"
      redact < "$latest" | head -200
      echo
    done
    echo "--- Plugin update state (redacted) ---"
    for f in "$DSH_HOME_DIR"/dsh-chatgpt-sub/*.json; do
      [ -f "$f" ] || continue
      echo "## $(basename "$f")"
      redact < "$f"
      echo
    done
  } > "$r" 2>&1
  redact < "$r" > "$r.tmp" && mv "$r.tmp" "$r"
}

finish() {
  trap - EXIT INT TERM
  redact < "$RAW" > "$SESSION/terminal.txt"
  rm -f "$RAW"
  write_report
  echo
  echo "Debug files saved in: $SESSION"
  echo "  - report.txt"
  echo "  - terminal.txt"
  echo "Open the Download folder, then share those files here."
}
trap finish EXIT INT TERM

echo "Session: $SESSION"
echo "Starting dsh web. Reproduce the problem, then press Ctrl+C here."
echo
"$DSH_BIN" web --no-open 2>&1 | tee -a "$RAW"
