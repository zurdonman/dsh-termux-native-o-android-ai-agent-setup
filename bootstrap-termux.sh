#!/data/data/com.termux/files/usr/bin/bash
# One-command installer for DeepSeek Harness (dsh) on Termux (Android).
#
# Run this in Termux, from any terminal:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup/main/bootstrap-termux.sh)
#
# It downloads (or updates) the repo in ~/dsh-termux-native-o-android-ai-agent-setup
# and runs install-termux.sh. Re-running it is safe.
#
# Note: use <(...) and not "curl ... | bash". The installer asks for your
# DeepSeek API key, and that prompt needs the keyboard, not a pipe.

set -eu

REPO_URL="${DSH_REPO_URL:-https://github.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup.git}"
REPO_BRANCH="${DSH_REPO_BRANCH:-main}"
DEST="${DSH_DIR:-$HOME/dsh-termux-native-o-android-ai-agent-setup}"

die() { printf '\n\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

if [ ! -d /data/data/com.termux ]; then
  die "run this inside Termux (install it from F-Droid, not the Play Store)."
fi

step "Git"
if ! command -v git >/dev/null 2>&1; then
  pkg install -y git || die "could not install git (pkg install -y git)."
fi

step "Repository: $DEST"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch -q origin "$REPO_BRANCH" || die "could not fetch from GitHub. Check your connection."
  git -C "$DEST" checkout -q "$REPO_BRANCH" || die "could not switch $DEST to $REPO_BRANCH (local changes?)."
  git -C "$DEST" merge -q --ff-only "origin/$REPO_BRANCH" || die "local copy in $DEST has changes that block the update. Move the folder away and run this again."
  echo "    updated to $(git -C "$DEST" rev-parse --short HEAD)"
elif [ -e "$DEST" ]; then
  die "$DEST exists but is not a git checkout. Move it away and run this again."
else
  git clone -q -b "$REPO_BRANCH" "$REPO_URL" "$DEST" || die "git clone failed."
  echo "    cloned $(git -C "$DEST" rev-parse --short HEAD)"
fi

step "Running install-termux.sh"
cd "$DEST"
exec bash install-termux.sh
