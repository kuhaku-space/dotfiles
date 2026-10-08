#!/usr/bin/env bash
set -eu

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
  "pkgconf"
  "libssl-dev"
  "cmake"
  "xclip"
  "wl-clipboard"
  "fontconfig"
)

print_manual_install() {
  printf "\e[1;33m%s\e[m\n" "$1" >&2
  printf "Install the equivalent of these packages with your package manager,\n" >&2
  printf "otherwise zsh / keychain / clipboard / builds will not work:\n" >&2
  printf "  %s\n" "${PACKAGES[@]}" >&2
}

if ! command -v apt-get >/dev/null 2>&1; then
  print_manual_install "apt is not available on this system."
  exit 0
fi

MISSING_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed$"; then
    MISSING_PACKAGES+=("$pkg")
  fi
done

if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
  exit 0
fi

SUDO=()
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1 || ! sudo -v; then
    print_manual_install "Cannot run apt-get as root (sudo is unavailable or denied)."
    exit 0
  fi
  SUDO=(sudo)
fi

printf "\e[1;36mInstall apt packages: %s\e[m\n" "${MISSING_PACKAGES[*]}"
"${SUDO[@]}" apt-get update -qq
"${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
  apt-get install -qq -y "${MISSING_PACKAGES[@]}"
