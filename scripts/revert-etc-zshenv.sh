#!/usr/bin/env bash
# /etc/zsh/zshenv に追記した ZDOTDIR を取り除き、パッケージ同梱の内容に戻す。
# ZDOTDIR の宣言は chezmoi 管理下の ~/.zshenv（ソースは dot_zshenv）が担う。
# 背景と手動手順: docs/migration-etc-zshenv-to-home-zshenv.md
#
# 既存マシンで1度だけ実行する。chezmoi apply からは呼ばれない（sudo を
# apply の経路に戻さないため、手動実行にしている）。何度実行しても安全。
#
#   scripts/revert-etc-zshenv.sh             # 実行
#   scripts/revert-etc-zshenv.sh --dry-run   # 変更せず差分だけ表示
set -eu

ETC_ZSHENV=/etc/zsh/zshenv
STUB="$HOME/.zshenv"
EXPECTED_ZDOTDIR="$HOME/.config/zsh"
DRY_RUN=0

info() { printf '\e[1;36m%s\e[m\n' "$1"; }
ok() { printf '\e[1;32m%s\e[m\n' "$1"; }
warn() { printf '\e[1;33m%s\e[m\n' "$1"; }
die() {
  printf '\e[1;31m%s\e[m\n' "$1" >&2
  exit 1
}

case "${1:-}" in
  -n | --dry-run) DRY_RUN=1 ;;
  "") ;;
  *)
    printf 'usage: %s [-n|--dry-run]\n' "$0" >&2
    exit 2
    ;;
esac

[ -f "$ETC_ZSHENV" ] ||
  die "$ETC_ZSHENV が無い。zsh がパッケージで入っていない環境か、パスが異なる。"

# --- 0. 先に ~/.zshenv を配置する ----------------------------------------
# /etc 側を消すと ZDOTDIR が未設定になり、zsh は $HOME を ZDOTDIR とみなす。
# stub が無い状態でこれをやると、新しいシェルが設定なしの素の zsh になる。
info "Check ZDOTDIR stub"
if [ -f "$STUB" ]; then
  ok "  $STUB は配置済み"
elif [ "$DRY_RUN" -eq 1 ]; then
  warn "  $STUB が無い（本番実行時に chezmoi apply で配置する）"
elif command -v chezmoi >/dev/null 2>&1; then
  warn "  $STUB が無いので chezmoi apply で配置する"
  chezmoi apply "$STUB"
  [ -f "$STUB" ] || die "$STUB を配置できなかった。中止する。"
  ok "  $STUB を配置した"
else
  die "$STUB が無く chezmoi も見つからない。先に stub を配置すること。"
fi

# --- 1. 戻した後の内容を組み立てて差分を確認 -----------------------------
# 追記行を落としたうえで、末尾の余分な空行を1つの改行に正規化する
# （追記時に先頭 \n が入ったため、行を消すだけでは末尾が "fi\n\n" になり
#   dpkg が記録している md5 と1バイト食い違う）。
# $(...) が末尾の改行をすべて落とすので、printf で1つだけ付け直す。
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$(grep -v '^export ZDOTDIR=' "$ETC_ZSHENV" || true)" >"$TMP"

info "Check $ETC_ZSHENV"
REVERTED=1
if cmp -s "$TMP" "$ETC_ZSHENV"; then
  ok "  既に元の内容（変更不要）"
else
  diff -u "$ETC_ZSHENV" "$TMP" || true
  if [ "$DRY_RUN" -eq 1 ]; then
    REVERTED=0
    warn "  --dry-run: $ETC_ZSHENV は変更しない"
  else
    BACKUP="$HOME/zshenv.etc.bak.$(date +%Y%m%d%H%M%S)"
    cp "$ETC_ZSHENV" "$BACKUP"
    ok "  バックアップ: $BACKUP"
    sudo -v || die "sudo が必要（$ETC_ZSHENV の書き換えのみに使う）"
    # 既存ファイルへ内容を上書きするので owner/mode は root:root 644 のまま。
    sudo cp "$TMP" "$ETC_ZSHENV"
    ok "  $ETC_ZSHENV を更新した"
  fi
fi

if [ "$REVERTED" -eq 0 ]; then
  warn "--dry-run のため以降の検証は省略する（差分が未適用で意味を持たない）"
  info "Done"
  exit 0
fi

# --- 2. パッケージ同梱の内容と一致したか検証 -----------------------------
# 期待値は dpkg が持つ conffile の md5 記録から取る（zsh のバージョンが
# 変わっても追随する）。apt 系以外では検証を飛ばす。
if command -v dpkg-query >/dev/null 2>&1; then
  info "Verify against dpkg conffile record"
  # shellcheck disable=SC2016  # ${Conffiles} は dpkg-query の書式指定であり shell 変数ではない
  EXPECTED_MD5="$(
    dpkg-query -W -f='${Conffiles}\n' zsh-common 2>/dev/null |
      awk '$1=="/etc/zsh/zshenv"{print $2}'
  )"
  ACTUAL_MD5="$(md5sum "$ETC_ZSHENV" | cut -d' ' -f1)"
  if [ -z "$EXPECTED_MD5" ]; then
    warn "  zsh-common の conffile 記録が取れなかった（検証を飛ばす）"
  elif [ "$ACTUAL_MD5" = "$EXPECTED_MD5" ]; then
    ok "  md5 一致: $ACTUAL_MD5（zsh 更新時の conffile 競合は起きない）"
  else
    warn "  md5 不一致: $ACTUAL_MD5 (期待 $EXPECTED_MD5)"
    warn "  ZDOTDIR 以外の変更が入っている可能性がある。差分を確認すること。"
  fi
fi

# --- 3. ZDOTDIR が ~/.zshenv 経由で解決されるか確認 ----------------------
# 親シェルの値が漏れると検証にならないので、見る変数を環境から外して起動する。
# /etc が ZDOTDIR を設定しなくなった後なら、値の出所は ~/.zshenv だけ。
if command -v zsh >/dev/null 2>&1; then
  info "Verify ZDOTDIR resolution"
  # 3つの値を1回の起動でまとめて受け取り、色付けは親側で行う（子 zsh に直接
  # 出力させると無色の行が混ざって見た目が揃わない）。
  # shellcheck disable=SC2016  # 子プロセスの zsh に展開させるので単一引用符が正しい
  # HISTFILE も環境から外す。本体 .zshenv が export しているため、外さないと
  # 親の値を子が継承してしまい「本体が source されたか」の判定にならない。
  mapfile -t ZSH_VALUES < <(
    env -u ZDOTDIR -u HISTFILE zsh -c 'printf "%s\n" "$ZDOTDIR" "$HISTFILE" "$fpath[1]"'
  )
  ACTUAL_ZDOTDIR="${ZSH_VALUES[0]-}"
  ACTUAL_HISTFILE="${ZSH_VALUES[1]-}"
  ACTUAL_FPATH1="${ZSH_VALUES[2]-}"
  if [ "$ACTUAL_ZDOTDIR" != "$EXPECTED_ZDOTDIR" ]; then
    warn "  ZDOTDIR=${ACTUAL_ZDOTDIR:-(未設定)} (期待 $EXPECTED_ZDOTDIR)"
    warn "  $STUB の内容と、/etc 側に別の ZDOTDIR 設定が無いか確認すること。"
  elif [ -z "$ACTUAL_HISTFILE" ]; then
    # HISTFILE は本体 $ZDOTDIR/.zshenv が設定する。空なら stub が
    # ZDOTDIR を宣言しただけで本体を source できていない。
    warn "  ZDOTDIR=$ACTUAL_ZDOTDIR"
    warn "  HISTFILE が空。$STUB が本体（\$ZDOTDIR/.zshenv）を source できていない。"
  else
    ok "  ZDOTDIR=$ACTUAL_ZDOTDIR"
    ok "  HISTFILE=$ACTUAL_HISTFILE"
    ok "  fpath[1]=$ACTUAL_FPATH1"
  fi
fi

info "Done"
