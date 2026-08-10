# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles。WSL2 (Ubuntu) 上の zsh 環境を想定。

ファイルは chezmoi のソース命名規則で保存している（`dot_config/` → `~/.config/`、`dot_zshrc` → `.zshrc` など）。`chezmoi apply` で `$HOME` に展開される。

> 個別の設計と移行記録は `docs/` 配下に置いている。SSH 鍵は [ssh-keys-bitwarden.md](docs/ssh-keys-bitwarden.md)、zsh の起動時間は [zsh-startup.md](docs/zsh-startup.md)、移行記録は [migration-yadm-to-chezmoi.md](docs/migration-yadm-to-chezmoi.md) と [migration-etc-zshenv-to-home-zshenv.md](docs/migration-etc-zshenv-to-home-zshenv.md)（`ZDOTDIR` の宣言場所を `/etc/zsh/zshenv` から `~/.zshenv` へ移した件。既存マシンで `/etc` を元に戻す手順を含む）。

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
| [run_once_before_01-bitwarden-cli.sh](run_once_before_01-bitwarden-cli.sh) | 初回1回だけ（ファイル展開**前**） | `bw` CLI が無ければ公式ネイティブバイナリで先行導入。SSH 鍵テンプレートが `bw` を使うため、テンプレート評価前に保証する必要がある |
| [run_once_before_02-bitwarden-login.sh](run_once_before_02-bitwarden-login.sh) | 初回1回だけ（ファイル展開**前**） | 未ログインなら対話的に `bw login` を起動。鍵テンプレートの取得前にログインを保証する（アンロックは `bitwarden.unlock=true` が自動で実行） |
| [run_once_after_05-apt-packages.sh](run_once_after_05-apt-packages.sh) | 初回1回だけ | `apt` パッケージ（build-essential, libssl-dev, keychain, zsh, unzip, xclip など）の不足分を install |
| [run_once_after_10-setup.sh](run_once_after_10-setup.sh) | 初回1回だけ | デフォルトシェルを zsh に変更 / ディレクトリ作成 / [mise](https://mise.jdx.dev/) 本体の導入 / push 用 remote を SSH へ切り替え |
| [run_onchange_after_20-git-hooks.sh](run_onchange_after_20-git-hooks.sh) | スクリプト内容が変わったとき | ソースリポジトリの `core.hooksPath` を `.githooks/` に設定（秘密情報の pre-commit 検査。後述） |
| [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) | `mise/config.toml` が変わったとき | `mise install` / `mise prune` で開発ツールを同期 |
| [run_onchange_after_40-zsh-completions.sh](run_onchange_after_40-zsh-completions.sh) | スクリプト内容が変わったとき | zsh 補完を `~/.local/share/zsh/completions` に生成（chezmoi, gh, deno, jj, zellij, bw, bat, mise, typst）。生成後に `zcompdump` を捨てて次回起動で作り直させる |

apt（05）を setup（10）より先に実行するのは、setup が zsh / git / sudo など apt で入るツールに依存するため。後から apt パッケージを追加したいときは、05 を手動実行するか直接 `apt install` する。

鍵が既に正しく置かれているマシンでは、01/02 は [scripts/needs-bitwarden.sh](scripts/needs-bitwarden.sh) の判定で何もせず抜ける。SSH 鍵の設計と初回マシンでの取得手順は [docs/ssh-keys-bitwarden.md](docs/ssh-keys-bitwarden.md)。

## 日常の操作

```sh
$EDITOR ~/.config/zsh/.zshrc        # $HOME 側の実ファイルを編集
chezmoi re-add ~/.config/zsh/.zshrc # 変更をソースへ取り込む
chezmoi diff                        # 反映差分を確認
chezmoi apply                       # $HOME に反映
chezmoi update                      # pull + apply
```

基本は `$HOME` 側の実ファイルを編集して `chezmoi re-add` でソースへ取り込む。`README.md` や `docs/` は [.chezmoiignore](.chezmoiignore) で `$HOME` に展開しないため、リポジトリ上のファイルを直接編集する。

同期状態は `dotfiles-status`（[.config/zsh/.zshrc](dot_config/zsh/dot_zshrc)）でまとめて見る。未コミット・未 push（`git status --short --branch`）と、`$HOME` とソースの差分（`chezmoi status`）の両方を出す。

ズレたまま `apply` すると、chezmoi が最後に書いた後に変わったファイルは `diff/overwrite/skip` を聞かれるが、**chezmoi が一度も書いていないファイル（新規マシンの既存ファイル等）は聞かれずに上書きされる**。

変更を保存・同期するときだけ、ソースリポジトリで Git 操作を行う:

```sh
chezmoi git -- status
chezmoi git -- add .
chezmoi git -- commit -m "..."
chezmoi git -- push
```

### 秘密情報を commit しないための歯止め

[chezmoi.toml](.chezmoi.toml.tmpl) で `git.autoCommit` / `autoPush` を有効にしているので、**ソースに入ったものは即座に public リポジトリへ出る**。そこで [scripts/check-secrets.sh](scripts/check-secrets.sh) が秘密鍵・トークン類のパターンを検査し、[.githooks/pre-commit](.githooks/pre-commit) が commit を止める。フックは clone しただけでは有効にならないので、[run_onchange_after_20-git-hooks.sh](run_onchange_after_20-git-hooks.sh) が `core.hooksPath` を設定する。CI では追跡中の全ファイルと**全履歴の blob** に対して同じ検査を走らせる。

```sh
bash scripts/check-secrets.sh --staged    # pre-commit と同じ検査
bash scripts/check-secrets.sh --tracked   # 追跡中の全ファイル
bash scripts/check-secrets.sh --history   # 全コミットの全 blob
```

誤検知したときは `--no-verify` で抜けるのではなく、スクリプトの `PATTERNS` を直す。

## CI/CD

GitHub Actions の [CI/CD](.github/workflows/ci-cd.yml) で、pull request / `main`・`master` への push / 手動実行時に検証する。ジョブは2つ:

| ジョブ | 内容 |
| --- | --- |
| `validate` | shellcheck（`*.sh` と hook）、`zsh -n`（zsh 設定と sheldon の inline スニペット）、actionlint、秘密情報スキャン、chezmoi テンプレート展開、TOML/YAML 構文、git config と allowed_signers の検証 |
| `bootstrap` | 素の `ubuntu:24.04` コンテナで README のワンライナーと同じ経路（`chezmoi init --apply` → `run_once_*` → `run_onchange_*`）を実際に流し、展開結果・ログインシェル・対話 zsh の起動・生成物・**mise.lock 通りの版が入ったか**を検証する |

`bootstrap` が秘密情報なしで通るのは `CI=true` のとき [.chezmoiignore](.chezmoiignore) が鍵を無視し、[scripts/needs-bitwarden.sh](scripts/needs-bitwarden.sh) が bw 関連スクリプトを空振りさせるため。**CI では mise はシェル起動に必要なツールだけを入れる**（対象と理由は [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) のコメント参照）。

lint は同じものをローカルでも回せる（`shellcheck` と `actionlint` は mise 管理）:

```sh
shellcheck -e SC1091 run_once_*.sh run_onchange_*.sh* scripts/*.sh .githooks/*
zsh -n dot_zshenv dot_config/zsh/dot_zshenv dot_config/zsh/dot_zshrc
actionlint
```

## 構成

| パス | 内容 |
| --- | --- |
| [dot_zshenv](dot_zshenv) | `ZDOTDIR` を宣言して `$ZDOTDIR/.zshenv` を source するだけの stub（`$HOME` に置く必要がある唯一の zsh ファイル）。zsh の探索順と `/etc/zsh/zshenv` を使わない理由はファイル冒頭のコメント参照 |
| [dot_config/zsh/](dot_config/zsh/) | zsh 設定本体（`.zshenv` / `.zshrc`）。`EDITOR` / `VISUAL` の定義もここ |
| [dot_config/mise/](dot_config/mise/) | mise が管理する開発ツール一覧（`config.toml`）と、版・URL・チェックサムを固定する `mise.lock` |
| [dot_config/sheldon/plugins.toml](dot_config/sheldon/plugins.toml) | zsh プラグイン（[sheldon](https://sheldon.cli.rs/)）。読み込み順の約束はファイル冒頭のコメント参照 |
| [dot_config/zeno/config.yml](dot_config/zeno/config.yml) | [zeno.zsh](https://github.com/yuki-yano/zeno.zsh) のスニペット |
| [dot_config/git/](dot_config/git/) | git 設定（`config` / `ignore` / ssh 署名の `allowed_signers`） |
| [dot_config/jj/config.toml](dot_config/jj/config.toml) | [jujutsu](https://jj-vcs.github.io/jj/) の設定。jj は git の設定を読まないので別に要る |
| [dot_config/npm/](dot_config/npm/), [dot_config/pnpm/](dot_config/pnpm/) | Node パッケージマネージャ設定 |
| [private_dot_ssh/](private_dot_ssh/) | ssh 鍵・クライアント設定・GitHub のホスト鍵（[docs/ssh-keys-bitwarden.md](docs/ssh-keys-bitwarden.md)） |
| `run_once_*` / `run_onchange_*` | `chezmoi apply` 時に走るセットアップ／同期スクリプト（[セットアップ](#セットアップ)参照） |
| [scripts/](scripts/) | `$HOME` に展開しないスクリプト。手動実行用（`revert-etc-zshenv.sh`）と、`apply` や CI・hook から呼ぶ共有ヘルパー（`needs-bitwarden.sh` / `check-secrets.sh` / `check-mise-lock.sh`） |
| [.githooks/](.githooks/) | ソースリポジトリの git hook。`.` 始まりなので chezmoi は `$HOME` に展開しない |

## zsh の起動

`update` 関数（[.zshrc](dot_config/zsh/dot_zshrc)）で dotfiles / apt / mise / sheldon をこの順に更新する（dotfiles が先頭なのは意図的。理由は関数のコメント）。sheldon のプラグインは `plugins.lock` に固定されるので、`sheldon lock --update` を通さないと古いままになる。

起動は約 100ms。測り方と、何を defer / キャッシュ / 静的生成にしているかは [docs/zsh-startup.md](docs/zsh-startup.md)。

## ツールの追加・更新

開発ツールは mise で管理している。追加・更新は config を編集して `mise install`:

```sh
mise use -g <tool>   # config.toml に追記してインストール
mise upgrade         # 更新（lock も進む）
```

### バージョンの固定（mise.lock）

版指定は `latest` のままだが、**実際に入る版は [mise.lock](dot_config/mise/private_mise.lock) が決める**（`[settings] lockfile = true`。詳細は [config.toml](dot_config/mise/config.toml) 冒頭のコメント）。

```sh
mise lock --global   # lock を作る／更新する（-g が無いと "No tools configured to lock"）
mise lock -g --bump  # latest 等を再解決して lock を進める（インストールはしない）
```

`mise.lock` は `$HOME` 側で書き換わる生成物なので、更新したらソースへ取り込む必要がある。取り込まないと次の `chezmoi apply` が古い lock で上書きしてしまう。`update` 関数はこれを自動でやる。手で更新するときは:

```sh
chezmoi update                      # 先に pull する（後述）
mise upgrade
chezmoi re-add ~/.config/mise/mise.lock
```

> pull を飛ばすと、他のマシンが進めた lock と rebase でコンフリクトする（生成物なので同じ行が両方で変わる）。そうなったら手でマージせず `chezmoi git -- rebase --abort` して上をやり直す。

lock と実際に入っている版がずれていないかは次で確認できる（CI の `bootstrap` ジョブも実行する）:

```sh
bash scripts/check-mise-lock.sh          # lock の全ツール
bash scripts/check-mise-lock.sh bat eza  # 指定したものだけ
```

zsh 補完を静的生成したい CLI は [run_onchange_after_40-zsh-completions.sh](run_onchange_after_40-zsh-completions.sh) に `gen <name> <command...>` を追加する。生成先は `~/.local/share/zsh/completions` で、[.zshenv](dot_config/zsh/dot_zshenv) がこのディレクトリを `fpath` の先頭へ登録している。`zoxide` は sheldon 側で動的に初期化しているため、このスクリプトでは生成しない。
