#!/usr/bin/env bash
# mise.lock に記録された版が実際に入っているか確認する。
#
# 版指定は config.toml では "latest" のままで、実際に入る版は mise.lock が決める。
# つまり lock が効いていないと、マシンごとに違う版が入っても誰も気付かない。
# それを機械的に見張るのがこのスクリプト。CI の bootstrap ジョブが呼ぶ。
#
# 使い方:
#   check-mise-lock.sh              lock に載っている全ツールを検査
#   check-mise-lock.sh bat eza      指定したツールだけ検査（未インストールの環境用）
#
# python も jq も使わない（素の Ubuntu コンテナで動かすため）。
set -euo pipefail

LOCK="${MISE_LOCK:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/mise.lock}"
if [ ! -r "$LOCK" ]; then
  printf 'lockfile not found: %s\n' "$LOCK" >&2
  exit 1
fi

MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
if [ ! -x "$MISE" ]; then
  printf 'mise not found\n' >&2
  exit 1
fi

# lock 内の [[tools.<name>]] 直後の version を取り出す。
# `npm:foo` のように記号を含む名前は TOML のキーが引用されるので、
# 引用符を落としてから比較する。
locked_version() {
  awk -v name="$1" '
    {
      line = $0
      gsub(/"/, "", line)
      if (line == "[[tools." name "]]") { found = 1; next }
    }
    found && $1 == "version" { gsub(/"/, "", $3); print $3; exit }
    found && /^\[/ { exit }
  ' "$LOCK" || true
}

# 実際に使われている版（mise ls --current の2列目）。
# 未知のツール名では mise が失敗しうるので、失敗は「空」として扱う。
current_version() {
  { "$MISE" ls --current "$1" 2>/dev/null || true; } | awk 'NR == 1 { print $2 }'
}

tools=("$@")
if [ ${#tools[@]} -eq 0 ]; then
  mapfile -t tools < <(sed -n 's/^\[\[tools\.\(.*\)\]\]$/\1/p' "$LOCK" | tr -d '"')
fi

failed=0
for tool in "${tools[@]}"; do
  locked="$(locked_version "$tool")"
  current="$(current_version "$tool")"
  if [ -z "$locked" ]; then
    printf '  %-24s not in lockfile\n' "$tool" >&2
    failed=1
  elif [ -z "$current" ]; then
    printf '  %-24s locked %s, not installed\n' "$tool" "$locked" >&2
    failed=1
  elif [ "$locked" != "$current" ]; then
    printf '  %-24s locked %s, but %s is in use\n' "$tool" "$locked" "$current" >&2
    failed=1
  else
    printf '  %-24s %s\n' "$tool" "$current"
  fi
done

if [ "$failed" -ne 0 ]; then
  printf '\nInstalled tools do not match mise.lock.\n' >&2
  printf 'Run "mise install" to converge, or "mise upgrade" to move the lock forward.\n' >&2
  exit 1
fi
