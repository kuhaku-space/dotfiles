#!/usr/bin/env bash
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
PUB="$SOURCE_DIR/private_dot_ssh/id_ed25519.pub"
KEY="$HOME/.ssh/id_ed25519"

[ -z "${CI:-}" ] || exit 0
[ -e "$KEY" ] || exit 0
command -v ssh-keygen >/dev/null 2>&1 || exit 0

fp() { ssh-keygen -lf "$1" 2>/dev/null | grep -o 'SHA256:[^ ]*' || true; }

EXPECTED="$(fp "$PUB")"
LOCAL="$(fp "$KEY")"

if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$LOCAL" ]; then
  exit 0
fi

STAMP="$(date +%Y%m%d%H%M%S)"
printf "\e[1;33mExisting SSH key differs from the one this repository manages.\e[m\n" >&2
printf "  local:    %s\n" "${LOCAL:-(fingerprint unavailable)}" >&2
printf "  expected: %s\n" "${EXPECTED:-(fingerprint unavailable)}" >&2

for f in "$KEY" "$KEY.pub"; do
  [ -e "$f" ] || continue
  cp -p "$f" "$f.bak.$STAMP"
  printf "  backed up %s -> %s\n" "$f" "$f.bak.$STAMP" >&2
done

printf "chezmoi will now replace it with the key from Bitwarden.\n" >&2
