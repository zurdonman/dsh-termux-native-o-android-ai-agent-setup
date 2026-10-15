#!/usr/bin/env bash
# Host side (GitHub runner with KVM). Everything here is logged to ci-logs/host.log.
#  1. installs the Android SDK pieces (platform-tools, emulator, system image for $EMULATOR_ABI)
#  2. creates an AVD and boots it (KVM), logs to ci-logs/emulator.log
#  3. installs the Termux APK (github-debug build, which allows `run-as`)
#  4. waits for Termux to extract its bootstrap, then runs termux-test.sh as com.termux
#  5. collects logs into ci-logs/ and writes ci-logs/summary.txt
set -uo pipefail

OUT="$GITHUB_WORKSPACE/ci-logs"
mkdir -p "$OUT"
: > "$OUT/summary.txt"
exec > >(tee -a "$OUT/host.log") 2>&1

API="${API_LEVEL:-34}"
ABI="${EMULATOR_ABI:-x86_64}"
IMG="system-images;android-${API};google_apis;${ABI}"
AVD=dshtest
PKG=com.termux
PREFIX_T=/data/data/com.termux/files/usr
HOME_T=/data/data/com.termux/files/home
INSTALLER_URL="https://codeload.github.com/${INSTALLER_REPO}/tar.gz/refs/heads/${INSTALLER_REF}"

note() { echo "[host $(date -u +%H:%M:%S)] $*"; }
record() { echo "[host] $1 $2" >> "$OUT/summary.txt"; }

collect_logs() {
  local adb="$1"
  "$adb" logcat -d -t 5000 > "$OUT/logcat.txt" 2>/dev/null || true
  "$adb" shell "run-as $PKG cat $HOME_T/ci/ci.log" > "$OUT/ci.log" 2>/dev/null || true
  "$adb" shell "run-as $PKG cat $HOME_T/ci/summary.txt" > "$OUT/termux-summary.txt" 2>/dev/null || true
  "$adb" shell "run-as $PKG cat $HOME_T/ci/web.log" > "$OUT/web.log" 2>/dev/null || true
  cat "$OUT/termux-summary.txt" >> "$OUT/summary.txt" 2>/dev/null || true
}

fail() {
  note "FAIL: $*"
  record host-FAIL "$*"
  if [ -n "${ADB:-}" ]; then collect_logs "$ADB"; fi
  finish 1
}

finish() {
  local rc="$1"
  {
    echo "## Termux on Android (${ABI} emulator) - dsh installer test"
    echo "installer: ${INSTALLER_REPO}@${INSTALLER_REF}, emulator API ${API}"
    echo '```'
    cat "$OUT/summary.txt"
    echo '```'
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  if grep -q FAIL "$OUT/summary.txt" 2>/dev/null; then exit 1; fi
  exit "$rc"
}

# ---------- 1. SDK ----------
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/android-sdk}}"
export ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK"
note "SDK at $SDK"
CMDLINE="$SDK/cmdline-tools/latest/bin"
if [ ! -x "$CMDLINE/sdkmanager" ]; then
  note "downloading Android command-line tools"
  mkdir -p "$SDK/cmdline-tools"
  curl -fsSL -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    || fail "commandline-tools download"
  unzip -q -o /tmp/clt.zip -d "$SDK/cmdline-tools" && rm -rf "$SDK/cmdline-tools/latest" \
    && mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest" || fail "commandline-tools unzip"
fi
note "accepting licenses and installing packages (this can take several minutes)"
yes 2>/dev/null | "$CMDLINE/sdkmanager" --licenses > /dev/null 2>&1 || true
"$CMDLINE/sdkmanager" --install "platform-tools" "emulator" "$IMG" > "$OUT/sdkmanager.log" 2>&1 \
  || fail "sdkmanager install of $IMG (see sdkmanager.log)"
record sdk-install PASS "$IMG"

# ---------- 2. AVD and emulator ----------
echo no | "$CMDLINE/avdmanager" create avd -n "$AVD" -k "$IMG" -d pixel_6 --force > "$OUT/avdmanager.log" 2>&1 \
  || fail "avdmanager create (see avdmanager.log)"
CFG="$HOME/.android/avd/$AVD.avd/config.ini"
{
  echo "hw.ramSize=4096"
  echo "disk.dataPartition.size=12G"
  echo "hw.cpu.ncore=4"
} >> "$CFG"
record avd-create PASS "$AVD"

export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
note "starting emulator"
emulator -avd "$AVD" -no-window -no-snapshot -no-audio -no-boot-anim -no-metrics \
  -gpu swiftshader_indirect -accel on > "$OUT/emulator.log" 2>&1 &
EMU_PID=$!
ADB=adb
adb start-server > /dev/null 2>&1 || true

note "waiting for device"
if ! timeout 600 adb wait-for-device; then
  fail "device never appeared (see emulator.log)"
fi
boot=""
for i in $(seq 1 180); do
  boot=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  [ "$boot" = "1" ] && break
  if ! kill -0 "$EMU_PID" 2>/dev/null; then fail "emulator process exited early (see emulator.log)"; fi
  sleep 5
done
[ "$boot" = "1" ] || fail "boot_completed never reached 1"
record emulator-boot PASS "${ABI} API ${API}"
adb shell getprop ro.product.cpu.abi | tr -d '\r' | sed 's/^/[device] abi=/'
adb shell getprop ro.build.version.release | tr -d '\r' | sed 's/^/[device] android=/'
adb shell getprop ro.build.version.sdk | tr -d '\r' | sed 's/^/[device] sdk=/'
adb shell getprop ro.kernel.qemu.gles 2>/dev/null | tr -d '\r' | sed 's/^/[device] qemu.gles=/'

# ---------- 3. Termux ----------
note "installing Termux APK"
if ! adb install -r -g "$GITHUB_WORKSPACE/ci-apk/termux.apk"; then
  fail "Termux APK install"
fi
record termux-install PASS "github-debug ${ABI}"
adb shell am start -n "$PKG/com.termux.app.TermuxActivity" > /dev/null

note "waiting for Termux bootstrap"
ready=0
for i in $(seq 1 90); do
  if adb shell "run-as $PKG sh -c 'test -x $PREFIX_T/bin/bash && echo READY'" 2>/dev/null | tr -d '\r' | grep -q READY; then
    ready=1
    note "bootstrap ready after $((i * 10))s"
    break
  fi
  sleep 10
done
[ "$ready" -eq 1 ] || fail "Termux bootstrap never appeared (run-as or bootstrap problem)"
record termux-bootstrap PASS "run-as works"

# ---------- 4. Run the Termux-side test ----------
adb shell "run-as $PKG sh -c 'cat > $HOME_T/termux-test.sh'" < "$GITHUB_WORKSPACE/.github/termux-ci/termux-test.sh"
adb shell "run-as $PKG sh -c 'cat > $HOME_T/checks.mjs'" < "$GITHUB_WORKSPACE/.github/termux-ci/checks.mjs"
note "running termux-test.sh inside Termux (installer takes a while)"
timeout 6000 adb shell "run-as $PKG $PREFIX_T/bin/bash $HOME_T/termux-test.sh '$INSTALLER_URL' '$ABI'"
note "termux-test.sh exit code: $?"

# ---------- 5. Collect ----------
collect_logs adb
finish 0
