#!/usr/bin/env bash
# 初回 apply 時に一度だけ実行されるセットアップ。
# シェル変更・ディレクトリ作成・mise 本体の導入・push 用 remote の切り替え。
set -eu

check_command() {
  command -v "$1" >/dev/null 2>&1
}

warn() {
  printf "\e[1;33m%s\e[m\n" "$1" >&2
}

cd "$HOME"

printf "\e[1;36mChange default shell to zsh\e[m\n"
# zsh の実パスはディストリで異なる（/bin/zsh, /usr/bin/zsh など）ので command -v で検出する。
ZSH_PATH="$(command -v zsh || true)"
# 現在のログインシェルは $SHELL ではなく /etc/passwd を見る。
# $SHELL はプロセスを起動したシェルを指すだけで、設定済みのログインシェルとは限らない
# （例: ログインシェルは /usr/bin/zsh なのに $SHELL は /bin/zsh のことがある）。
CURRENT_SHELL="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
# /bin/zsh と /usr/bin/zsh のような symlink 差で誤検知しないよう実パスで比較する。
resolve() { readlink -f "$1" 2>/dev/null || echo "$1"; }
if [ -z "$ZSH_PATH" ]; then
  printf "zsh is not installed yet; skipping chsh (run after zsh is installed).\n"
elif [ "$(resolve "$CURRENT_SHELL")" != "$(resolve "$ZSH_PATH")" ]; then
  # ここから先の失敗で apply を止めない。実機では chsh が通らない状況が普通にある
  # （LDAP/SSSD 管理のアカウントは拒否される、sudo が無いと /etc/shells も書けない）。
  # ログインシェルが変わらないだけの話で、後続の mise install や補完生成まで
  # 巻き添えにする理由がない。手で直せるよう、失敗時はコマンドを提示する。
  #
  # chsh は /etc/shells に載っているシェルしか受け付けないので、未登録なら追記する。
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

# SSH 鍵は Bitwarden から取得する（private_dot_ssh/*.tmpl が bitwarden 関数で展開する）。
# ログイン（run_once_before_02）とアンロック（chezmoi.toml の bitwarden.unlock=true）は
# 鍵取得が必要なときに apply が自動で促すので、事前準備は不要。export BW_SESSION も bw login も手で打たなくてよい。
# 鍵生成（ssh-keygen）は廃止。全マシンで同じ鍵を共有する。

# ZDOTDIR は chezmoi が展開する ~/.zshenv（dot_zshenv）が宣言する。
# /etc/zsh/zshenv への追記はしない（root や他ユーザーまで巻き込み、sudo が必要で
# chezmoi の管理外になるため）。

printf "\e[1;36mSource zshenv configuration file\e[m\n"
# .zshenv は zsh 前提（$ZSH_VERSION 等を参照）なので、bash の set -u 下で
# source すると未定義変数で落ちる。この source の間だけ -u を外す。
set +u
. "$HOME/.config/zsh/.zshenv"
set -u

printf "\e[1;36mMake directories\e[m\n"
mkdir -p "$HOME/.local/state/zsh" "$HOME/.cache/zsh"
# ssh は ControlPath のディレクトリを自分では作らない。config.d は Include 用
# （マシン固有・非公開のホスト定義を置く場所。~/.ssh/config 参照）。
mkdir -p "$HOME/.ssh/control" "$HOME/.ssh/config.d"
chmod 700 "$HOME/.ssh/control" "$HOME/.ssh/config.d"

printf "\e[1;36mInstall mise\e[m\n"
# .zshenv は既に source 済みなので $HOME/.local/bin は PATH 上にある
# -f が無いと HTTP エラーの本文をそのまま sh に流してしまうので付ける。
check_command mise || curl -fsSL https://mise.run | sh
# 新規インストール時はまだ mise が PATH 外なので明示的に呼ぶ
MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
# self-update は standalone インストール専用で、ディストリのパッケージや nix/brew で
# 入れた mise では失敗する。更新できないだけなので apply は止めない
# （止めると後続の 30-mise-install / 40-zsh-completions がまるごと走らなくなる）。
"$MISE" self-update -y ||
  warn "mise self-update failed (not a standalone install?). Update it with your package manager."

printf "\e[1;36mSwitch dotfiles remote to SSH for push\e[m\n"
# ワンライナー導入では HTTPS で clone される（鍵が無くても clone できるように）。
# 以降 push できるよう、ソースリポジトリの origin を SSH に張り替える。
#
# ソースの場所は chezmoi がスクリプトに渡す CHEZMOI_SOURCE_DIR から取る。
# `chezmoi source-path` は使わない。初回のワンライナー導入では chezmoi 本体が
# まだ PATH に無く（インストーラが絶対パスで呼ぶ）、コマンドが見つからないまま
# フォールバックの既定パスに落ちて .git が無いと判定され、この差し替えが黙って
# 行われなかった。
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
