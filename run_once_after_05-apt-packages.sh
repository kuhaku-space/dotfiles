#!/usr/bin/env bash
# 初回 apply 時に一度だけ実行され、不足している apt パッケージを install する。
# 後からパッケージを追加した場合は手動で apt install するか、このスクリプトを実行すること。
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

PACKAGES=(
  # ここから下は dotfiles 自体が依存する。ワンライナー導入では curl と git が
  # 既にある前提になるが、最小構成のインストールだと入っていないことがあり、
  # その場合 chezmoi の git 操作・pre-commit hook・ghq が動かない。
  "ca-certificates"
  "curl"
  "git"
  # ssh-keygen。鍵の判定（.chezmoiignore / needs-bitwarden.sh）と git の ssh 署名が要求する。
  "openssh-client"
  "unzip"
  "zsh"
  "keychain"
  "jq"
  # ビルド用（Rust の openssl-sys など）
  "build-essential"
  "libssl-dev"
  "libclang-dev"
  "cmake"
  # クリップボード。zsh の clip 関数が X11 / Wayland のどちらでも動くよう両方入れる
  # （実機のデスクトップは Wayland が既定のことが多く、xclip だけでは足りない）。
  "xclip"
  "wl-clipboard"
  # Nerd Font の登録に fc-cache が要る（run_once_after_15-nerd-font.sh）。
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
  # apt ではなく apt-get を使う。apt はスクリプトから呼ぶと
  # "does not have a stable CLI interface" を毎回 stderr に出す。
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get update -qq
  sudo -E apt-get install -qq -y "${MISSING_PACKAGES[@]}"
  sudo -E apt-get autoremove -qq -y
  sudo -E apt-get autoclean -qq -y
  sudo -E apt-get clean -qq -y
fi
