#!/usr/bin/env bash
# テンプレート評価（private_dot_ssh/*.tmpl の bitwarden 関数）より前に bw CLI を保証する。
# run_before_ は全ファイル展開の前に走るため、ここで bw を入れておけば SSH 鍵テンプレートが解決できる。
# 継続的なバージョン管理は mise（bitwarden）に任せ、ここは初回ブートストラップ専用。
set -eu

SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

# 鍵が既に正しく置かれている（＝bw を呼ぶ必要がない）なら、導入もしない。
# CI もここで抜ける。判定は .chezmoiignore と同じ条件。
if ! bash "$SOURCE_DIR/scripts/needs-bitwarden.sh"; then
  printf "SSH key already matches the repository's public key; skipping bw bootstrap.\n"
  exit 0
fi

if command -v bw >/dev/null 2>&1; then
  exit 0
fi

# mise 管理版が既にあればそれを PATH に乗せて再確認する。
if command -v mise >/dev/null 2>&1 && mise which bw >/dev/null 2>&1; then
  exit 0
fi

printf "\e[1;36mBootstrap Bitwarden CLI (bw)\e[m\n"

# 取得先は mise.lock を唯一の出典にする。
#
# 以前は vault.bitwarden.com の ?app=cli&platform=linux を直接叩いていたが、あれは
# x86_64 のビルドしか返さないので、arm64 の実機では取れた bw が Exec format error に
# なり、鍵テンプレートの評価に失敗していた。lock には mise が記録したプラットフォーム別の
# URL と sha256 があるので、アーキテクチャを選べてチェックサム検証まで付く。
# （この経路は mise 本体より前に走るので mise 自体はまだ使えない。lock を直接読む）
LOCK="$SOURCE_DIR/dot_config/mise/private_mise.lock"
if [ ! -r "$LOCK" ]; then
  printf "mise lockfile not found: %s\n" "$LOCK" >&2
  exit 1
fi

MACHINE="$(uname -m)"
case "$MACHINE" in
  x86_64 | amd64) PLATFORM="linux-x64" ;;
  aarch64 | arm64) PLATFORM="linux-arm64" ;;
  *)
    printf "No bw build is known for this architecture: %s\n" "$MACHINE" >&2
    printf "Install bw manually (or via mise) and re-run chezmoi apply.\n" >&2
    exit 1
    ;;
esac

# [tools.bitwarden."platforms.<plat>"] ブロックから 1 フィールド取り出す。
# python も jq も使わない（ブートストラップ時点では何も入っていない前提）。
lock_field() {
  awk -v section="[tools.bitwarden.\"platforms.$PLATFORM\"]" -v key="$1" '
    $0 == section { in_section = 1; next }
    in_section && /^\[/ { exit }
    in_section && $1 == key { gsub(/"/, "", $3); print $3; exit }
  ' "$LOCK"
}

URL="$(lock_field url)"
CHECKSUM="$(lock_field checksum)"
if [ -z "$URL" ]; then
  printf "No bitwarden entry for %s in %s\n" "$PLATFORM" "$LOCK" >&2
  exit 1
fi

# unzip を入れるのは run_once_after_05 で、このスクリプトより後に走る。
# 「後で入るから」と落とすと最小構成のインストールでは初回 apply が必ず失敗するので、
# ここで確保してしまう。apt が無い環境では従来どおり手動導入を促す。
if ! command -v unzip >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  printf "Installing unzip (required to extract bw)\n"
  # 入れられなくても直後のチェックで手動導入を促すので、ここでは落とさない。
  if sudo apt-get update -qq; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip || true
  fi
fi
if ! command -v unzip >/dev/null 2>&1; then
  printf "unzip is required to extract bw but is not installed.\n" >&2
  printf "Install it (e.g. sudo apt install -y unzip) and re-run chezmoi apply.\n" >&2
  exit 1
fi

DEST="$HOME/.local/bin"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/bw.zip"

# 落としたバイナリはこの直後に実行される（鍵の取得）。配布経路の改竄に気付けるよう、
# lock が記録している sha256 と突き合わせてから展開する。
case "$CHECKSUM" in
  sha256:*)
    if command -v sha256sum >/dev/null 2>&1; then
      if ! printf '%s  %s\n' "${CHECKSUM#sha256:}" "$TMP/bw.zip" | sha256sum -c - >/dev/null 2>&1; then
        printf "Checksum mismatch for %s\n" "$URL" >&2
        printf "  expected %s\n" "${CHECKSUM#sha256:}" >&2
        printf "  actual   %s\n" "$(sha256sum "$TMP/bw.zip" | cut -d' ' -f1)" >&2
        exit 1
      fi
    else
      printf "sha256sum not found; skipping checksum verification.\n" >&2
    fi
    ;;
  *)
    printf "No usable checksum for %s in the lockfile; skipping verification.\n" "$PLATFORM" >&2
    ;;
esac

unzip -oq "$TMP/bw.zip" -d "$TMP/extracted"
BW_BIN="$(find "$TMP/extracted" -maxdepth 2 -type f -name bw -print -quit)"
if [ -z "$BW_BIN" ]; then
  printf "No bw binary inside %s\n" "$URL" >&2
  exit 1
fi
install -m 0755 "$BW_BIN" "$DEST/bw"

printf "Installed bw (%s) to %s\n" "$PLATFORM" "$DEST/bw"
