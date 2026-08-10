# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles。WSL2 (Ubuntu) 上の zsh 環境を想定。

ファイルは chezmoi のソース命名規則で保存している（`dot_config/` → `~/.config/`、`dot_zshrc` → `.zshrc` など）。`chezmoi apply` で `$HOME` に展開される。

> 移行記録は `docs/` 配下に置いている。yadm → chezmoi は [docs/migration-yadm-to-chezmoi.md](docs/migration-yadm-to-chezmoi.md)、`ZDOTDIR` の宣言場所を `/etc/zsh/zshenv` から `~/.zshenv` へ移した件（既存マシンで `/etc` を元に戻す手順を含む）は [docs/migration-etc-zshenv-to-home-zshenv.md](docs/migration-etc-zshenv-to-home-zshenv.md) を参照。

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
| [run_once_before_01-bitwarden-cli.sh](run_once_before_01-bitwarden-cli.sh) | 初回1回だけ（ファイル展開**前**） | `bw` CLI が無ければ公式ネイティブバイナリで先行導入。SSH 鍵テンプレート（後述）が `bw` を使うため、テンプレート評価前に保証する必要がある |
| [run_once_before_02-bitwarden-login.sh](run_once_before_02-bitwarden-login.sh) | 初回1回だけ（ファイル展開**前**） | 未ログインなら対話的に `bw login` を起動。鍵テンプレートの取得前にログインを保証する（アンロックは `bitwarden.unlock=true` が自動で実行） |
| [run_once_after_05-apt-packages.sh](run_once_after_05-apt-packages.sh) | 初回1回だけ | `apt` パッケージ（build-essential, libssl-dev, keychain, zsh, unzip, xclip など）の不足分を install |
| [run_once_after_10-setup.sh](run_once_after_10-setup.sh) | 初回1回だけ | デフォルトシェルを zsh に変更 / ディレクトリ作成 / [mise](https://mise.jdx.dev/) 本体の導入 / push 用 remote を SSH へ切り替え（SSH 鍵は Bitwarden 連携で取得。後述） |
| [run_onchange_after_20-git-hooks.sh](run_onchange_after_20-git-hooks.sh) | スクリプト内容が変わったとき | ソースリポジトリの `core.hooksPath` を `.githooks/` に設定（秘密情報の pre-commit 検査。後述） |
| [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) | `mise/config.toml` が変わったとき | `mise install` / `mise prune` で開発ツールを同期 |
| [run_onchange_after_40-zsh-completions.sh](run_onchange_after_40-zsh-completions.sh) | スクリプト内容が変わったとき | zsh 補完を `~/.local/share/zsh/completions` に生成（chezmoi, gh, deno, jj, zellij, bw, bat, mise, typst）。生成後に `zcompdump` を捨てて次回起動で作り直させる |

apt（05）を setup（10）より先に実行するのは、setup が zsh / git / sudo など apt で入るツールに依存するため。`run_once_` はスクリプト内容のハッシュ、`run_onchange_` は変更検知（mise は config.toml のハッシュ、それ以外はスクリプト内容のハッシュ）で実行要否を判定する。後から apt パッケージを追加したいときは、`run_once_after_05-apt-packages.sh` を手動実行するか直接 `apt install` する。

鍵が既に正しく置かれているマシンでは、01/02 は [scripts/needs-bitwarden.sh](scripts/needs-bitwarden.sh) の判定で何もせず抜ける（bw の導入もログインの催促もしない）。判定条件は [.chezmoiignore](.chezmoiignore) と同じ。

`README.md` は [.chezmoiignore](.chezmoiignore) でリポジトリには置くが `$HOME` には展開しない。

## SSH 鍵（Bitwarden 連携）

**秘密鍵**は Bitwarden の **SSH Key item** 1件に保存し、`chezmoi apply` 時に取得して `~/.ssh/` へ展開する。1つの鍵を認証と git 署名の両方に使う。リポジトリには秘密鍵そのものも暗号化済みの秘密鍵も置かず、取得テンプレートだけが入る。全マシンで同じ鍵を共有する（マシンごとの鍵生成はしない）。**公開鍵は秘密ではない**ので平文でリポジトリに置く。

| ファイル | 展開先 | パーミッション | 用途 |
| --- | --- | --- | --- |
| [private_dot_ssh/private_id_ed25519.tmpl](private_dot_ssh/private_id_ed25519.tmpl) | `~/.ssh/id_ed25519` | 0600 | 秘密鍵（認証 + 署名）。Bitwarden から取得 |
| [private_dot_ssh/id_ed25519.pub](private_dot_ssh/id_ed25519.pub) | `~/.ssh/id_ed25519.pub` | 0644 | 公開鍵（git の `signingKey` が参照）。平文 |
| [private_dot_ssh/private_config](private_dot_ssh/private_config) | `~/.ssh/config` | 0600 | ssh クライアント設定 |
| [private_dot_ssh/private_known_hosts.chezmoi](private_dot_ssh/private_known_hosts.chezmoi) | `~/.ssh/known_hosts.chezmoi` | 0600 | GitHub のホスト鍵（初回 push の TOFU 確認を出さないため） |

公開鍵を平文で持つのは、**鍵の期待値の出典を1箇所にする**ため。[.chezmoiignore](.chezmoiignore) はこのファイルからフィンガープリントを都度導出して「ローカルの鍵が期待どおりか」を判定し、[allowed_signers](dot_config/git/allowed_signers.tmpl) もこのファイルを `include` する。鍵をローテーションするときに差し替えるのはこの1ファイルだけでよく、フィンガープリントを別途書き写す必要がない。ついでに公開鍵の取得で `bw` を呼ばなくなる。

Bitwarden の SSH Key item（名前 `github`）を **item ID で**指定して取得する（`github` という名前の item が複数あり、名前指定だと曖昧になるため）。テンプレートは `{{ (bitwarden "item" "<item-id>").sshKey.privateKey }}` で鍵本体を取り出す。git の署名鍵は [git config](dot_config/git/config) で `~/.ssh/id_ed25519.pub` を指している。`bw` CLI は初回は [run_once_before_01-bitwarden-cli.sh](run_once_before_01-bitwarden-cli.sh) が公式バイナリで先行導入し、以降は mise（`bitwarden`）で管理する。

### ssh クライアント設定

`~/.ssh/config` は管理下にあるが、このリポジトリは public なので**マシン固有・非公開のホスト（研究室や社内のホスト名・IP・ユーザー名）は書かない**。それらは `~/.ssh/config.d/*.conf` に置き、管理下の `config` が先頭で `Include` する（glob なのでファイルが無いマシンでもエラーにならない）。ssh は「最初に見つかった値」を採用するため、上書きしたい定義を先に読ませる必要がある。

`~/.ssh/known_hosts.chezmoi` には GitHub の公開ホスト鍵を入れて、`UserKnownHostsFile` の2番目として渡している（1番目の `~/.ssh/known_hosts` が書き込み先）。これで新規マシンの初回 push でホスト鍵の確認プロンプトが出ない。更新は `curl -fsS https://api.github.com/meta | jq -r .ssh_keys[]`。

> **既存マシンでの注意**: `~/.ssh/config` が管理下に入ったので、`chezmoi apply` は既存の `~/.ssh/config` を**上書きする**。ローカルにホスト定義があるマシンでは、apply する前に退避しておく:
>
> ```sh
> mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh/config.d
> cp ~/.ssh/config ~/.ssh/config.d/local.conf && chmod 600 ~/.ssh/config.d/local.conf
> chezmoi diff ~/.ssh/config   # 上書き内容を確認してから
> chezmoi apply
> ```

> ファイル展開（テンプレート評価）は `run_after_` スクリプトより前に走るため、`bw` の導入を `run_before_` に置いている。これにより初回ワンライナーでも鍵テンプレートが解決できる。

### 初回マシンでの取得手順

事前準備は不要。鍵取得が必要なときに、セットアップが順に **bw 導入 → ログイン → アンロック** まで自動で促す。だから新しいマシンでも[セットアップ](#セットアップ)のワンライナー1本でよく、`export BW_SESSION=...` も `bw login` も手で打つ必要はない（入力自体は対話で求められる）。内訳:

| 段階 | 担当 | 自動化の中身 |
| --- | --- | --- |
| 導入 | [run_once_before_01-bitwarden-cli.sh](run_once_before_01-bitwarden-cli.sh) | `bw` が無ければ公式バイナリで先行導入 |
| ログイン | [run_once_before_02-bitwarden-login.sh](run_once_before_02-bitwarden-login.sh) | 未ログインなら対話的に `bw login` を起動（メール+マスターパスワード+2FA を入力）。ログイン済みなら何もしない |
| アンロック | [chezmoi.toml](.chezmoi.toml.tmpl) の `bitwarden.unlock = true` | テンプレート評価時に chezmoi が自動で `bw unlock` を実行（マスターパスワードを入力） |

> **ログインだけは無人化できない**。`bw login` は認証情報（メール+マスターパスワード、または API キー）を必要とし、それを public リポジトリに置けないため。上記はあくまで「適切なタイミングで自動的に入力を促す」もので、入力そのものは対話になる。非対話で済ませたい場合（CI など）は `BW_CLIENTID` / `BW_CLIENTSECRET` を環境変数に設定して `bw login --apikey` を使う方法があるが、API キーの取り扱いに注意。

鍵が既に正しく配置済み（ローカルの鍵のフィンガープリントがリポジトリの公開鍵と一致）のときは、[.chezmoiignore](.chezmoiignore) が鍵を管理対象から外し、[scripts/needs-bitwarden.sh](scripts/needs-bitwarden.sh) が 01/02 を空振りさせるので、通常の `chezmoi apply` では bw の導入・ログイン・アンロックのいずれも走らない。鍵を新しいマシンに増やしたいときは、Bitwarden の Web/アプリで対応する SSH Key item を作っておけばよい。

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

> 以前はシェル起動ごとに未コミットを警告していた（`warn_dirty`）が、やめた。見ていたのはソースの作業ツリーだけで、**一番危ないズレ（`$HOME` の実ファイルを直接編集して `re-add` を忘れる＝次の `apply` で消える）を検知できていなかった**。未 push も見ていない。加えて `autoCommit` / `autoPush` が commit と push を自動で行うので警告すべき対象がほとんど残らない。消せない警告を全シェルで鳴らす価値はないと判断した。

変更を保存・同期するときだけ、ソースリポジトリで Git 操作を行う:

```sh
chezmoi git -- status
chezmoi git -- add .
chezmoi git -- commit -m "..."
chezmoi git -- push
```

### 秘密情報を commit しないための歯止め

[chezmoi.toml](.chezmoi.toml.tmpl) で `git.autoCommit` / `autoPush` を有効にしているので、**ソースに入ったものは即座に public リポジトリへ出る**。例えば（鍵がまだ一致していないマシンで）`chezmoi add ~/.ssh/id_ed25519` を打つと、平文の秘密鍵がそのまま push される。

そこで [scripts/check-secrets.sh](scripts/check-secrets.sh) が秘密鍵・トークン類のパターンを検査し、[.githooks/pre-commit](.githooks/pre-commit) が commit を止める。フックは clone しただけでは有効にならないので、[run_onchange_after_20-git-hooks.sh](run_onchange_after_20-git-hooks.sh) が `core.hooksPath` を設定する。CI では追跡中の全ファイルと**全履歴の blob** に対して同じ検査を走らせる。

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

`bootstrap` が秘密情報なしで通るのは `CI=true` のとき [.chezmoiignore](.chezmoiignore) が鍵を無視し、[scripts/needs-bitwarden.sh](scripts/needs-bitwarden.sh) が bw 関連スクリプトを空振りさせるため。**CI では mise はシェル起動に必要なツールだけを入れる**（rust / node / neovim まで入れると 30 分を超えるため。対象は [run_onchange_after_30-mise-install.sh.tmpl](run_onchange_after_30-mise-install.sh.tmpl) 参照）。

lint は同じものをローカルでも回せる（`shellcheck` と `actionlint` は mise 管理）:

```sh
shellcheck -e SC1091 run_once_*.sh run_onchange_*.sh* scripts/*.sh .githooks/*
zsh -n dot_zshenv dot_config/zsh/dot_zshenv dot_config/zsh/dot_zshrc
actionlint
```

## 構成

| パス | 内容 |
| --- | --- |
| [dot_zshenv](dot_zshenv) | `ZDOTDIR` を宣言して `$ZDOTDIR/.zshenv` を source するだけの stub（`$HOME` に置く必要がある唯一の zsh ファイル） |
| [dot_config/zsh/](dot_config/zsh/) | zsh 設定本体（`.zshenv` / `.zshrc`）。`EDITOR` / `VISUAL` の定義もここ |
| [dot_config/mise/](dot_config/mise/) | mise が管理する開発ツール一覧（`config.toml`）と、版・URL・チェックサムを固定する `mise.lock` |
| [dot_config/sheldon/plugins.toml](dot_config/sheldon/plugins.toml) | zsh プラグイン（[sheldon](https://sheldon.cli.rs/)）。読み込み順の約束はファイル冒頭のコメント参照 |
| [dot_config/zeno/config.yml](dot_config/zeno/config.yml) | [zeno.zsh](https://github.com/yuki-yano/zeno.zsh) のスニペット |
| [dot_config/git/](dot_config/git/) | git 設定（`config` / `ignore` / ssh 署名の `allowed_signers`） |
| [dot_config/jj/config.toml](dot_config/jj/config.toml) | [jujutsu](https://jj-vcs.github.io/jj/) の設定。jj は git の設定を読まないので別に要る |
| [dot_config/npm/](dot_config/npm/), [dot_config/pnpm/](dot_config/pnpm/) | Node パッケージマネージャ設定 |
| [private_dot_ssh/](private_dot_ssh/) | ssh 鍵・クライアント設定・GitHub のホスト鍵（[SSH 鍵](#ssh-鍵bitwarden-連携)参照） |
| `run_once_*` / `run_onchange_*` | `chezmoi apply` 時に走るセットアップ／同期スクリプト（[セットアップ](#セットアップ)参照） |
| [scripts/](scripts/) | `$HOME` に展開しないスクリプト。手動実行用（`revert-etc-zshenv.sh`）と、`apply` や CI・hook から呼ぶ共有ヘルパー（`needs-bitwarden.sh` / `check-secrets.sh` / `check-mise-lock.sh`） |
| [.githooks/](.githooks/) | ソースリポジトリの git hook。`.` 始まりなので chezmoi は `$HOME` に展開しない |

### ZDOTDIR を `~/.zshenv` で宣言する理由

zsh は `ZDOTDIR` 未設定なら `$HOME` を `ZDOTDIR` とみなすため、`~/.zshenv` だけは `$HOME` 直下に置くしかない。ここで `ZDOTDIR` を設定しても読むファイルは既に確定しているので、本体（`$ZDOTDIR/.zshenv`）は明示的に source する。`.zprofile` / `.zshrc` / `.zlogin` は `ZDOTDIR` 確定後に読まれるため転送は不要。

以前は `/etc/zsh/zshenv` に `ZDOTDIR` を追記していたが、やめた。あのファイルは root を含む全ユーザーの全 zsh 起動（非対話スクリプトも）で読まれ、`zsh -f` 以外では読み込みを止められない（`NO_GLOBAL_RCS` が効くのは `zprofile` 以降）。そこに個人の `$HOME` を絶対パスで焼き込むと `sudo zsh` した root が他人の設定を読む。加えて sudo が必要で chezmoi の管理外（`chezmoi diff` に出ない）になり、zsh 更新時に conffile の競合を起こす。

**既存マシンの移行**: 以前の追記が残っていると `/etc` 側が先に `ZDOTDIR` を設定するので `~/.zshenv` は読まれない（挙動は変わらないが root への影響も消えない）。1度だけ `/etc/zsh/zshenv` を元に戻す必要がある。[scripts/revert-etc-zshenv.sh](scripts/revert-etc-zshenv.sh) を実行すれば一括で済む（`--dry-run` で差分確認可、何度実行しても安全）。背景・手動手順・復元方法は [docs/migration-etc-zshenv-to-home-zshenv.md](docs/migration-etc-zshenv-to-home-zshenv.md)。新規マシンでは不要。

## zsh の起動

`update` 関数（[.zshrc](dot_config/zsh/dot_zshrc)）で apt / mise / sheldon / dotfiles をまとめて更新する。sheldon のプラグインは `plugins.lock` に固定されるので、`sheldon lock --update` を通さないと古いままになる。ツールが入れ替わると生成物（starship の init 出力・補完ダンプ）が古くなるため、`update` はそれらのキャッシュも捨てる。

起動時間は `hyperfine -w 5 -r 50 'zsh -i -c exit'`（zeno スニペット `benchmark`）で測る。現状は約 **100ms**（改善前は 210ms）。プロンプト表示に間に合わせる必要のない処理は [zsh-defer](https://github.com/romkatv/zsh-defer) に回している。defer した処理はプロンプトを待たせないだけで消えるわけではないので、**そもそも要らない処理は消す**方が先:

| 処理 | 扱い | 理由 |
| --- | --- | --- |
| keychain / ssh-agent | defer | プロンプト表示に不要 |
| `compinit` | defer | 約 30ms。**fpath を広げるプラグインより後**に走らせる必要がある |
| `zoxide init` | defer | `z` を打つまでに間に合えばよい |
| `starship init` | キャッシュ | プロンプトなので defer できない。出力を `$XDG_CACHE_HOME/zsh/starship-init.zsh` に保存 |
| `mise completion` | 静的生成 | 毎起動の subprocess をやめ、補完ファイルとして `fpath` に置く |
| `bindkey` | defer | widget を定義するプラグイン（zeno / autosuggestions）が defer なので、即時に張ると読み込み前の入力が `No such widget` で捨てられる |

`apply = ["defer"]` は **inline プラグインには効かない**（テンプレートは `files` を展開するためのもの）。inline を遅延したいときは自分で `zsh-defer` を書く。読み込み順の約束は [plugins.toml](dot_config/sheldon/plugins.toml) 冒頭のコメントにまとめてある。

## ツールの追加・更新

開発ツールは mise で管理している。追加・更新は config を編集して `mise install`:

```sh
mise use -g <tool>   # config.toml に追記してインストール
mise upgrade         # 更新（lock も進む）
```

### バージョンの固定（mise.lock）

版指定は `latest` のままだが、**実際に入る版は [mise.lock](dot_config/mise/private_mise.lock) が決める**（`[settings] lockfile = true`）。lock には版に加えて URL とチェックサムが入るので、他のマシンでも同じ版が入り、ダウンロード内容も検証される。

```sh
mise lock --global   # グローバル設定の lock を作る／更新する（-g が必要）
mise lock -g --bump  # latest 等を再解決して lock を進める（インストールはしない）
```

> `-g` を付けないとプロジェクトの config root しか見ないため、`No tools configured to lock` になる。

`mise.lock` は `$HOME` 側で書き換わる生成物なので、更新したらソースへ取り込む必要がある。取り込まないと次の `chezmoi apply` が古い lock で上書きしてしまう。`update` 関数はこれを自動でやる（`mise upgrade` → `chezmoi re-add ~/.config/mise/mise.lock`。chezmoi の `autoCommit` / `autoPush` が commit と push まで行う）。手で `mise upgrade` したときは:

```sh
chezmoi re-add ~/.config/mise/mise.lock
```

lock と実際に入っている版がずれていないかは次で確認できる（CI の `bootstrap` ジョブも実行する）:

```sh
bash scripts/check-mise-lock.sh          # lock の全ツール
bash scripts/check-mise-lock.sh bat eza  # 指定したものだけ
```

zsh 補完を静的生成したい CLI は [run_onchange_after_40-zsh-completions.sh](run_onchange_after_40-zsh-completions.sh) に `gen <name> <command...>` を追加する。生成先は `~/.local/share/zsh/completions` で、[.zshenv](dot_config/zsh/dot_zshenv) がこのディレクトリを `fpath` の先頭へ登録している。`zoxide` は sheldon 側で動的に初期化しているため、このスクリプトでは生成しない。
