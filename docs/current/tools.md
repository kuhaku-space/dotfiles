# 使用しているツール

どの層で何を導入し、各ツールをどの目的で使うかをまとめる。バージョンはここに書かない。導入されるツールとバージョンの出典は次の3つで、この文書は役割の対応表としてそれを補う。

| 層 | 出典 | 導入方法 |
| --- | --- | --- |
| 開発 CLI | [mise設定](../../dot_config/mise/config.toml) の `[tools]`、固定されたバージョンは [mise.lock](../../dot_config/mise/private_mise.lock) | [run_onchange_after_30-mise-install.sh.tmpl](../../run_onchange_after_30-mise-install.sh.tmpl) が `chezmoi apply` 時に `mise install` する |
| OS パッケージ | [run_once_after_05-apt-packages.sh](../../run_once_after_05-apt-packages.sh) の `PACKAGES` | apt があれば不足分を導入し、なければ一覧を表示するだけ |
| zsh プラグイン | [plugins.toml](../../dot_config/sheldon/plugins.toml) | Sheldon が取得し、`sheldon lock --update` で更新する |

ツールを増減したときは、出典とこの文書の表を同時に更新する。個々のツールを採用・除外した理由は [設定ファイルの設計](configuration.md#mise) にあり、ここでは繰り返さない。

## mise で管理する CLI

### シェルと対話環境

| ツール | 用途 |
| --- | --- |
| starship | prompt。init 出力を cache して起動ごとの subprocess を避ける |
| atuin | `Ctrl-R` の履歴検索。Atuin Cloud へ暗号化して同期する（[設定](configuration.md#atuin)） |
| zoxide | 使用履歴に基づくディレクトリ移動 |
| carapace | 補完の集約先。未対応の `bw` と `mise` だけ各 CLI の生成機能を使う |
| usage | mise の補完生成が利用する CLI spec ツール |
| fzf | zeno などの絞り込み UI。既定 option は `.zshenv` の `FZF_DEFAULT_OPTS` |
| deno | zeno.zsh の実行環境 |
| sheldon | zsh plugin manager |
| zellij | terminal multiplexer |

`mise install` の CI 分岐が導入する subset（atuin、sheldon、starship、zoxide、fzf、deno、bat、eza、usage）は、対話 zsh の起動に必要なものである。

### ファイルとテキスト

| ツール | 用途 |
| --- | --- |
| eza | `ls` の置き換え。zeno の `l` snippet と `ZENO_GIT_TREE` |
| bat | 色付きのファイル表示。`ZENO_GIT_CAT` |
| glow | Markdown をターミナルで読む |
| neovim | あれば `$EDITOR`。なければ `vi` に落ちる |

### Git と GitHub

| ツール | 用途 |
| --- | --- |
| gh | GitHub CLI。[Git設定](../../dot_config/git/config) の credential helper と `ghq.vcs` に指定する |
| ghq | repository の取得先を一元化する。`Ctrl-]` の zeno-ghq-cd で移動する |

### dotfiles と秘密情報

| ツール | 用途 |
| --- | --- |
| chezmoi | dotfiles 本体の管理 |
| bitwarden | SSH 鍵の取得元。初回は先行導入した `~/.local/bin/bw` を使い、以後は mise 管理版へ移る |

### 開発とローカル検査

| ツール | 用途 |
| --- | --- |
| claude | Claude Code。GitHub Releases から取得し、実行ファイル名は `claude` |
| shellcheck | CI と同じ shell script 検査をローカルでも実行する |
| actionlint | CI と同じ workflow 検査をローカルでも実行する |
| hyperfine | zsh 起動時間の計測。zeno の `benchmark` snippet と [zsh-startup.md](zsh-startup.md) |

## apt で導入する OS パッケージ

一覧は [run_once_after_05-apt-packages.sh](../../run_once_after_05-apt-packages.sh) を出典とし、ここでは役割を示す。

- **bootstrap と chezmoi**: `ca-certificates`、`curl`、`git`、`openssh-client`、`unzip`。chezmoi の導入、mise と bw の取得、リポジトリの操作に使う。
- **shell**: `zsh`（login shell）、`keychain`（既存の desktop agent がない場合の SSH agent）。
- **clipboard**: Wayland の `wl-clipboard` と X11 の `xclip`。`.zshrc` の `clip` がどちらかを選ぶ。
- **ビルド**: `build-essential`、`libssl-dev`、`libclang-dev`、`cmake`。Rust などを source から build する場合に必要で、`.zshenv` の `OPENSSL_LIB_DIR` は `libssl.so` の実在を確認してから設定する。
- **その他**: `jq`、`fontconfig`（Nerd Font の導入と cache 更新）。

apt がない環境では導入せず、同等のパッケージ名を表示して終了する。実機 Linux 固有の注意点は [bare-metal-linux.md](bare-metal-linux.md) を参照する。

## zsh プラグイン

| プラグイン | 用途 |
| --- | --- |
| base16-shell | terminal の色 |
| zsh-defer | 遅延ロードの基盤。最初に同期ロードする |
| zsh-completions | 追加の補完関数。fpath を広げるため compinit より前に読む |
| zsh-autosuggestions | 履歴からの入力補助 |
| fast-syntax-highlighting | 入力中の構文強調 |
| zeno.zsh | snippet 展開、ghq 移動、補完。Deno と fzf を使う |

compinit、Atuin、Starship、zoxide の初期化は inline plugin として持つ。ロード順の制約は [設定ファイルの設計](configuration.md#sheldon)、遅延と cache の方針は [zsh-startup.md](zsh-startup.md) にある。

## この dotfiles が導入しないもの

設定だけを配布し、導入は各マシンに任せるものがある。

| 対象 | 配布するもの | 導入方法 |
| --- | --- | --- |
| mise 本体 | なし | [run_once_after_10-setup.sh](../../run_once_after_10-setup.sh) が `https://mise.run` から導入し、`mise self-update` を試みる |
| Rust / rustup | `RUSTUP_HOME`、`CARGO_HOME`、`OPENSSL_*`、`$CARGO_HOME/bin` の PATH | rustup とプロジェクトの `rust-toolchain.toml` |
| Node.js / pnpm | [npmrc](../../dot_config/npm/npmrc)、[pnpm/rc](../../dot_config/pnpm/rc)、`NODE_REPL_HISTORY` | 必要なプロジェクトで個別に用意する |
| jj | [jj設定](../../dot_config/jj/config.toml) | 各マシンで個別に導入する |
| Nerd Font | なし | [run_once_after_15-nerd-font.sh](../../run_once_after_15-nerd-font.sh)。WSL では Windows 側の terminal が描画するため何もしない |

## ツールを増減する手順

mise で管理するツールを追加する場合は、設定と lockfile の両方をソースへ取り込む。

```sh
mise use -g <tool>                    # config.toml と mise.lock を更新
chezmoi re-add ~/.config/mise/config.toml ~/.config/mise/mise.lock
```

削除は `mise use -g --remove <tool>` の後に同じ re-add を行う。`mise prune` で実体も消える。apt パッケージは `PACKAGES` 配列を、zsh プラグインは `plugins.toml` を直接編集する。

変更後の検証は [Validation commands](../commands.md) から必要なものを選ぶ。導入済みのツールと lockfile の一致は [scripts/check-mise-lock.sh](../../scripts/check-mise-lock.sh) で確認する。
