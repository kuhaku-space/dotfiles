# スクリプトの役割と設計

chezmoi が実行するスクリプトと、リポジトリ内の補助コマンドについて、実行順・失敗時の扱い・実装上の理由をまとめる。各スクリプト自身には、shebang、chezmoi の変更検知用ハッシュ、ShellCheck 指示など、実行や検証に意味を持つコメントだけを置く。

`run_once_` はレンダリング後の内容ハッシュで実行済みか判定される。このためスクリプトを編集すると、適用済みのマシンでも次回の `chezmoi apply` で再実行される。各処理は再実行可能に保つ。

## apply 前の SSH 鍵と Bitwarden

### `run_before_00-backup-ssh-key.sh`

[run_before_00-backup-ssh-key.sh](../../run_before_00-backup-ssh-key.sh) は、Bitwarden の鍵で上書きされる前に、既存の `~/.ssh/id_ed25519` と公開鍵を日時付きバックアップへ退避する。chezmoi は自身が一度も配置していないファイルを確認なしで上書きするため、初回導入だけでなく鍵のローテーションでも毎回の `apply` 前に検査する。

リポジトリの公開鍵とローカル鍵の指紋が一致するときは何もしない。期待する指紋を取得できない場合は安全側に倒して退避し、`cp -p` で元の mode を維持する。CI では秘密鍵を展開しないため処理しない。

### `scripts/needs-bitwarden.sh`

[scripts/needs-bitwarden.sh](../../scripts/needs-bitwarden.sh) は Bitwarden が必要なら終了コード 0、不要なら 1 を返す。`run_once_before_01`、`run_once_before_02`、`.chezmoiignore` が共有する判定は次のとおり。

- CI では認証できず、鍵も展開しないため常に不要とする。
- ローカル秘密鍵とリポジトリの公開鍵から同じ指紋が得られれば不要とする。
- 鍵、公開鍵、または `ssh-keygen` がなく判定不能な場合は必要とする。

### `run_once_before_01-bitwarden-cli.sh`

[run_once_before_01-bitwarden-cli.sh](../../run_once_before_01-bitwarden-cli.sh) は、秘密鍵テンプレートの評価より前に `bw` CLI を用意する。鍵が既に一致している場合、PATH 上に `bw` がある場合、mise 管理版が利用できる場合は何もしない。

初回ブートストラップでは mise 自体がまだ使えないため、`mise.lock` を直接解析する。配布 URL と SHA-256 は lockfile を唯一の出典とし、x86_64 と arm64 に対応する。Python や jq がない最小環境を想定して awk で対象ブロックを読む。以前使っていた Bitwarden の汎用 Linux URL は x86_64 バイナリしか返さず、arm64 で実行できなかった。

`unzip` を通常導入する 05 より先に実行されるため、apt があればこのスクリプト自身が `unzip` の導入を試みる。取得物は lockfile の SHA-256 と照合してから `~/.local/bin/bw` に配置する。

### `run_once_before_02-bitwarden-login.sh`

[run_once_before_02-bitwarden-login.sh](../../run_once_before_02-bitwarden-login.sh) は、鍵の取得が必要で `bw status` が `unauthenticated` の場合だけ対話的なログインを開始する。`locked` と `unlocked` はログイン済みなので何もしない。アンロックは `.chezmoi.toml.tmpl` の `bitwarden.unlock = true` が担当する。

01 が `~/.local/bin` に配置した直後は PATH に反映されていない場合があるため、そこも明示的に探索する。後からログアウトした場合は手動で `bw login` してから再適用する。SSH 鍵全体の運用は [ssh-keys-bitwarden.md](ssh-keys-bitwarden.md) を参照する。

## apply 後のセットアップ

### `run_once_after_05-apt-packages.sh`

[run_once_after_05-apt-packages.sh](../../run_once_after_05-apt-packages.sh) は、初回に不足している apt パッケージだけを導入する。apt がない環境では必要なパッケージ一覧を表示して正常終了する。後から一覧を変更した場合は、スクリプトを再実行するか各ディストリビューションのパッケージマネージャで追加する。

パッケージの用途は次のとおり。

| 用途 | パッケージ |
| --- | --- |
| chezmoi、Git、hook、取得処理 | `ca-certificates`, `curl`, `git`, `openssh-client`, `unzip` |
| シェル環境 | `zsh`, `keychain`, `jq` |
| Rust などのビルド | `build-essential`, `libssl-dev`, `libclang-dev`, `cmake` |
| X11／Wayland クリップボード | `xclip`, `wl-clipboard` |
| Nerd Font の登録 | `fontconfig` |

非対話スクリプト向けの安定した CLI を使うため `apt` ではなく `apt-get` を呼ぶ。

### `run_once_after_10-setup.sh`

[run_once_after_10-setup.sh](../../run_once_after_10-setup.sh) はログインシェル、必要ディレクトリ、mise、Git remote を設定する。

- zsh の場所はディストリビューションにより異なるため `command -v` で得る。現在のログインシェルは `$SHELL` ではなく passwd database から取得し、symlink を解決して比較する。
- `chsh` は `/etc/shells` への登録を必要に応じて試す。LDAP/SSSD 管理や sudo のない環境では失敗しうるため、警告だけを出して後続処理を続ける。
- SSH 鍵は Bitwarden から取得し、ここでは生成しない。`ZDOTDIR` は chezmoi 管理の `~/.zshenv` が宣言し、`/etc/zsh/zshenv` は変更しない。
- zsh 用の `.zshenv` を bash から読む間は、zsh 専用変数による未定義エラーを避けるため `set -u` を一時解除する。
- SSH の ControlPath と非公開のホスト設定用に `~/.ssh/control` と `~/.ssh/config.d` を作成する。
- mise の取得には HTTP エラーを失敗にする `curl -f` を使う。standalone 以外の mise では `self-update` が失敗するため、警告だけにして後続のツール同期と補完生成を続ける。
- 初回は SSH 鍵なしでも clone できる HTTPS remote を使い、セットアップ後に push 用の SSH remote へ変更する。ソースの場所は、初回には chezmoi が PATH にない場合があるため `chezmoi source-path` ではなく `CHEZMOI_SOURCE_DIR` から得る。

### `run_once_after_15-nerd-font.sh`

[run_once_after_15-nerd-font.sh](../../run_once_after_15-nerd-font.sh) は実機 Linux に JetBrainsMono Nerd Font を導入する。CI は端末を持たず、WSL は Windows 側の端末が描画するため対象外とする。既存の Nerd Font を fontconfig が認識している場合も追加しない。

フォントは見た目だけに影響するので、ダウンロード、展開、キャッシュ更新の失敗では `apply` を止めない。大きなアーカイブから端末向け Mono の Regular、Bold、Italic、BoldItalic のみを展開し、命名変更などで一致しなければ全 TTF の展開へフォールバックする。導入後は端末エミュレータで `JetBrainsMono Nerd Font` を選択する必要がある。

### `run_onchange_after_20-git-hooks.sh`

[run_onchange_after_20-git-hooks.sh](../../run_onchange_after_20-git-hooks.sh) は `.githooks/` を `core.hooksPath` に設定する。dot directory は chezmoi の展開対象外であり、clone だけでは hook 設定も有効にならないため `apply` で保証する。

所有者不一致などで Git がソースをリポジトリとして扱えない場合、hook の設定失敗だけで `apply` 全体を止めず警告して終了する。Git のバージョンによる相対パス解釈の差を避けるため絶対パスを保存する。

### `run_onchange_after_30-mise-install.sh.tmpl`

[run_onchange_after_30-mise-install.sh.tmpl](../../run_onchange_after_30-mise-install.sh.tmpl) は `config.toml` または `mise.lock` が変わると再実行される。テンプレート内のハッシュコメントは chezmoi の変更検知に必要であり、削除しない。

通常環境では `mise install` と `mise prune` で構成に収束させる。bootstrap CI の目的は導入経路、シェル起動、補完生成の検証なので、時間を抑えるため必要なビルド済みツールだけを導入する。

### `run_onchange_after_40-zsh-completions.sh.tmpl`

[run_onchange_after_40-zsh-completions.sh.tmpl](../../run_onchange_after_40-zsh-completions.sh.tmpl) は、補完生成コマンド本体の内容ハッシュが変わったときに再実行される。mise の `postinstall` hook は全ツールが導入済みだと発火しないため、`apply` からも補完状態を収束させる。ハッシュコメントは変更検知に必要である。

## 手動コマンドと検証スクリプト

### `refresh-zsh-completions`

[dot_local/bin/executable_refresh-zsh-completions](../../dot_local/bin/executable_refresh-zsh-completions) は、インストール済みツールの zsh 補完を `~/.local/share/zsh/completions` に生成する。Carapace の全completer登録コードは通常の補完関数ではないため、`~/.cache/zsh/carapace-init.zsh` に分けて生成する。起動時間との関係は [zsh-startup.md](zsh-startup.md) を参照する。

- hook の再帰を防ぐため `MISE_NO_HOOKS=1` で mise を呼ぶ。
- Carapace未対応で静的生成が必要な対象は `NAMES` で管理する。現在は `bw` と `mise` だけである。
- stampに残っている旧対象は補完ファイルを削除し、Carapace管理へ移す。
- shim は CWD によってバージョンを解決できないため、`mise exec <tool>@<version>` を使う。`bw` は既定の appdata directory を作らないよう場所を明示する。
- `mise ls --installed` を一度だけ実行して使い回す。`--current` は CWD 依存で、postinstall と chezmoi apply の実行場所によって生成と削除を繰り返すため使わない。mise が利用不能なら既存補完を消さず終了する。
- stamp はインストール済みツールごとに名前、バージョン、`ok` または `skip` を記録する。失敗した同じバージョンは毎回再試行せず、バージョン変更時に再試行する。
- Carapace の登録コードも同じstampでバージョンを追跡し、未導入になった場合はcacheを削除する。
- 強制指定、初回、バージョン変更、成功記録があるのに生成物がない場合だけ再生成する。未インストールのツールは補完と stamp を削除し、再導入時に生成し直す。
- zcompdump は補完ファイルの集合が変わった場合だけ削除する。内容だけの変更では command と補完関数の対応は変わらず、関数本体は `fpath` から遅延ロードされる。

### `scripts/check-mise-lock.sh`

[scripts/check-mise-lock.sh](../../scripts/check-mise-lock.sh) は、`mise.lock` の固定バージョンと現在有効なバージョンを比較する。Python や jq のない bootstrap CI でも動くよう標準的なシェルツールだけを使い、引用された TOML tool key にも対応する。使い方は [commands.md](../commands.md#mise-lock) を参照する。

### `scripts/check-secrets.sh`

[scripts/check-secrets.sh](../../scripts/check-secrets.sh) は、public リポジトリへの秘密情報の commit を防ぐ。chezmoi の autoCommit／autoPush により commit が公開へ直結するため、pre-commit と CI の両方で使う。

`--staged` は index、`--tracked` は現在追跡中のファイル、`--history` は履歴中の一意な blob を検査する。検出パターン自体を持つスクリプトと hook は自己検出を避けるため除外する。誤検出は `--no-verify` で迂回せずパターンを修正する。コマンドは [commands.md](../commands.md#secrets-and-signing) を参照する。

### `scripts/revert-etc-zshenv.sh`

[scripts/revert-etc-zshenv.sh](../../scripts/revert-etc-zshenv.sh) は旧環境の `/etc/zsh/zshenv` から `ZDOTDIR` の追記を除去する、一度限りの手動移行コマンドである。sudo を通常の `apply` 経路へ戻さないため自動実行しない。

安全のため先に `~/.zshenv` を配置し、追記行と余分な末尾改行を除いた内容を作り、バックアップ後に既存ファイルへ上書きする。dpkg 環境では conffile の MD5 と比較する。最後に親環境の `ZDOTDIR` と `HISTFILE` を除いて zsh を起動し、stub と本体設定の両方が読み込まれたことを確認する。`--dry-run` を指定すると差分だけを表示する。背景、復旧方法、手動手順は [移行記録](../archive/migration-etc-zshenv-to-home-zshenv.md) を参照する。
