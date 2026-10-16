#!/data/data/com.termux/files/usr/bin/bash
# One-command installer for DeepSeek Harness (dsh) on Termux (Android, arm64).
#
#   git clone -b <branch> https://github.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup.git
#   cd dsh-termux-native-o-android-ai-agent-setup
#   bash install-termux.sh
#
# Steps:
#   1. Base packages (git, curl, tar) and pkg upgrade (fixes the cmake/libc++ mismatch).
#   2. Runs the lilyco-42/dsh-termux installer, pinned to a commit. It asks for your
#      DeepSeek API key (hidden input), so run this from a terminal, not a pipe.
#   3. pnpm, which dsh uses to install plugins.
#   4. Android fixes that the lilyco installer does not cover:
#        - termux-verify/fix-require-builtin.sh  (dsh web does not start otherwise)
#        - termux-verify/fix-ripgrep.sh          (glob/grep tools)
#   5. Self-check (termux-verify/checks.mjs).
#
# Re-running is safe: every step skips work that is already done.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# Pinned lilyco-42/dsh-termux commit (main as of 2026-10-11). Change it to update.
LILYCO_SHA="36b7cc87a03e3a45dabcdede70404370f14aa688"
LILYCO_URL="https://codeload.github.com/lilyco-42/dsh-termux/tar.gz/${LILYCO_SHA}"
WORK_DIR="$HOME/dsh-install"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
die() { printf '\n\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

if [ ! -d /data/data/com.termux ]; then
  die "this script must run inside Termux (install it from F-Droid)."
fi

step "1/5 Base packages"
pkg install -y git curl tar || die "pkg install failed (see messages above)."
pkg upgrade -y || die "pkg upgrade failed (see messages above)."

step "2/5 lilyco-42/dsh-termux installer (commit ${LILYCO_SHA:0:7})"
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
curl -fsSL "$LILYCO_URL" | tar -xz -C "$WORK_DIR" || die "could not download the installer from $LILYCO_URL"
INSTALLER_DIR="$(ls -d "$WORK_DIR"/dsh-termux-* 2>/dev/null | head -1)"
[ -f "$INSTALLER_DIR/install.sh" ] || die "install.sh not found in the downloaded archive."
(cd "$INSTALLER_DIR" && bash install.sh) || die "lilyco installer failed. Send the messages above."

step "3/5 pnpm (used by dsh to install plugins)"
if command -v pnpm >/dev/null 2>&1; then
  echo "    pnpm $(pnpm --version) already installed."
else
  npm install -g pnpm || die "npm install -g pnpm failed."
fi

step "4/5 Android fixes (dsh web and ripgrep)"
bash "$REPO_DIR/termux-verify/fix-require-builtin.sh" || die "fix-require-builtin.sh failed."
bash "$REPO_DIR/termux-verify/fix-ripgrep.sh" || die "fix-ripgrep.sh failed."
bash "$REPO_DIR/termux-verify/fix-flock.sh" || die "fix-flock.sh failed."
bash "$REPO_DIR/termux-verify/fix-rename-import.sh" || die "fix-rename-import.sh failed."

step "5/5 Self-check"
DSH_PKG="$(npm root -g)/@deepseek-ai/dsh/package.json"
FAILS=0
if [ -f "$DSH_PKG" ]; then
  node "$REPO_DIR/termux-verify/checks.mjs" "$DSH_PKG" | tee "$WORK_DIR/checks.txt" | sed 's/^CHECK //'
  FAILS=$(grep -c ' FAIL' "$WORK_DIR/checks.txt" || true)
else
  echo "    dsh package.json not found at $DSH_PKG"
  FAILS=1
fi

echo
if [ "$FAILS" -eq 0 ] && command -v dsh >/dev/null 2>&1; then
  printf '\033[1;32mInstallation finished.\033[0m dsh version: %s\n' "$(dsh --version 2>/dev/null | head -1)"
  echo "Start the web UI with:  dsh web"
  echo "(Stop it with Ctrl+C. Open the URL it prints in the Android browser.)"
  exit 0
fi
printf '\033[1;33mFinished with %s failing check(s).\033[0m\n' "$FAILS"
echo "Send back: $WORK_DIR/checks.txt (and the messages above)."
exit 1
