#!/usr/bin/env bash
# zsh 補完スクリプトを fpath 配下へ生成する。
# このファイルの内容が変わると chezmoi が再実行する(run_onchange)。
# 補完を追加・更新したいときは、末尾の gen 行を足す/版を変えるだけでよい。
set -eu

COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
mkdir -p "$COMP_DIR"

MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
if [ ! -x "$MISE" ]; then
  printf "mise is not installed. Skipping completions...\n"
  exit 0
fi

# gen <name> <補完を zsh 用に出力するコマンド...>
# グローバルに置きたくないツールは `mise exec <tool>@<ver> --` 経由で呼ぶ。
gen() {
  name="$1"
  shift
  if out="$("$@" 2>/dev/null)" && [ -n "$out" ]; then
    printf '%s' "$out" >"$COMP_DIR/_$name"
    printf "  generated _%s\n" "$name"
  else
    printf "  skip _%s (generation failed)\n" "$name"
  fi
}

printf "\e[1;36mGenerate zsh completions\e[m\n"

gen typst "$MISE" exec typst@latest -- typst completions zsh
# 追加例:
# gen ripgrep "$MISE" exec ripgrep@latest -- rg --generate complete-zsh
