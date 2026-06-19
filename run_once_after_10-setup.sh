#!/usr/bin/env bash
# 初回 apply 時に一度だけ実行されるセットアップ。
# シェル変更・SSH 鍵生成・ZDOTDIR 追記・ディレクトリ作成・mise 本体の導入。
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

cd "$HOME"

printf "\e[1;36mChange default shell to zsh\e[m\n"
[ "$SHELL" = "/bin/zsh" ] || chsh -s /bin/zsh

printf "\e[1;36mGenerate SSH keys\e[m\n"
[ -e "$HOME/.ssh/id_ed25519" ] || ssh-keygen -a 128 -f "$HOME/.ssh/id_ed25519" -C "kuhakuspace2000@gmail.com"
[ -e "$HOME/.ssh/signing-key" ] || ssh-keygen -a 128 -f "$HOME/.ssh/signing-key" -C "kuhakuspace2000@gmail.com"

printf "\e[1;36mAppend ZDOTDIR to zshenv\e[m\n"
grep -q "export ZDOTDIR" /etc/zsh/zshenv ||
  printf '\nexport ZDOTDIR=%s\n' "$HOME/.config/zsh" | sudo tee -a /etc/zsh/zshenv

printf "\e[1;36mSource zshenv configuration file\e[m\n"
. "$HOME/.config/zsh/.zshenv"

printf "\e[1;36mMake directories\e[m\n"
mkdir -p "$HOME/.local/state/zsh" "$HOME/.cache/zsh"

printf "\e[1;36mInstall mise\e[m\n"
# .zshenv は既に source 済みなので $HOME/.local/bin は PATH 上にある
check_command mise || curl https://mise.run | sh
# 新規インストール時はまだ mise が PATH 外なので明示的に呼ぶ
MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
"$MISE" self-update -y
