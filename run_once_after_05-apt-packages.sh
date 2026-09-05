#!/usr/bin/env bash
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

PACKAGES=(
  "ca-certificates"
  "curl"
  "git"
  "openssh-client"
  "unzip"
  "zsh"
  "keychain"
  "jq"
  "build-essential"
  "libssl-dev"
  "libclang-dev"
  "cmake"
  "xclip"
  "wl-clipboard"
  "fontconfig"
)

if ! check_command apt-get; then
  printf "\e[1;33mapt is not available on this system.\e[m\n" >&2
  printf "Install the equivalent of these packages with your package manager,\n" >&2
  printf "otherwise zsh / keychain / clipboard / builds will not work:\n" >&2
  printf "  %s\n" "${PACKAGES[@]}" >&2
  exit 0
fi

MISSING_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed$"; then
    MISSING_PACKAGES+=("$pkg")
  fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
  printf "\e[1;36mInstall apt packages: %s\e[m\n" "${MISSING_PACKAGES[*]}"
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get update -qq
  sudo -E apt-get install -qq -y "${MISSING_PACKAGES[@]}"
  sudo -E apt-get autoremove -qq -y
  sudo -E apt-get autoclean -qq -y
  sudo -E apt-get clean -qq -y
fi
