#!/usr/bin/env bash
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

warn() {
  printf "\e[1;33m%s\e[m\n" "$1" >&2
}

cd "$HOME"

printf "\e[1;36mChange default shell to zsh\e[m\n"
ZSH_PATH="$(command -v zsh || true)"
CURRENT_SHELL="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
resolve() { readlink -f "$1" 2>/dev/null || echo "$1"; }
if [ -z "$ZSH_PATH" ]; then
  printf "zsh is not installed yet; skipping chsh (run after zsh is installed).\n"
elif [ "$(resolve "$CURRENT_SHELL")" != "$(resolve "$ZSH_PATH")" ]; then
  if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null ||
      warn "Failed to register $ZSH_PATH in /etc/shells (needs sudo)."
  fi
  if grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    chsh -s "$ZSH_PATH" ||
      warn "chsh failed. Set the login shell manually: chsh -s $ZSH_PATH"
  else
    warn "Skipping chsh: $ZSH_PATH is not listed in /etc/shells."
  fi
else
  printf "Default shell is already zsh; skipping chsh.\n"
fi

printf "\e[1;36mSource zshenv configuration file\e[m\n"
set +u
. "$HOME/.config/zsh/.zshenv"
set -u

printf "\e[1;36mMake directories\e[m\n"
mkdir -p "$HOME/.local/state/zsh" "$HOME/.cache/zsh"
mkdir -p "$HOME/.ssh/control" "$HOME/.ssh/config.d"
chmod 700 "$HOME/.ssh/control" "$HOME/.ssh/config.d"

printf "\e[1;36mInstall mise\e[m\n"
check_command mise || curl -fsSL https://mise.run | sh
MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
"$MISE" self-update -y ||
  warn "mise self-update failed (not a standalone install?). Update it with your package manager."

printf "\e[1;36mSwitch dotfiles remote to SSH for push\e[m\n"
SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
if [ -d "$SOURCE_DIR/.git" ]; then
  ORIGIN_URL="$(git -C "$SOURCE_DIR" remote get-url origin 2>/dev/null || true)"
  case "$ORIGIN_URL" in
    https://*github.com/*)
      git -C "$SOURCE_DIR" remote set-url origin \
        ssh://git@github.com/kuhaku-space/dotfiles.git
      ;;
  esac
fi
