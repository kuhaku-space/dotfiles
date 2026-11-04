#!/usr/bin/env bash
set -eu

if [ -n "${CI:-}" ]; then
  exit 0
fi

LOGIN_ITEM="37b0c493-58d7-4b02-87dc-b4c400b57caf"
KEY_ITEM="6e720ed5-807a-411d-bc28-b4c400d0d13c"

ATUIN="$(command -v atuin || true)"
if [ -z "$ATUIN" ] && command -v mise >/dev/null 2>&1; then
  ATUIN="$(mise which atuin 2>/dev/null || true)"
fi
if [ -z "$ATUIN" ]; then
  printf "atuin not found; skipping Atuin login.\n" >&2
  exit 0
fi

if ! "$ATUIN" status 2>&1 | grep -q 'not logged in'; then
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
  printf "bw not found; cannot log in to Atuin.\n" >&2
  exit 1
fi

STATUS="$("$BW" status 2>/dev/null | tr -d '[:space:]' || true)"
case "$STATUS" in
  *'"status":"unauthenticated"'*)
    printf "\e[1;36mLog in to Bitwarden for Atuin (bw login)\e[m\n"
    BW_SESSION="$("$BW" login --raw)"
    export BW_SESSION
    ;;
  *'"status":"locked"'*)
    printf "\e[1;36mUnlock Bitwarden for Atuin (bw unlock)\e[m\n"
    BW_SESSION="$("$BW" unlock --raw)"
    export BW_SESSION
    ;;
esac

USERNAME="$("$BW" get username "$LOGIN_ITEM")"
ATUIN_PASSWORD="$("$BW" get password "$LOGIN_ITEM")"
ATUIN_ENCRYPTION_KEY="$("$BW" get notes "$KEY_ITEM")"
export ATUIN_PASSWORD ATUIN_ENCRYPTION_KEY

printf "\e[1;36mLog in to Atuin as %s\e[m\n" "$USERNAME"
"$ATUIN" login -u "$USERNAME"
"$ATUIN" sync
