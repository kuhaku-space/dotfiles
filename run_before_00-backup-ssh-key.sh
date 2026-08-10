#!/usr/bin/env bash
# Bitwarden 版の鍵で上書きされる前に、既存の ~/.ssh/id_ed25519 を退避する。
#
# chezmoi は「自分が一度も書いていないファイル」を確認なしで上書きする（README 参照）。
# 対象が秘密鍵だと、そのマシンで前から使っていた鍵が黙って消える。実機を後から
# dotfiles 管理下へ入れるとき（自分で ssh-keygen した鍵が既にある）に踏む。
#
# run_once_ ではなく毎 apply 走らせる。守りたいのは「鍵が置き換わる瞬間」であって
# 初回とは限らない（鍵をローテーションしたときも同じことが起きる）。鍵が一致して
# いれば何もしないので、通常の apply の負荷は ssh-keygen 2回分しかない。
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"
PUB="$SOURCE_DIR/private_dot_ssh/id_ed25519.pub"
KEY="$HOME/.ssh/id_ed25519"

# CI では鍵を展開しない（.chezmoiignore）ので、退避するものも無い。
[ -z "${CI:-}" ] || exit 0
[ -e "$KEY" ] || exit 0
command -v ssh-keygen >/dev/null 2>&1 || exit 0

fp() { ssh-keygen -lf "$1" 2>/dev/null | grep -o 'SHA256:[^ ]*' || true; }

EXPECTED="$(fp "$PUB")"
LOCAL="$(fp "$KEY")"

# 同じ鍵なら上書きされても失うものが無い。指紋が取れない場合（EXPECTED が空）は
# 比較が成立しないので、安全側に倒して退避する。
if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$LOCAL" ]; then
  exit 0
fi

STAMP="$(date +%Y%m%d%H%M%S)"
printf "\e[1;33mExisting SSH key differs from the one this repository manages.\e[m\n" >&2
printf "  local:    %s\n" "${LOCAL:-(fingerprint unavailable)}" >&2
printf "  expected: %s\n" "${EXPECTED:-(fingerprint unavailable)}" >&2

for f in "$KEY" "$KEY.pub"; do
  [ -e "$f" ] || continue
  # cp -p で mode を保つ。秘密鍵が 644 で残ると ssh がその鍵を拒否する。
  cp -p "$f" "$f.bak.$STAMP"
  printf "  backed up %s -> %s\n" "$f" "$f.bak.$STAMP" >&2
done

printf "chezmoi will now replace it with the key from Bitwarden.\n" >&2
