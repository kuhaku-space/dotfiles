#!/usr/bin/env bash
# apply が Bitwarden を必要とするか判定する（exit 0 = 必要 / exit 1 = 不要）。
#
# run_once_before_01（bw の導入）と run_once_before_02（bw login）から呼ばれる。
# 判定条件は .chezmoiignore と同じで「ローカルの ~/.ssh/id_ed25519 が、リポジトリ内の
# 公開鍵 private_dot_ssh/id_ed25519.pub と同じ鍵か」。同じなら鍵を取り直す必要が
# ないので、bw の導入もログインも走らせない（＝マスターパスワードを聞かれない）。
#
# CI では Bitwarden 認証ができないため常に「不要」を返す（.chezmoiignore 側も
# CI では鍵を無視する）。
set -eu

if [ -n "${CI:-}" ]; then
  exit 1
fi

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
PUB="$SOURCE_DIR/private_dot_ssh/id_ed25519.pub"
KEY="$HOME/.ssh/id_ed25519"

# 期待値が読めない、鍵が無い、ssh-keygen が無い → 判定できないので「必要」に倒す。
if ! command -v ssh-keygen >/dev/null 2>&1; then exit 0; fi
if [ ! -r "$PUB" ] || [ ! -r "$KEY" ]; then exit 0; fi

fp() { ssh-keygen -lf "$1" 2>/dev/null | grep -o 'SHA256:[^ ]*' || true; }

EXPECTED="$(fp "$PUB")"
LOCAL="$(fp "$KEY")"

if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$LOCAL" ]; then
  exit 1
fi
exit 0
