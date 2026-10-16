#!/usr/bin/env bash
# Creates ~/.codex, which the ChatGPT Subscription plugin needs to save the sign-in.
#
# Why: dsh-chatgpt-sub writes ~/.codex/auth.json.tmp and renames it to auth.json.
# It does not create the folder. On Termux ~/.codex does not exist, so the write
# fails with ENOENT after the browser login succeeds. The plugin then reports
# "oauth.write-failed" ("Signed in, but it could not be saved locally") and
# unbinds, so DSH asks you to sign in again.
#
# Idempotent: safe to run many times. Does not touch auth.json if it exists.
#
#   bash termux-verify/fix-chatgpt-codex-dir.sh

set -uo pipefail

CODEX_DIR="$HOME/.codex"

if [ -d "$CODEX_DIR" ]; then
  echo "already present: $CODEX_DIR"
else
  mkdir -p "$CODEX_DIR" || { echo "error: could not create $CODEX_DIR" >&2; exit 1; }
  echo "created: $CODEX_DIR"
fi
chmod 700 "$CODEX_DIR" || { echo "error: could not chmod $CODEX_DIR" >&2; exit 1; }
exit 0
