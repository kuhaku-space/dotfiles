#!/usr/bin/env bash
# テンプレート評価（private_dot_ssh/*.tmpl の bitwarden 関数）より前に bw へのログインを保証する。
# アンロック（マスターパスワード入力）は chezmoi.toml の bitwarden.unlock=true が自動で行うが、
# ログイン自体は認証情報（メール+マスターパスワード or API キー）が必要なため無人化できない。
# 未ログインのときだけここで対話的に bw login を促し、ワンライナー導入だけで鍵取得まで到達できるようにする。
# run_once のため初回セットアップ時に一度だけ走る。後からログアウトした場合は、apply 失敗後に手で bw login すればよい。
set -eu

# 鍵が既に正しく置かれているなら鍵の取得自体が起きないので、ログインも求めない。
# （ここを見ないと「ログアウト状態 + 鍵は正しい」マシンで無用な bw login を促す）
# CI もここで抜ける。判定は .chezmoiignore と同じ条件。
if ! bash "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/scripts/needs-bitwarden.sh"; then
  printf "SSH key already matches the repository's public key; skipping bw login.\n"
  exit 0
fi

# run_once_before_01 で ~/.local/bin に入れた直後はまだ PATH 外のことがあるので bw を明示的に解決する。
BW="$(command -v bw || true)"
if [ -z "$BW" ] && command -v mise >/dev/null 2>&1; then
  BW="$(mise which bw 2>/dev/null || true)"
fi
if [ -z "$BW" ] && [ -x "$HOME/.local/bin/bw" ]; then
  BW="$HOME/.local/bin/bw"
fi
if [ -z "$BW" ]; then
  printf "bw not found; cannot ensure Bitwarden login.\n" >&2
  exit 1
fi

# bw status は未ログインでも JSON を返す（exit 0）。status が unauthenticated のときだけ login する。
# locked / unlocked（＝既にログイン済み）なら何もしない。アンロックは unlock=true 側に任せる。
STATUS="$("$BW" status 2>/dev/null | tr -d '[:space:]' || true)"
case "$STATUS" in
  *'"status":"unauthenticated"'*)
    printf "\e[1;36mLog in to Bitwarden (bw login)\e[m\n"
    "$BW" login
    ;;
  *)
    printf "Already logged in to Bitwarden; skipping bw login.\n"
    ;;
esac
