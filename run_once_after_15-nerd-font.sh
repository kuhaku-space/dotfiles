#!/usr/bin/env bash
# 実機の Linux デスクトップ向けに Nerd Font を入れる。
#
# starship の既定プリセットは git ブランチに Powerline のグリフ（U+E0A0）を使い、
# eza --icons と zellij のタブバーも Nerd Font の私用領域を叩く。WSL では
# Windows Terminal 側にフォントを設定しているので見えているが、実機では Linux 側に
# 入れないと全部豆腐（□）になる。dotfiles がこれを一切面倒見ていなかった。
#
# フォントは端末エミュレータ側で選ぶ必要がある。導入後に端末の設定で
# "JetBrainsMono Nerd Font" を選ぶこと。
set -eu

FONT_NAME="JetBrainsMono"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts"
URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_NAME}.zip"

warn() { printf "\e[1;33m%s\e[m\n" "$1" >&2; }

# WSL では Windows 側の端末がフォントを描くので、Linux 側に入れても使われない。
# /proc/sys/kernel/osrelease に microsoft が入るのが WSL1/WSL2 共通の目印。
if [ -n "${WSL_DISTRO_NAME:-}" ] ||
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf "WSL detected; fonts are rendered by the Windows terminal. Skipping.\n"
  exit 0
fi

if [ -d "$FONT_DIR" ] && [ -n "$(find "$FONT_DIR" -name '*.ttf' -print -quit 2>/dev/null)" ]; then
  printf "Nerd Font already installed in %s. Skipping.\n" "$FONT_DIR"
  exit 0
fi

# 端末が既に別の Nerd Font を持っているなら足さない。
if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "nerd font"; then
  printf "A Nerd Font is already available to fontconfig. Skipping.\n"
  exit 0
fi

# ここから先は「見た目が良くなる」だけの処理なので、失敗しても apply は止めない。
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
# アーカイブは 96 ファイル・展開すると 229MB ある（Mono / Propo / 各ウェイト）。
# 端末で要るのは Mono 版（アイコンが1セル幅に収まる）の4スタイルだけなので、
# そこだけ取り出す（20MB）。パターンに一致しないと unzip は 11 で終わるので、
# 命名が変わった場合は保険として .ttf を全部展開する。
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
