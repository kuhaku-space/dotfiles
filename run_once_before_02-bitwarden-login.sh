#!/usr/bin/env bash
set -eu

if ! bash "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/scripts/needs-bitwarden.sh"; then
  printf "SSH key already matches the repository's public key; skipping bw login.\n"
  exit 0
fi

BW="$(command -v bw || true)"
if [ -z "$BW" ] && command -v mise >/dev/null 2>&1; then
  BW="$(mise which bw 2>/dev/null || true)"
fi
if [ -z "$BW" ] && [ -x "$HOME/.local/bin/bw" ]; then
  BW="$HOME/.local/bin/bw"
fi
if [ -z "$BW" ]; then
  printf "bw not found; cannot ensure Bitwarden login.\n" >&2
  exit 1
fi

STATUS="$("$BW" status 2>/dev/null | tr -d '[:space:]' || true)"
case "$STATUS" in
  *'"status":"unauthenticated"'*)
    printf "\e[1;36mLog in to Bitwarden (bw login)\e[m\n"
    "$BW" login
    ;;
  *)
    printf "Already logged in to Bitwarden; skipping bw login.\n"
    ;;
esac
