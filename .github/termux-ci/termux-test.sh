#!/data/data/com.termux/files/usr/bin/bash
# Runs INSIDE the Termux app on the Android emulator (as the com.termux uid).
# Usage: termux-test.sh <installer tarball URL> [abi]
#   abi defaults to aarch64 (real phones). On an x86_64 emulator the installer's
#   hard-coded NDK target is switched to x86_64 and this is logged as an adaptation.
# Writes ~/ci/ci.log (everything) and ~/ci/summary.txt (PASS/FAIL per step).

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export TMPDIR=$PREFIX/tmp
export PATH=$PREFIX/bin
export LANG=en_US.UTF-8
export TERM=xterm-256color
export SHELL=$PREFIX/bin/bash
if [ -f "$PREFIX/lib/libtermux-exec.so" ]; then
  export LD_PRELOAD="$PREFIX/lib/libtermux-exec.so"
fi

INSTALLER_URL="${1:?usage: termux-test.sh <installer tarball URL> [abi]}"
ABI="${2:-aarch64}"
CI_DIR=$HOME/ci
LOG=$CI_DIR/ci.log
SUMMARY=$CI_DIR/summary.txt
mkdir -p "$CI_DIR"
: > "$LOG"
: > "$SUMMARY"

say() { echo "$*" | tee -a "$LOG"; }

record() { # record <name> <PASS|FAIL> <detail>
  echo "[$1] $2 $3" | tee -a "$LOG" >> "$SUMMARY"
}

run_step() { # run_step <name> <command...>
  local name="$1"; shift
  say "=== STEP: $name ($(date -u +%H:%M:%S) UTC) ==="
  "$@" >> "$LOG" 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then record "$name" PASS "rc=0"; else record "$name" FAIL "rc=$rc"; fi
  return "$rc"
}

say "Termux CI started $(date -u)"
say "uname: $(uname -a)"
say "android: $(/system/bin/getprop ro.build.version.release 2>/dev/null) abi: $(/system/bin/getprop ro.product.cpu.abi 2>/dev/null) (test abi=$ABI)"
say "termux: $(cat $PREFIX/etc/motd 2>/dev/null | head -1)"

run_step pkg-update pkg update -y
run_step pkg-base pkg install -y curl git tar

run_step download-installer bash -c "curl -fsSL '$INSTALLER_URL' -o '$CI_DIR/installer.tgz' && tar -xzf '$CI_DIR/installer.tgz' -C '$CI_DIR'"
INSTALL_DIR=$(ls -d "$CI_DIR"/dsh-termux-* 2>/dev/null | head -1)
say "installer dir: ${INSTALL_DIR:-<none>}"

if [ -n "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/install.sh" ]; then
  if [ "$ABI" = "x86_64" ]; then
    # The installer compiles native modules for aarch64 only. On an x86_64 emulator
    # the same target must be x86_64, or clang builds the wrong architecture.
    sed -i 's/^NDK_TARGET="aarch64-unknown-linux-android30"/NDK_TARGET="x86_64-unknown-linux-android30"/' "$INSTALL_DIR/install.sh"
    record install-adaptation INFO "NDK_TARGET aarch64 -> x86_64 (emulator only, not a phone test)"
  fi
  # Same invocation the installer README documents. DEEPSEEK_API_KEY is set so the
  # interactive key prompt is skipped; a dummy key is enough for install and boot tests.
  run_step installer-install bash -c "cd '$INSTALL_DIR' && DEEPSEEK_API_KEY=sk-ci-dummy bash install.sh"

  run_step dsh-version dsh --version

  say "=== STEP: dsh-web (boot the web UI and poll it) ==="
  nohup dsh web --no-open > "$CI_DIR/web.log" 2>&1 &
  WEB_PID=$!
  code=000
  for i in $(seq 1 60); do
    code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3080/ 2>/dev/null || echo 000)
    [ "$code" != "000" ] && break
    sleep 5
  done
  say "web.log (tail):"; tail -n 20 "$CI_DIR/web.log" | tee -a "$LOG"
  if [ "$code" != "000" ]; then record dsh-web PASS "http=$code on 127.0.0.1:3080"; else record dsh-web FAIL "no HTTP response on 127.0.0.1:3080 after 300s"; fi
  kill "$WEB_PID" 2>/dev/null
  sleep 2

  # Native modules and ripgrep, checked from inside dsh's own dependency tree.
  DSH_PKG="$(npm root -g)/@deepseek-ai/dsh/package.json"
  say "=== STEP: native-checks ==="
  if [ -f "$DSH_PKG" ]; then
    node "$CI_DIR/checks.mjs" "$DSH_PKG" 2>&1 | tee -a "$LOG" | grep '^CHECK ' | sed 's/^CHECK //' | tee -a "$SUMMARY"
  else
    record native-checks FAIL "dsh package.json not found at $DSH_PKG"
  fi

  say "=== STEP: termux-patches-present ==="
  patched=$(grep -rl "termux-noreplace-fallback\|termux-hardlink-fallback\|termux-durability-guard" "$(npm root -g)/@deepseek-ai/dsh" 2>/dev/null | wc -l)
  if [ "$patched" -ge 3 ]; then record termux-patches-present PASS "files=$patched"; else record termux-patches-present FAIL "files=$patched (expected >=3)"; fi
else
  record installer-install FAIL "install.sh not found in installer tarball"
fi

say "=== DONE $(date -u) ==="
echo "--- summary ---"; cat "$SUMMARY"
