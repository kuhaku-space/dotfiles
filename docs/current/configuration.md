# 設定ファイルの設計

設定値の意図、変更時の制約、関連する運用をまとめる。設定ファイル自身には値だけを置き、自動生成を示すマーカーなど機械的意味のあるコメントだけを残す。

## chezmoi

### `.chezmoi.toml.tmpl`

[`.chezmoi.toml.tmpl`](../../.chezmoi.toml.tmpl) は、初期化時の実際のソース位置を `.chezmoi.sourceDir` から取得する。これにより既定の `~/.local/share/chezmoi` と ghq 配下のどちらで初期化しても、生成される `chezmoi.toml` が正しい場所を参照する。

Bitwarden の `unlock = true` により、秘密鍵テンプレートが Bitwarden を必要とするときだけ chezmoi が `bw unlock` を実行する。正しい鍵が既にある通常の `apply` では `.chezmoiignore` が秘密鍵を除外するため、アンロックも発生しない。

Git の autoCommit と autoPush は、chezmoi がソースへ加えた変更を自動公開する。このため秘密情報検査を pre-commit と CI の両方で実施する。

### `.chezmoiignore`

[`.chezmoiignore`](../../.chezmoiignore) は README、`AGENTS.md`、文書、補助スクリプトを `$HOME` へ展開しない。インストーラがソース内の `bin/` に一時的な chezmoi を置いた場合も、mise 管理版と競合しないよう除外する。

CI は Bitwarden 認証を利用できないため秘密鍵と公開鍵を除外する。通常環境では [needs-bitwarden.sh](../../scripts/needs-bitwarden.sh) を呼び、ローカル鍵が期待する公開鍵と一致するときだけ秘密鍵を除外する。判定をテンプレート内の `ssh-keygen` 呼び出しではなくスクリプトへ委譲する理由は、破損・空・別形式の鍵による非ゼロ終了でテンプレート評価全体が停止するのを防ぐためである。終了コードはシェルで `fetch` または `keep` の文字列へ変換して受け取る。

### `.gitignore`

[`.gitignore`](../../.gitignore) は、chezmoiインストーラが`-b`なしでソース直下に作る`/bin/`だけを除外する。先頭のslashは必須であり、`bin/`にすると任意階層へ一致し、`dot_local/bin/`内の配布コマンドまでGitから漏れる。chezmoi側も同じ一時ディレクトリを除外する。

## Git と jj

### Git

[Git設定](../../dot_config/git/config) は SSH 鍵で commit と tag を常時署名する。`allowedSignersFile` を指定することで `git log --show-signature` と `git verify-commit` が自分の署名を principal に結び付けて検証できる。許可署名者テンプレートはリポジトリの公開鍵を唯一の出典とするため、鍵のローテーションでは [公開鍵](../../private_dot_ssh/id_ed25519.pub) だけを差し替える。

`core.editor` は設定せず、zsh 環境の `$VISUAL` と `$EDITOR` に委ねる。VS Code のない SSH 接続先でも commit できるようにするためである。

主な動作設定は次のとおり。

- `rerere` は過去の conflict 解決を記録して再利用する。
- push は現在の branch を既定にし、初回から upstream を自動設定する。
- fetch 時は消えた branch と tag を prune する。pull は fast-forward のみに限定する。
- マシン固有または非公開の名前・メールアドレスなどは、存在しなくてもエラーにならない `~/.config/git/config.local` に置く。

[グローバルignore](../../dot_config/git/ignore) は Claude Code のローカル設定、`mise.local.toml`、プロジェクトで自動生成される未追跡の `mise.lock` を除外する。mise の lockfile 生成自体はバージョン固定と checksum 検証に必要なので止めない。既に追跡されている lockfile には影響せず、この dotfiles のソース名 `private_mise.lock` にも一致しない。

### jj

[jj設定](../../dot_config/jj/config.toml) は Git 設定を継承しないため、ユーザー名とメールアドレスを別に持つ。引数なしの `jj` は `log` を実行する。自身の commit は Git と同じ公開鍵で SSH 署名し、検証にも同じ allowed signers を使う。

## mise

[mise設定](../../dot_config/mise/config.toml) は `lockfile = true` とし、`latest` 指定を解決したバージョン、URL、checksum を `mise.lock` に記録する。グローバル lock の作成・更新には `mise lock --global` または `mise upgrade` を使う。`update` 関数は更新後の lockfile を chezmoi のソースへ取り込む。

`postinstall` hook は、ツールの導入・更新直後に `refresh-zsh-completions` を呼ぶ。これがないと、補完の更新は chezmoi の onchange スクリプトが変化した場合に限られ、`mise upgrade` 後も古い補完が残る。

Claude Code は aqua backend ではなく GitHub Releases から取得する。mise 2026.8.4 では aqua registry の backend type override が反映されず、空 URL によってインストールと lockfile が壊れたためである。アーカイブ内の実行ファイル名は `claude-code` ではなく `claude` なので明示する。aqua 側の問題が解消した場合は通常の `latest` 指定へ戻せる。

Bitwarden は公式ネイティブバイナリを使い、初回に先行導入するものと同じ成果物を mise で継続管理する。ShellCheck と actionlint は CI と同じ検査をローカルでも実行するために含める。

Rust、Node.js、Typst は意図的にグローバル設定へ含めない。

- Rust は rustup とプロジェクトの `rust-toolchain.toml` に任せる。mise の core Rust は既存 rustup を検出すると symlink と `RUSTUP_TOOLCHAIN` でプロジェクト指定へ干渉し、lockfile に URL や checksum も残らない。
- Node.js は dotfiles 自体の依存ではなく、Bitwarden と Claude Code もネイティブバイナリなので不要である。
- Typst はプロジェクトごとにバージョンを決める。インストール済みならグローバル設定になくても補完生成が検出するため、補完だけを理由に追加しない。

`private_mise.lock` の `@generated` 行は生成物を示すため残し、内容は手編集しない。

## zsh

### 起動ファイルと環境変数

[ホーム直下のstub](../../dot_zshenv) は `ZDOTDIR=$HOME/.config/zsh` を設定し、本体の `.zshenv` を明示的に読む。zsh は起動時に読むファイルを先に決めるため、stub 内で `ZDOTDIR` を変えただけでは新しい場所の `.zshenv` を自動では読まない。`.zprofile`、`.zshrc`、`.zlogin` は `ZDOTDIR` 決定後に探索されるので転送不要である。全ユーザーへ影響し、sudo と conffile conflict を伴う `/etc/zsh/zshenv` は使わない。

[環境設定](../../dot_config/zsh/dot_zshenv) は XDG path、履歴、Rust、zeno、fzf、Node.js、Claude Code、補完 path を設定する。

- `LANG` が未設定の最小環境だけ `C.UTF-8` にする。`ja_JP.UTF-8` は生成済みとは限らない。
- `openssl-sys` 用の環境変数は `libssl.so` と header が実在するときだけ設定する。固定した x86_64 path を渡すと pkg-config が使われず他アーキテクチャでリンクに失敗する。include path は `openssl/` の親を指す。
- zsh では `typeset -U` で PATH と fpath の重複を除き、静的補完を compinit より前に登録する。bootstrap から bash で source される場合は zsh 専用構文を避ける。
- editor は PATH 確定後に選び、nvim があれば `$EDITOR=nvim`、VS Code があれば `$VISUAL='code --wait'` とする。Git はこの一箇所へ委ねる。

### 対話設定

[対話設定](../../dot_config/zsh/dot_zshrc) の `dotfiles-status` は、ソースの未commit・ahead/behind と `$HOME` の展開差分を必要なときだけ表示する。シェル起動ごとの警告では re-add 忘れや未pushを十分検出できず、消せない警告が常時出るため手動コマンドにした。ローカル変数名に `status` を使わないのは zsh では `$?` の読み取り専用aliasだからである。

`update` は次の順で実行する。

1. 最初に `chezmoi update` で pull と apply を済ませる。先に mise.lock のローカルcommitを作ると、他マシンのlock更新に対するrebase conflictを起こしやすい。
2. aptを更新する。
3. `mise upgrade -C "$HOME"` でグローバル設定だけを更新し、生成されたlockfileをre-addする。実行ディレクトリのプロジェクト設定を誤って更新しないため `-C` が必要である。
4. `sheldon lock --update` で固定されたpluginを更新する。
5. Starshipのinit cacheだけを削除する。zcompdumpは補完関数の対応表であり、ツールのversion更新だけでは古くならない。補完ファイルの増減時は補完生成側が削除する。

`clip` はWaylandでは`wl-copy`、X11では`xclip`、表示サーバーがなければOSC 52を選ぶ。SSH越しでもOSC 52対応端末なら手元のclipboardへ送れる。

miseをactivateした親プロセスからVS CodeなどがPATH先頭にhelperを挿入する場合があるため、activate後にmise管理ツールを先頭へ戻し、miseのsnapshotも更新する。

SSH agent初期化はprompt後へ遅延する。`ssh-add -l` の終了コード0は鍵あり、1は既存agentに鍵なし、その他はagent接続不可として扱う。既存のdesktop agentがあればそこへ追加し、なければkeychainを使う。遅延処理中のpassphrase promptはZLEと競合するためstdinを閉じ、後のSSH接続時に`AddKeysToAgent`へ任せる。keychainがない環境では静かに終了する。

履歴は重複削除、先頭spaceの除外、空白圧縮、実行時刻・所要時間、逐次追記を有効にする。pluginが提供するwidgetは遅延ロードされるため、対応する`bindkey`も同じく遅延する。

起動時間に関する全体設計は [zsh-startup.md](zsh-startup.md) を参照する。

## Sheldon

[plugins.toml](../../dot_config/sheldon/plugins.toml) の順序には次の制約がある。

1. `zsh-defer` を最初に同期ロードする。
2. `zsh-completions` はfpathを広げるためcompinitより前に同期ロードする。
3. fpath確定後にcompinitを遅延実行する。
4. 補完を必要としない残りのpluginを遅延ロードする。

inline pluginには通常のdefer templateが適用されないため、自身で`zsh-defer`を呼ぶ。compinitのdumpは変更時だけzcompileする。Starshipは最初のpromptに必要なので遅延せず、init出力をcacheして毎回のsubprocessを避ける。zoxideは最初に`z`を使うまでに用意できればよいので遅延する。mise補完は静的生成するため、起動時には生成しない。

## SSH

[SSH client設定](../../private_dot_ssh/private_config) は公開できないhost定義を`~/.ssh/config.d/*.conf`から先に読む。OpenSSHは最初に見つけた値を採用するため、`Include`は先頭に置く。

GitHubでは管理対象の鍵だけを使い、不要な鍵を順に試すことによる`Too many authentication failures`を防ぐ。全hostでagentへの鍵登録、connection共有、keepaliveを有効にする。ControlPathはNFS上でsocketを作れないため、利用可能なら`/run/user/$UID`を優先し、それ以外は`~/.ssh/control`へ置く。known_hostsはローカルの書き込み先とリポジトリ配布分の両方を読む。

[秘密鍵template](../../private_dot_ssh/private_id_ed25519.tmpl) は認証とGit署名を兼ねるSSH Key itemを一意なBitwarden item IDで取得する。[allowed signers template](../../dot_config/git/allowed_signers.tmpl) は同じ公開鍵を埋め込む。

[known hosts](../../private_dot_ssh/private_known_hosts.chezmoi) はGitHub APIの`ssh_keys`と一致する公開情報で、初回push時のTOFU確認を省く。更新時は次を使う。

```sh
curl -fsS https://api.github.com/meta | jq -r .ssh_keys[]
```

記録していたfingerprintは次のとおり。

| 種類 | SHA-256 |
| --- | --- |
| ECDSA | `SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM` |
| ED25519 | `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU` |
| RSA | `SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s` |

SSH鍵の導入・更新手順は [ssh-keys-bitwarden.md](ssh-keys-bitwarden.md) を参照する。

## Zellij

[Zellij設定](../../dot_config/zellij/config.kdl) は既定keybindを無効化し、modeごとのkeybindとbuilt-in plugin aliasを明示する。background pluginはなく、web clientのfontは`monospace`である。

以前のファイル末尾にはZellijが生成した無効な設定例が含まれていた。これらはこのリポジトリで選択した値ではなく、Zellijの既定値を使う候補であった。対象はUI簡略化、theme、初期mode／shell／cwd／layout、layout・theme directory、mouseとpane frame、session共有・終了・serialization、scrollback、clipboard、editor、自動layout、Kitty keyboard、web server／sharing／TLS、stack resize、startup tips、release notes、advanced mouse action、web server address／port、復元command hookである。変更するときは現在利用するZellij versionの設定仕様を確認し、必要な値だけを有効なKDLとして追加する。

## GitHub Actions

[CI/CD workflow](../../.github/workflows/ci-cd.yml) は`validate`と`bootstrap`の2 jobを持つ。

`validate`は履歴全体のsecret scanに必要なためfull historyをcheckoutする。runnerから認証なしでGitHub APIを使うと403になる場合があるため、actionlintのrelease assetは`GH_TOKEN`を設定した`gh`で取得する。拡張子を持たない`dot_local/bin/`もShellCheck対象へ明示的に含め、chezmoiのshell templateはrender後にも`bash -n`を実行する。zsh設定とSheldonのinline codeはzsh構文として検査する。

chezmoi template検査では、Bitwarden認証を要求する秘密鍵templateだけを通常renderから除外する。一方、CI分岐が秘密鍵を除外すること、破損・空・別の鍵でも`.chezmoiignore`評価が停止しないこと、Bitwardenのx86_64／arm64取得情報がlockfileに残っていることを個別に検証する。TOML検査は拡張子が`.toml`でないmise lockfileも含め、allowed signersは3 fieldが存在し公開鍵として解釈できることまで確認する。

`bootstrap`はREADMEのone-linerと同じ`chezmoi init --apply`経路を素のUbuntu containerで実行する。read-only mountを直接使うとremoteを書き換えられず、runner所有のcopyはGitのdubious ownership判定を受けるため、`/root/dotfiles`へcopyして所有者を揃える。展開ファイル、CIでの鍵除外、`bin/`除外、login shell、SSH remote、hook、対話zsh、補完、Starship cacheを検査し、CIで導入するsubsetについて実際のversionが配布lockfileと一致することも確認する。
