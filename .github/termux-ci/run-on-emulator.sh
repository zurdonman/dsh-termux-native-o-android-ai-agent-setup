#!/usr/bin/env bash
# Host side (GitHub runner). Runs while the Android emulator is up.
#  1. installs the Termux APK (github-debug build, which allows `run-as`)
#  2. waits for Termux to extract its bootstrap
#  3. copies termux-test.sh into Termux's home and runs it as the Termux uid
#  4. pulls the logs back to ci-logs/ and into the job summary
set -uo pipefail

ADB="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}/platform-tools/adb"
[ -x "$ADB" ] || ADB=adb

APK="$GITHUB_WORKSPACE/ci-apk/termux.apk"
OUT="$GITHUB_WORKSPACE/ci-logs"
mkdir -p "$OUT"

PKG=com.termux
PREFIX_T=/data/data/com.termux/files/usr
HOME_T=/data/data/com.termux/files/home
INSTALLER_URL="https://codeload.github.com/${INSTALLER_REPO}/tar.gz/refs/heads/${INSTALLER_REF}"

echo "::group::Device"
"$ADB" wait-for-device
"$ADB" shell getprop ro.product.cpu.abi | tr -d '\r'
"$ADB" shell getprop ro.build.version.release | tr -d '\r'
"$ADB" shell getprop ro.build.version.sdk | tr -d '\r'
echo "::endgroup::"

echo "::group::Install Termux"
if ! "$ADB" install -r -g "$APK"; then
  echo "Termux APK install failed" | tee "$OUT/summary.txt"
  cat "$OUT/summary.txt" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi
"$ADB" shell am start -n "$PKG/com.termux.app.TermuxActivity" >/dev/null
echo "::endgroup::"

echo "::group::Wait for Termux bootstrap"
ready=0
for i in $(seq 1 90); do
  if "$ADB" shell "run-as $PKG sh -c 'test -x $PREFIX_T/bin/bash && echo READY'" 2>/dev/null | tr -d '\r' | grep -q READY; then
    ready=1
    echo "bootstrap ready after $((i * 10))s"
    break
  fi
  sleep 10
done
echo "::endgroup::"

if [ "$ready" -ne 1 ]; then
  echo "Termux bootstrap never appeared" | tee "$OUT/summary.txt"
  "$ADB" logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
  cat "$OUT/summary.txt" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

echo "::group::Copy test script into Termux"
"$ADB" shell "run-as $PKG sh -c 'cat > $HOME_T/termux-test.sh'" < "$GITHUB_WORKSPACE/.github/termux-ci/termux-test.sh"
"$ADB" shell "run-as $PKG sh -c 'cat > $HOME_T/checks.mjs'" < "$GITHUB_WORKSPACE/.github/termux-ci/checks.mjs"
echo "::endgroup::"

echo "::group::Run installer inside Termux (this takes a while)"
timeout 5400 "$ADB" shell "run-as $PKG $PREFIX_T/bin/bash $HOME_T/termux-test.sh '$INSTALLER_URL'"
echo "termux-test.sh exit code: $?"
echo "::endgroup::"

echo "::group::Collect logs"
"$ADB" shell "run-as $PKG cat $HOME_T/ci/ci.log" > "$OUT/ci.log" 2>/dev/null
"$ADB" shell "run-as $PKG cat $HOME_T/ci/summary.txt" > "$OUT/summary.txt" 2>/dev/null
"$ADB" shell "run-as $PKG cat $HOME_T/ci/web.log" > "$OUT/web.log" 2>/dev/null
"$ADB" logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
cat "$OUT/summary.txt" 2>/dev/null
echo "::endgroup::"

{
  echo "## Termux on Android (arm64) - dsh installer test"
  echo
  echo "Installer: \`${INSTALLER_REPO}@${INSTALLER_REF}\`, emulator API ${API_LEVEL}"
  echo
  echo '```'
  cat "$OUT/summary.txt" 2>/dev/null
  echo '```'
} >> "$GITHUB_STEP_SUMMARY"

if [ ! -s "$OUT/summary.txt" ] || grep -q FAIL "$OUT/summary.txt"; then
  echo "At least one step failed (see summary)."
  exit 1
fi
exit 0
