#!/data/data/com.termux/files/usr/bin/bash
# "dsh web debug": runs dsh web behind a logging proxy and records the session.
#
#   dsh-debug                                          start a debug session (after --install)
#   bash termux-debug/dsh-web-debug.sh                 same, without installing
#   bash termux-debug/dsh-web-debug.sh --install   creates the 'dsh-debug' command
#
# Layout while it runs:
#   browser -> http://127.0.0.1:3080 (proxy, logs everything) -> dsh web on 127.0.0.1:3180
#
# Every HTTP request and every WebSocket message that goes through the browser UI is
# written to events.log in the session folder, with secrets redacted. Nothing is
# uploaded. Output goes to Download/dsh-log/session-<date>/:
#   events.log    one line per request / WebSocket message (redacted)
#   terminal.txt  everything dsh web printed (redacted)
#   report.txt    versions, file NAMES in ~/.dsh and ~/.codex, startup logs (redacted)
#
# Stop with Ctrl+C. The report is written on exit.
#
# Overrides (for testing): DSH_DEBUG_OUT, DSH_HOME_DIR, DSH_BIN,
#                          DSH_DEBUG_PORT (proxy, default 3080),
#                          DSH_DEBUG_BACKEND_PORT (dsh, default 3180).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"

if [ "${1:-}" = "--install" ]; then
  # Creates a 'dsh-debug' command in Termux's bin folder. It is a plain executable,
  # so it works in any shell and cannot clash with aliases or functions.
  BIN_DIR="${PREFIX:-/data/data/com.termux/files/usr}/bin"
  WRAPPER="$BIN_DIR/dsh-debug"
  mkdir -p "$BIN_DIR" || { echo "could not create $BIN_DIR"; exit 1; }
  cat > "$WRAPPER" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec bash "$HERE/dsh-web-debug.sh" "\$@"
EOF
  chmod +x "$WRAPPER"
  # Remove the bashrc block written by an earlier version of this script.
  RC="$HOME/.bashrc"
  if [ -f "$RC" ] && grep -q '# >>> dsh web debug >>>' "$RC"; then
    cp "$RC" "$RC.bak-dsh-debug"
    sed -i '/# >>> dsh web debug >>>/,/# <<< dsh web debug <<</d' "$RC"
    echo "Removed the old 'dsh web debug' block from $RC (backup: $RC.bak-dsh-debug)."
  fi
  echo "Installed the command: dsh-debug"
  echo "Start a debug session with:  dsh-debug"
  exit 0
fi

OUT_ROOT="${DSH_DEBUG_OUT:-/storage/emulated/0/Download/dsh-log}"
DSH_HOME_DIR="${DSH_HOME_DIR:-$HOME/.dsh}"
DSH_BIN="${DSH_BIN:-dsh}"
PUBLIC_PORT="${DSH_DEBUG_PORT:-3080}"
BACKEND_PORT="${DSH_DEBUG_BACKEND_PORT:-3180}"
PROXY="$HERE/dsh-proxy.mjs"
STAMP="$(date +%Y%m%d-%H%M%S)"
SESSION="$OUT_ROOT/session-$STAMP"
RAW="$HOME/.dsh-debug-raw-$STAMP.txt"   # unredacted, stays inside Termux, deleted on exit
EVENTS="$SESSION/events.log"

die() { echo "error: $*" >&2; exit 1; }

[ -f "$PROXY" ] || die "proxy not found at $PROXY"
command -v node >/dev/null 2>&1 || die "node not installed (run install-termux.sh)"
if [ ! -d "$(dirname "$OUT_ROOT")" ]; then
  die "Download folder not reachable. Run 'termux-setup-storage' once, then start again."
fi
mkdir -p "$SESSION" 2>/dev/null || true
# The Download folder can be created but not writable (Android storage not mounted or
# permission revoked). Test a real write; if it fails, keep the logs inside Termux
# instead of losing them.
if ! { : > "$SESSION/.write-test"; } 2>/dev/null; then
  OUT_ROOT="$HOME/dsh-log"
  SESSION="$OUT_ROOT/session-$STAMP"
  EVENTS="$SESSION/events.log"
  mkdir -p "$SESSION" || die "could not create $SESSION"
  echo "WARNING: the Download folder is not writable. Logs go to $SESSION instead."
  echo "         Copy them later with: cp -r \"$SESSION\" /storage/emulated/0/Download/"
else
  rm -f "$SESSION/.write-test"
fi
: > "$RAW"

if node -e "require('net').connect($PUBLIC_PORT,'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))" 2>/dev/null; then
  die "port $PUBLIC_PORT is already in use. Stop the other dsh web first (Ctrl+C in its Termux session)."
fi

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
    echo "dsh web debug report  $(date)"
    echo "=================================================="
    echo "Device: $(getprop ro.product.model 2>/dev/null) / Android $(getprop ro.build.version.release 2>/dev/null) (sdk $(getprop ro.build.version.sdk 2>/dev/null))"
    echo "Arch: $(uname -m 2>/dev/null)"
    echo "Node platform: $(node -p "process.platform + '-' + process.arch" 2>/dev/null || echo missing)"
    echo "node: $(node -v 2>/dev/null || echo missing)   npm: $(npm -v 2>/dev/null || echo missing)   pnpm: $(pnpm -v 2>/dev/null || echo missing)"
    echo "dsh: $("$DSH_BIN" --version 2>/dev/null | head -1)"
    echo "rg: $(command -v rg >/dev/null 2>&1 && rg --version | head -1 || echo missing)"
    echo "events: $(grep -c ' HTTP ' "$EVENTS" 2>/dev/null) HTTP lines, $(grep -c ' WS ' "$EVENTS" 2>/dev/null) WebSocket frames, $(grep -c ' HTTP-ERR ' "$EVENTS" 2>/dev/null) HTTP errors"
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

PIDS=""
cleanup_done=0
finish() {
  [ "$cleanup_done" -eq 1 ] && return
  cleanup_done=1
  trap - EXIT INT TERM
  for p in $PIDS; do kill "$p" 2>/dev/null; done
  sleep 1
  redact < "$RAW" > "$SESSION/terminal.txt" 2>/dev/null
  rm -f "$RAW"
  write_report
  echo
  echo "Debug session saved in: $SESSION"
  echo "  - events.log    (every request and WebSocket message)"
  echo "  - terminal.txt  (dsh output)"
  echo "  - report.txt    (versions and file names)"
  echo "Open the Download folder and share those files here."
}
trap finish EXIT INT TERM

echo "Session: $SESSION"

# 1. dsh web on the internal port (its output goes to the raw file, tailed on screen)
# rename-trap.cjs logs the file and line of any dsh code that calls rename() without
# importing it (the "rename is not defined" turn error), then runs the real rename.
NODE_OPTIONS="${NODE_OPTIONS:-} --require $HERE/rename-trap.cjs" "$DSH_BIN" web --port "$BACKEND_PORT" --no-open >> "$RAW" 2>&1 &
PIDS="$PIDS $!"
tail -n +1 -F "$RAW" 2>/dev/null &
PIDS="$PIDS $!"

# 2. Wait for dsh to print its login URL (with token)
TOKEN_LINE=""
for _ in $(seq 1 120); do
  TOKEN_LINE="$(grep -o 'token=[A-Za-z0-9_.-]*' "$RAW" 2>/dev/null | head -1)"
  [ -n "$TOKEN_LINE" ] && break
  sleep 1
done
[ -n "$TOKEN_LINE" ] || { echo "dsh web did not start in 120 s. See the messages above."; exit 1; }

# 3. Logging proxy on the public port
node "$PROXY" --listen "$PUBLIC_PORT" --target "$BACKEND_PORT" --log "$EVENTS" &
PIDS="$PIDS $!"
sleep 2

echo
echo "================================================================"
echo " Debug mode ON. Open this URL in the phone browser:"
echo "   http://127.0.0.1:$PUBLIC_PORT/?$TOKEN_LINE"
echo " Reproduce the problem, then press Ctrl+C here."
echo "================================================================"
echo

# Keep the session alive until the backend or the user stops it
wait
