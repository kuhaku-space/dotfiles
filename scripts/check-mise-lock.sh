#!/usr/bin/env bash
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
