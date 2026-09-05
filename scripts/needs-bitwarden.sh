#!/usr/bin/env bash
set -eu

if [ -n "${CI:-}" ]; then
  exit 1
fi

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
PUB="$SOURCE_DIR/private_dot_ssh/id_ed25519.pub"
KEY="$HOME/.ssh/id_ed25519"

if ! command -v ssh-keygen >/dev/null 2>&1; then exit 0; fi
if [ ! -r "$PUB" ] || [ ! -r "$KEY" ]; then exit 0; fi

fp() { ssh-keygen -lf "$1" 2>/dev/null | grep -o 'SHA256:[^ ]*' || true; }

EXPECTED="$(fp "$PUB")"
LOCAL="$(fp "$KEY")"

if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$LOCAL" ]; then
  exit 1
fi
exit 0
