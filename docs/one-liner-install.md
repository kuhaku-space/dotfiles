# ワンライナーインストールの設計記録

新規マシンで dotfiles を一発導入できるようにした際の設計判断の記録。

## ワンライナー

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/kuhaku-space/dotfiles.git
```

`get.chezmoi.io` が chezmoi 本体を取得し、`--` 以降を `chezmoi` にそのまま渡す。`init --apply` で「clone → `$HOME` 展開 → `run_once_`/`run_onchange_` 実行」まで一気に走る。

## 設計判断

### ソースは chezmoi デフォルト（`~/.local/share/chezmoi`）

ghq 配下に置く運用もできるが、ワンライナーをシンプルに保つため新規マシンでは chezmoi 標準の場所に clone する。`chezmoi apply` / `chezmoi update` がそのまま使える。

### clone は HTTPS、push は SSH

新規マシンには SSH 鍵が無い（鍵生成は `run_once_` の中でやる）ので、**clone は HTTPS** でなければ鶏卵問題になる。一方で日常運用の push には SSH を使いたい。そこで：

- clone は public リポジトリへの HTTPS で行う。
- `run_once_after_10-setup.sh` の末尾で、origin が HTTPS GitHub のときだけ SSH へ張り替える。

### URL を明示する（`user/repo` 短縮形を使わない）

chezmoi の `kuhaku-space/dotfiles` 短縮形は `https://kuhaku-space@github.com/...` と **ユーザー名付き** URL を生成し、public リポジトリでも認証を要求してしまう。素の `https://github.com/kuhaku-space/dotfiles.git` を明示すると認証なしで clone できる。

### スクリプトの実行順（apt → setup → mise）

`run_once_after_10-setup.sh` は zsh / git / sudo など apt で入るツールに依存する。そのため apt を先に走らせる必要があり、apt パッケージのスクリプトを `05-` プレフィックスにして setup（`10-`）より前に置いた。実行順はファイル名のソート順（`05` → `10` → `30`）。

### chsh はシェルの実パスを検出する

zsh の実体はディストリで `/bin/zsh` だったり `/usr/bin/zsh` だったりする。`command -v zsh` で検出し、`/etc/shells` に未登録なら追記してから `chsh` する。zsh 未インストール時はスキップして `set -eu` で全体が止まらないようにする（通常は apt が先に zsh を入れる）。
