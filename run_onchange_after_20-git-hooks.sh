#!/usr/bin/env bash
# ソースリポジトリの git hook を有効にする。
# このファイルの内容が変わると chezmoi が再実行する（run_onchange）。
#
# hook 本体は .githooks/ に置いている。ソースディレクトリ直下の「.」始まりは
# chezmoi が管理対象から自動的に外すので、$HOME には展開されずリポジトリだけに残る。
# clone しただけでは core.hooksPath は設定されないため、apply のたびに保証する。
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
HOOKS_DIR="$SOURCE_DIR/.githooks"

if [ ! -d "$SOURCE_DIR/.git" ]; then
  printf "Source directory is not a git repository. Skipping hooks setup...\n"
  exit 0
fi

if [ ! -d "$HOOKS_DIR" ]; then
  printf "%s not found. Skipping hooks setup...\n" "$HOOKS_DIR"
  exit 0
fi

printf "\e[1;36mEnable git hooks in the dotfiles source repository\e[m\n"
# 相対パスは git のバージョンで解釈が変わるので絶対パスで設定する。
git -C "$SOURCE_DIR" config core.hooksPath "$HOOKS_DIR"
chmod +x "$HOOKS_DIR"/* 2>/dev/null || true
printf "  core.hooksPath = %s\n" "$HOOKS_DIR"
