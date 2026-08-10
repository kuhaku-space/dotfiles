#!/usr/bin/env bash
# 秘密情報がこのリポジトリに入るのを止める。
#
# 背景: chezmoi.toml で git.autoCommit / autoPush を有効にしているため、
# 例えば `chezmoi add ~/.ssh/id_ed25519` を打つと、平文の秘密鍵がソースに入って
# そのまま自動 commit → 自動 push され、public リポジトリに出てしまう。
# push の前に機械的に止める最後の砦がこれ。
#
# 使い方:
#   check-secrets.sh --staged    ステージ済みの変更を検査（pre-commit hook 用）
#   check-secrets.sh --tracked   追跡中の全ファイルを検査（CI 用）
#   check-secrets.sh --history   全コミットの全 blob を検査（CI 用。小さいリポジトリ前提）
set -euo pipefail

MODE="${1:---staged}"

# 検査から除外するパス。自分自身とフック本体はパターン定義を含むので必ず除外する。
is_excluded() {
  case "$1" in
    scripts/check-secrets.sh | .githooks/*) return 0 ;;
    *) return 1 ;;
  esac
}

# 検出パターン（名前|正規表現）。名前は検出時のメッセージに使う。
# パターン自身がヒットしないよう、文字クラスで1文字割っている。
PATTERNS=(
  "OpenSSH/PEM private key|-----BEGIN[ A-Z]*PRIVA[T]E KEY-----"
  "PuTTY private key|PuTTY-User-Key-File"
  "Bitwarden session token|BW_SESSION=[A-Za-z0-9+/=]{20,}"
  "GitHub token|gh[pousr]_[A-Za-z0-9]{20,}"
  "GitHub fine-grained token|github_pa[t]_[A-Za-z0-9_]{20,}"
  "AWS access key id|AKIA[0-9A-Z]{16}"
  "Slack token|xox[abprs]-[A-Za-z0-9-]{10,}"
  "Anthropic API key|sk-an[t]-[A-Za-z0-9_-]{20,}"
  "OpenAI API key|sk-proj-[A-Za-z0-9_-]{20,}"
)

found=0

# scan <表示名> <内容の取得コマンド...>
scan() {
  local label="$1"
  shift
  local content
  content="$("$@" 2>/dev/null || true)"
  [ -n "$content" ] || return 0

  local entry name regex
  for entry in "${PATTERNS[@]}"; do
    name="${entry%%|*}"
    regex="${entry#*|}"
    if printf '%s' "$content" | grep -Eq -- "$regex"; then
      printf '%s: %s\n' "$label" "$name" >&2
      found=1
    fi
  done
}

case "$MODE" in
  --staged)
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      is_excluded "$path" && continue
      scan "$path" git show ":$path"
    done < <(git diff --cached --name-only --diff-filter=ACM)
    ;;
  --tracked)
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      is_excluded "$path" && continue
      scan "$path" cat "$path"
    done < <(git ls-files)
    ;;
  --history)
    # <blob-sha> <path> の一覧。同じ blob が複数コミットに出ても一度で済む。
    while read -r sha path; do
      [ -n "${path:-}" ] || continue
      is_excluded "$path" && continue
      scan "$path (blob ${sha:0:8})" git cat-file blob "$sha"
    done < <(git rev-list --objects --all | awk 'NF==2 {print $1, $2}' | sort -u -k2,2 -k1,1)
    ;;
  *)
    printf 'usage: %s [--staged|--tracked|--history]\n' "$0" >&2
    exit 2
    ;;
esac

if [ "$found" -ne 0 ]; then
  cat >&2 <<'MSG'

Secret-looking content detected. Refusing to continue.

This repository is public and chezmoi has autoCommit/autoPush enabled, so a
commit here is effectively a publish. If this is a false positive, adjust
PATTERNS in scripts/check-secrets.sh; do not bypass with --no-verify.
MSG
  exit 1
fi
