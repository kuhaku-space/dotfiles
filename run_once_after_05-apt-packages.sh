#!/usr/bin/env bash
# 初回 apply 時に一度だけ実行され、不足している apt パッケージを install する。
# 後からパッケージを追加した場合は手動で apt install するか、このスクリプトを実行すること。
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

if ! check_command apt; then
  printf "apt is not installed. Ignoring...\n"
  exit 0
fi

PACKAGES=(
  "build-essential"
  "libssl-dev"
  "libclang-dev"
  "cmake"
  "jq"
  "keychain"
  "zsh"
  "unzip"
)
MISSING_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed$"; then
    MISSING_PACKAGES+=("$pkg")
  fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
  printf "\e[1;36mInstall apt packages: %s\e[m\n" "${MISSING_PACKAGES[*]}"
  sudo apt update -qq
  sudo apt install -qq -y "${MISSING_PACKAGES[@]}"
  sudo apt autoremove -qq -y
  sudo apt autoclean -qq -y
  sudo apt clean -qq -y
fi
