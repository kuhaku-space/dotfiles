#!/usr/bin/env bash
# テンプレート評価（private_dot_ssh/*.tmpl の bitwarden 関数）より前に bw CLI を保証する。
# run_before_ は全ファイル展開の前に走るため、ここで bw を入れておけば SSH 鍵テンプレートが解決できる。
# 継続的なバージョン管理は mise（npm:@bitwarden/cli）に任せ、ここは初回ブートストラップ専用。
set -eu

if command -v bw >/dev/null 2>&1; then
  exit 0
fi

# mise 管理版が既にあればそれを PATH に乗せて再確認する。
if command -v mise >/dev/null 2>&1 && mise which bw >/dev/null 2>&1; then
  exit 0
fi

printf "\e[1;36mBootstrap Bitwarden CLI (bw)\e[m\n"

DEST="$HOME/.local/bin"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Bitwarden 公式のネイティブバイナリ zip（node 不要）。
URL="https://vault.bitwarden.com/download/?app=cli&platform=linux"
curl -fsSL "$URL" -o "$TMP/bw.zip"

if ! command -v unzip >/dev/null 2>&1; then
  printf "unzip is required to extract bw but is not installed.\n" >&2
  printf "Install it (e.g. sudo apt install -y unzip) and re-run chezmoi apply.\n" >&2
  exit 1
fi

unzip -oq "$TMP/bw.zip" -d "$TMP"
install -m 0755 "$TMP/bw" "$DEST/bw"

printf "Installed bw to %s\n" "$DEST/bw"
