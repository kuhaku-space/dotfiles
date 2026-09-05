#!/usr/bin/env bash
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
HOOKS_DIR="$SOURCE_DIR/.githooks"

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
git -C "$SOURCE_DIR" config core.hooksPath "$HOOKS_DIR"
chmod +x "$HOOKS_DIR"/* 2>/dev/null || true
printf "  core.hooksPath = %s\n" "$HOOKS_DIR"
