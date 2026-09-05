#!/usr/bin/env bash
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

if ! bash "$SOURCE_DIR/scripts/needs-bitwarden.sh"; then
  printf "SSH key already matches the repository's public key; skipping bw bootstrap.\n"
  exit 0
fi

if command -v bw >/dev/null 2>&1; then
  exit 0
fi

if command -v mise >/dev/null 2>&1 && mise which bw >/dev/null 2>&1; then
  exit 0
fi

printf "\e[1;36mBootstrap Bitwarden CLI (bw)\e[m\n"

LOCK="$SOURCE_DIR/dot_config/mise/private_mise.lock"
if [ ! -r "$LOCK" ]; then
  printf "mise lockfile not found: %s\n" "$LOCK" >&2
  exit 1
fi

MACHINE="$(uname -m)"
case "$MACHINE" in
  x86_64 | amd64) PLATFORM="linux-x64" ;;
  aarch64 | arm64) PLATFORM="linux-arm64" ;;
  *)
    printf "No bw build is known for this architecture: %s\n" "$MACHINE" >&2
    printf "Install bw manually (or via mise) and re-run chezmoi apply.\n" >&2
    exit 1
    ;;
esac

lock_field() {
  awk -v section="[tools.bitwarden.\"platforms.$PLATFORM\"]" -v key="$1" '
    $0 == section { in_section = 1; next }
    in_section && /^\[/ { exit }
    in_section && $1 == key { gsub(/"/, "", $3); print $3; exit }
  ' "$LOCK"
}

URL="$(lock_field url)"
CHECKSUM="$(lock_field checksum)"
if [ -z "$URL" ]; then
  printf "No bitwarden entry for %s in %s\n" "$PLATFORM" "$LOCK" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  printf "Installing unzip (required to extract bw)\n"
  if sudo apt-get update -qq; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip || true
  fi
fi
if ! command -v unzip >/dev/null 2>&1; then
  printf "unzip is required to extract bw but is not installed.\n" >&2
  printf "Install it (e.g. sudo apt install -y unzip) and re-run chezmoi apply.\n" >&2
  exit 1
fi

DEST="$HOME/.local/bin"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/bw.zip"

case "$CHECKSUM" in
  sha256:*)
    if command -v sha256sum >/dev/null 2>&1; then
      if ! printf '%s  %s\n' "${CHECKSUM#sha256:}" "$TMP/bw.zip" | sha256sum -c - >/dev/null 2>&1; then
        printf "Checksum mismatch for %s\n" "$URL" >&2
        printf "  expected %s\n" "${CHECKSUM#sha256:}" >&2
        printf "  actual   %s\n" "$(sha256sum "$TMP/bw.zip" | cut -d' ' -f1)" >&2
        exit 1
      fi
    else
      printf "sha256sum not found; skipping checksum verification.\n" >&2
    fi
    ;;
  *)
    printf "No usable checksum for %s in the lockfile; skipping verification.\n" "$PLATFORM" >&2
    ;;
esac

unzip -oq "$TMP/bw.zip" -d "$TMP/extracted"
BW_BIN="$(find "$TMP/extracted" -maxdepth 2 -type f -name bw -print -quit)"
if [ -z "$BW_BIN" ]; then
  printf "No bw binary inside %s\n" "$URL" >&2
  exit 1
fi
install -m 0755 "$BW_BIN" "$DEST/bw"

printf "Installed bw (%s) to %s\n" "$PLATFORM" "$DEST/bw"
