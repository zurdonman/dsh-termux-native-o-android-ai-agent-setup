#!/data/data/com.termux/files/usr/bin/bash
# Verifies the dsh installer on a REAL Android phone, running inside Termux.
#
# Usage (inside Termux):
#   bash termux-verify/verify.sh
#
# Optional environment variables:
#   INSTALLER_REPO  GitHub repo with install.sh   (default: lilyco-42/dsh-termux)
#   INSTALLER_REF   branch, tag or commit          (default: main)
#   DEEPSEEK_API_KEY  not required for install/boot checks; a dummy value is
#                     used if unset, so the installer does not prompt.
#
# Output (send these back):
#   ~/dsh-verify/report.txt   one line per step: PASS / FAIL + short detail
#   ~/dsh-verify/full.log     full output of every step (secrets redacted)
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$HOME/dsh-verify"
REPORT="$REPORT_DIR/report.txt"
LOG="$REPORT_DIR/full.log"
INSTALLER_REPO="${INSTALLER_REPO:-lilyco-42/dsh-termux}"
INSTALLER_REF="${INSTALLER_REF:-main}"
INSTALLER_URL="https://codeload.github.com/${INSTALLER_REPO}/tar.gz/refs/heads/${INSTALLER_REF}"

mkdir -p "$REPORT_DIR"
: > "$REPORT"
: > "$LOG"

say()   { echo "$*" | tee -a "$LOG"; }
record(){ echo "[$1] $2 $3" | tee -a "$REPORT" "$LOG"; }

# run <name> <command...> : output goes to the log only; result is PASS/FAIL
run() {
  local name="$1"; shift
  say "=== STEP: $name ($(date +%H:%M:%S)) ==="
  "$@" >> "$LOG" 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    record "$name" PASS "rc=0"
  else
    record "$name" FAIL "rc=$rc"
    echo "--- last 25 lines of full.log for $name ---" | tee -a "$REPORT" "$LOG" >/dev/null
    tail -n 25 "$LOG" >> "$REPORT"
  fi
  return "$rc"
}

say "dsh-termux verification started $(date)"
say "phone: $(/system/bin/getprop ro.product.manufacturer 2>/dev/null) $(/system/bin/getprop ro.product.model 2>/dev/null)"
say "android: $(/system/bin/getprop ro.build.version.release 2>/dev/null) (sdk $(/system/bin/getprop ro.build.version.sdk 2>/dev/null)) abi: $(/system/bin/getprop ro.product.cpu.abi 2>/dev/null)"
say "uname: $(uname -a)"
say "installer: ${INSTALLER_REPO}@${INSTALLER_REF}"

run pkg-update pkg update -y
run pkg-base pkg install -y curl git tar

say "=== STEP: download-installer ($(date +%H:%M:%S)) ==="
if curl -fsSL "$INSTALLER_URL" -o "$REPORT_DIR/installer.tgz" >> "$LOG" 2>&1 \
   && tar -xzf "$REPORT_DIR/installer.tgz" -C "$REPORT_DIR" >> "$LOG" 2>&1; then
  record download-installer PASS "$INSTALLER_URL"
else
  record download-installer FAIL "could not download $INSTALLER_URL"
fi
INSTALL_DIR=$(ls -d "$REPORT_DIR"/dsh-termux-* 2>/dev/null | head -1)

if [ -n "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/install.sh" ]; then
  export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-sk-test-dummy}"
  run installer-install bash -c "cd '$INSTALL_DIR' && bash install.sh"

  run dsh-version dsh --version

  say "=== STEP: dsh-web ($(date +%H:%M:%S)) ==="
  nohup dsh web --no-open > "$REPORT_DIR/web.log" 2>&1 &
  WEB_PID=$!
  code=000
  for _ in $(seq 1 60); do
    code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3080/ 2>/dev/null)
    [ -z "$code" ] && code=000
    [ "$code" != "000" ] && break
    sleep 5
  done
  cat "$REPORT_DIR/web.log" >> "$LOG"
  if [ "$code" != "000" ]; then
    record dsh-web PASS "http=$code on 127.0.0.1:3080"
  else
    record dsh-web FAIL "no HTTP response on 127.0.0.1:3080 after 300s (see web.log in full.log)"
  fi
  kill "$WEB_PID" 2>/dev/null
  sleep 2

  DSH_PKG="$(npm root -g)/@deepseek-ai/dsh/package.json"
  say "=== STEP: native-checks ($(date +%H:%M:%S)) ==="
  if [ -f "$DSH_PKG" ]; then
    node "$HERE/checks.mjs" "$DSH_PKG" 2>&1 | tee -a "$LOG" | grep '^CHECK ' | sed 's/^CHECK //' | tee -a "$REPORT"
  else
    record native-checks FAIL "dsh package.json not found at $DSH_PKG"
  fi

  DSH_ROOT="$(npm root -g)/@deepseek-ai/dsh"
  p_fs=$(grep -rl "termux-noreplace-fallback" "$DSH_ROOT" 2>/dev/null | wc -l)
  p_att=$(grep -rl "termux-hardlink-fallback" "$DSH_ROOT" 2>/dev/null | wc -l)
  p_sess=$(grep -rl "await rename(tmp, finalPath)" "$DSH_ROOT" 2>/dev/null | wc -l)
  if [ "$p_fs" -ge 1 ] && [ "$p_att" -ge 1 ] && [ "$p_sess" -ge 1 ]; then
    record termux-patches-present PASS "fs-local=$p_fs attachment=$p_att session=$p_sess"
  else
    record termux-patches-present FAIL "fs-local=$p_fs attachment=$p_att session=$p_sess (all must be >=1)"
  fi
else
  record installer-install FAIL "install.sh not found (download failed)"
fi

say "=== DONE $(date) ==="

# Redact secrets before the user shares the files.
for f in "$LOG" "$REPORT"; do
  sed -i -E 's/token=[A-Za-z0-9_-]+/token=REDACTED/g; s/sk-[A-Za-z0-9_-]{6,}/sk-REDACTED/g' "$f"
done

echo
echo "================ REPORT ================"
cat "$REPORT"
echo "========================================"
echo "Send back: $REPORT"
echo "If something failed also send: $LOG"
