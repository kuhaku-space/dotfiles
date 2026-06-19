# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles。WSL2 (Ubuntu) 上の zsh 環境を想定。

ファイルは chezmoi のソース命名規則で保存している（`dot_config/` → `~/.config/`、`dot_zshrc` → `.zshrc` など）。`chezmoi apply` で `$HOME` に展開される。

> yadm からの移行記録は [docs/migration-yadm-to-chezmoi.md](docs/migration-yadm-to-chezmoi.md) を参照。

## セットアップ

このリポジトリは [ghq](https://github.com/x-motemen/ghq) 配下に置き、それを chezmoi のソースディレクトリとして使う。

```sh
# chezmoi を入れる（未インストールの場合）
sh -c "$(curl -fsLS get.chezmoi.io)"  # もしくは mise u -g chezmoi

# リポジトリを取得
ghq get ssh://git@github.com/kuhaku-space/dotfiles.git

# このリポジトリをソースに指定して初期化＆展開
#   --apply で展開と同時にセットアップスクリプト（run_once_/run_onchange_）が走る
chezmoi init --source "$(ghq root)/github.com/kuhaku-space/dotfiles" --apply
```

`--source` は `~/.config/chezmoi/chezmoi.toml` に記録されるので、以降は単に `chezmoi apply` / `chezmoi update` でよい。

`chezmoi apply` 時に走るスクリプトは、実行頻度ごとに分割している（ファイル名のソート順で実行される）:

| スクリプト | タイミング | 内容 |
| --- | --- | --- |
| [run_once_after_10-setup.sh](run_once_after_10-setup.sh) | 初回1回だけ | デフォルトシェルを zsh に変更 / SSH 鍵（`id_ed25519`・`signing-key`）の生成 / `/etc/zsh/zshenv` への `ZDOTDIR` 追記 / ディレクトリ作成 / [mise](https://mise.jdx.dev/) 本体の導入 |
| [run_once_after_15-apt-packages.sh](run_once_after_15-apt-packages.sh) | 初回1回だけ | `apt` パッケージ（build-essential, libssl-dev, keychain, zsh など）の不足分を install |
| [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) | `mise/config.toml` が変わったとき | `mise install` / `mise prune` で開発ツールを同期 |

`run_once_` はスクリプト内容のハッシュ、`run_onchange_` は変更検知（mise は config.toml のハッシュ）で実行要否を判定する。後から apt パッケージを追加したいときは、`run_once_after_15-apt-packages.sh` を手動実行するか直接 `apt install` する。

`README.md` は [.chezmoiignore](.chezmoiignore) でリポジトリには置くが `$HOME` には展開しない。

## 日常の操作

```sh
chezmoi edit ~/.config/zsh/.zshrc   # ソースを編集
chezmoi apply                       # $HOME に反映
chezmoi git -- status               # ソースリポジトリの状態を確認
chezmoi git -- commit -am "..."     # コミット
chezmoi git -- push                 # push
chezmoi update                      # pull + apply
```

リポジトリ（ソース）に未コミットの変更があると、zsh 起動時に `[warn] DIRTY DOTFILES` が表示される（[.config/zsh/.zshrc](dot_config/zsh/dot_zshrc) の `warn_dirty`）。

## 構成

| パス | 内容 |
| --- | --- |
| [dot_config/zsh/](dot_config/zsh/) | zsh 設定（`.zshenv` / `.zshrc`） |
| [dot_config/mise/config.toml](dot_config/mise/config.toml) | mise が管理する開発ツール一覧 |
| [dot_config/sheldon/plugins.toml](dot_config/sheldon/plugins.toml) | zsh プラグイン（[sheldon](https://sheldon.cli.rs/)） |
| [dot_config/zeno/config.yml](dot_config/zeno/config.yml) | [zeno.zsh](https://github.com/yuki-yano/zeno.zsh) のスニペット |
| [dot_config/git/](dot_config/git/) | git 設定 |
| [dot_config/npm/](dot_config/npm/), [dot_config/pnpm/](dot_config/pnpm/) | Node パッケージマネージャ設定 |
| `run_once_after_*` / `run_onchange_after_*` | `chezmoi apply` 時に走るセットアップ／同期スクリプト（[セットアップ](#セットアップ)参照） |

## ツールの追加・更新

開発ツールは mise で管理している。追加・更新は config を編集して `mise install`:

```sh
mise use -g <tool>   # config.toml に追記してインストール
mise upgrade         # 更新
```
