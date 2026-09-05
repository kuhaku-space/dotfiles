# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している、Linux 向けの dotfiles。主な検証環境は WSL2 (Ubuntu) と実機の Ubuntu。

chezmoi のソース命名規則（`dot_config/` → `~/.config/`、`dot_zshrc` → `.zshrc` など）でファイルを保存し、`chezmoi apply` で `$HOME` に展開する。

apt 以外のディストリビューションでも利用できるが、パッケージ導入は自動化していない。必要なパッケージは [run_once_after_05-apt-packages.sh](run_once_after_05-apt-packages.sh) が表示する。実機 Linux 固有の注意点は [docs/current/bare-metal-linux.md](docs/current/bare-metal-linux.md) を参照する。

## セットアップ

新しいマシンでは、次のコマンドで chezmoi の導入、リポジトリの取得、設定の展開、セットアップを行う。

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/kuhaku-space/dotfiles.git
```

SSH 鍵が必要な場合は、途中で Bitwarden へのログインとアンロックを求められる。事前準備と鍵の扱いは [SSH 鍵（Bitwarden 連携）](docs/current/ssh-keys-bitwarden.md) を参照する。

すでに別の場所へ clone したリポジトリをソースにする場合:

```sh
chezmoi init --source <path> --apply
```

セットアップスクリプトの実行順や処理内容は [スクリプトの役割と設計](docs/current/scripts.md) にまとめている。

## 日常の操作

基本は `$HOME` 側のファイルを編集し、ソースへ取り込んでから反映する。

```sh
$EDITOR ~/.config/zsh/.zshrc
chezmoi re-add ~/.config/zsh/.zshrc
chezmoi diff
chezmoi apply
chezmoi update                       # pull + apply
```

`README.md` と `docs/` は `$HOME` へ展開されないため、リポジトリ上で直接編集する。

同期状態は `dotfiles-status` で確認できる。Git の未 commit・未 push と、ソースと `$HOME` の差分をまとめて表示する。

Git を直接操作する場合:

```sh
chezmoi git -- status
chezmoi git -- add .
chezmoi git -- commit -m "..."
chezmoi git -- push
```

このリポジトリは chezmoi の autoCommit / autoPush を有効にしている。秘密情報を検出すると pre-commit hook が commit を止めるため、誤検知でも `--no-verify` で回避せず検出パターンを修正する。検査方法は [Secrets and signing](docs/commands.md#secrets-and-signing) を参照する。

## ツールの更新

開発ツールは mise で管理している。

```sh
mise use -g <tool>                    # ツールを追加
mise upgrade                         # ツールと lockfile を更新
chezmoi re-add ~/.config/mise/mise.lock
```

普段は `.zshrc` の `update` 関数で dotfiles、apt、mise、Sheldon をまとめて更新できる。mise のバージョン固定と zsh 補完生成の仕組みは [設定ファイルの設計](docs/current/configuration.md#mise) と [スクリプトの役割と設計](docs/current/scripts.md#refresh-zsh-completions) を参照する。

## 構成

| パス | 内容 |
| --- | --- |
| [dot_config/zsh/](dot_config/zsh/) | zsh の環境・対話設定 |
| [dot_config/mise/](dot_config/mise/) | mise のツール設定と lockfile |
| [dot_config/sheldon/](dot_config/sheldon/) | zsh プラグイン設定 |
| [dot_config/git/](dot_config/git/) / [dot_config/jj/](dot_config/jj/) | Git と Jujutsu の設定 |
| [private_dot_ssh/](private_dot_ssh/) | SSH 鍵テンプレートとクライアント設定 |
| [dot_local/bin/](dot_local/bin/) | `~/.local/bin` へ展開するコマンド |
| `run_before_*` / `run_once_*` / `run_onchange_*` | `chezmoi apply` 時に実行するスクリプト |
| [scripts/](scripts/) | 手動実行・hook・CI 用の補助スクリプト |

## ドキュメント

設計や運用上の詳細は [ドキュメント索引](docs/INDEX.md) から選ぶ。変更後の検証コマンドは [docs/commands.md](docs/commands.md) にまとめている。

CI は GitHub Actions の [`ci-cd.yml`](.github/workflows/ci-cd.yml) で、構文・秘密情報・chezmoi テンプレートと、素の Ubuntu 上でのセットアップ経路を検証する。
