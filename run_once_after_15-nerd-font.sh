#!/usr/bin/env bash
set -eu

FONT_NAME="JetBrainsMono"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts"
URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_NAME}.zip"

warn() { printf "\e[1;33m%s\e[m\n" "$1" >&2; }

if [ -n "${CI:-}" ]; then
  printf "CI detected; skipping font installation.\n"
  exit 0
fi

if [ -n "${WSL_DISTRO_NAME:-}" ] ||
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf "WSL detected; fonts are rendered by the Windows terminal. Skipping.\n"
  exit 0
fi

if [ -d "$FONT_DIR" ] && [ -n "$(find "$FONT_DIR" -name '*.ttf' -print -quit 2>/dev/null)" ]; then
  printf "Nerd Font already installed in %s. Skipping.\n" "$FONT_DIR"
  exit 0
fi

if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "nerd font"; then
  printf "A Nerd Font is already available to fontconfig. Skipping.\n"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  warn "curl and unzip are required to install the Nerd Font. Skipping."
  exit 0
fi

printf "\e[1;36mInstall %s Nerd Font\e[m\n" "$FONT_NAME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! curl -fsSL "$URL" -o "$TMP/font.zip"; then
  warn "Failed to download $URL. Skipping font installation."
  exit 0
fi

mkdir -p "$FONT_DIR"
if ! unzip -oq "$TMP/font.zip" -d "$FONT_DIR" \
  '*NerdFontMono-Regular.ttf' '*NerdFontMono-Bold.ttf' \
  '*NerdFontMono-Italic.ttf' '*NerdFontMono-BoldItalic.ttf' 2>/dev/null; then
  warn "Expected font files were not found in the archive; extracting all .ttf instead."
  if ! unzip -oq "$TMP/font.zip" -d "$FONT_DIR" '*.ttf'; then
    warn "Failed to extract the font archive. Skipping."
    exit 0
  fi
fi

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DIR" >/dev/null || warn "fc-cache failed; the font may not be visible yet."
else
  warn "fc-cache not found (install fontconfig); the font may not be visible yet."
fi

printf "  installed to %s\n" "$FONT_DIR"
printf "  select \"%s Nerd Font\" in your terminal emulator's settings.\n" "$FONT_NAME"
