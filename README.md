# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles。WSL2 (Ubuntu) 上の zsh 環境を想定。

ファイルは chezmoi のソース命名規則で保存している（`dot_config/` → `~/.config/`、`dot_zshrc` → `.zshrc` など）。`chezmoi apply` で `$HOME` に展開される。

> yadm からの移行記録は [docs/migration-yadm-to-chezmoi.md](docs/migration-yadm-to-chezmoi.md) を参照。

## セットアップ

新しいマシンでは、次のワンライナーだけで導入が完結する（chezmoi 本体の導入 → リポジトリの取得 → `$HOME` への展開 → セットアップスクリプトの実行まで）。

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/kuhaku-space/dotfiles.git
```

- `get.chezmoi.io` が chezmoi 本体を一時的に取得し、`--` 以降をそのまま `chezmoi` に渡す。
- リポジトリは **HTTPS**（public）で `~/.local/share/chezmoi`（chezmoi のデフォルトソース）に clone される。SSH 鍵が無い新規マシンでも clone できる。
  - `kuhaku-space/dotfiles` という短縮形ではなく URL を明示しているのは、短縮形だと chezmoi が `https://kuhaku-space@github.com/...` とユーザー名付き URL を生成し、public リポジトリでも認証を要求してしまうため。
- `--apply` で展開と同時にセットアップスクリプト（`run_once_` / `run_onchange_`）が走る。`run_once_` 内で SSH 鍵生成・apt・mise 導入まで行い、最後に push 用 remote を SSH へ切り替える。

以降は単に `chezmoi apply` / `chezmoi update` でよい。chezmoi 本体は mise でも管理しているため、初回セットアップ後は mise 管理版が使われる。

> このマシンのように既にソースを別の場所（例: ghq 配下）へ clone 済みで、そこをソースにしたい場合は `chezmoi init --source <path> --apply` で初期化する。`--source` は `~/.config/chezmoi/chezmoi.toml` に記録される。

`chezmoi apply` 時に走るスクリプトは、実行頻度ごとに分割している（ファイル名のソート順で実行される）:

| スクリプト | タイミング | 内容 |
| --- | --- | --- |
| [run_once_after_05-apt-packages.sh](run_once_after_05-apt-packages.sh) | 初回1回だけ | `apt` パッケージ（build-essential, libssl-dev, keychain, zsh など）の不足分を install |
| [run_once_after_10-setup.sh](run_once_after_10-setup.sh) | 初回1回だけ | デフォルトシェルを zsh に変更 / SSH 鍵（`id_ed25519`・`signing-key`）の生成 / `/etc/zsh/zshenv` への `ZDOTDIR` 追記 / ディレクトリ作成 / [mise](https://mise.jdx.dev/) 本体の導入 / push 用 remote を SSH へ切り替え |
| [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) | `mise/config.toml` が変わったとき | `mise install` / `mise prune` で開発ツールを同期 |

apt（05）を setup（10）より先に実行するのは、setup が zsh / git / sudo など apt で入るツールに依存するため。`run_once_` はスクリプト内容のハッシュ、`run_onchange_` は変更検知（mise は config.toml のハッシュ）で実行要否を判定する。後から apt パッケージを追加したいときは、`run_once_after_05-apt-packages.sh` を手動実行するか直接 `apt install` する。

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
