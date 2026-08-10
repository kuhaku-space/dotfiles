#!/usr/bin/env bash
# zsh 補完スクリプトを fpath 配下へ生成する。
# このファイルの内容が変わると chezmoi が再実行する(run_onchange)。
# 補完を追加・更新したいときは、末尾の gen 行を足す/版を変えるだけでよい。
set -eu

COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
mkdir -p "$COMP_DIR"

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

CHEZMOI="$(command -v chezmoi || echo "$HOME/.local/bin/chezmoi")"
gen chezmoi "$CHEZMOI" completion zsh
gen gh gh completion -s zsh
gen deno deno completions zsh
gen jj jj util completion zsh
gen zellij zellij setup --generate-completion zsh
gen bw env BITWARDENCLI_APPDATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/Bitwarden CLI" bw completion --shell zsh
gen bat bat --completion zsh

MISE="$(command -v mise || echo "$HOME/.local/bin/mise")"
if [ -x "$MISE" ]; then
  # mise 自身の補完は静的に置く。毎起動 `mise completion zsh` を eval すると
  # subprocess 1回分（実測 約30ms）が起動時間に乗る。
  gen mise "$MISE" completion zsh
  gen typst "$MISE" exec typst@latest -- typst completions zsh
else
  printf "mise is not installed. Skipping mise-managed completions...\n"
fi
# 追加例:
# gen ripgrep "$MISE" exec ripgrep@latest -- rg --generate complete-zsh

# 補完ファイルが増減した後も compinit はキャッシュ済みのダンプを再利用しうるので、
# ここで捨てて次のシェル起動で作り直させる。
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-"*
printf "  dropped stale zcompdump\n"
