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

# .git の存在だけでは足りない。所有者が違う（dubious ownership）などで git が
# リポジトリとして扱わないことがあり、その場合 git config は exit 128 で落ちて
# apply 全体を止めてしまう。hook の設定失敗で apply を落とす価値はないので、
# git 自身に確認させて、駄目なら理由を出して抜ける。
if ! git -C "$SOURCE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  printf "git does not recognize %s as a repository. Skipping hooks setup...\n" "$SOURCE_DIR"
  git -C "$SOURCE_DIR" rev-parse --git-dir 2>&1 | sed "s/^/  /" || true
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
