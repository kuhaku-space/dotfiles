# zsh の起動時間

測定は `hyperfine -w 5 -r 50 'zsh -i -c exit'`（zeno スニペット `benchmark`）。現状は WSL2 で約 **35ms**（改善前は 210ms）。

プロンプト表示に間に合わせる必要のない処理は [zsh-defer](https://github.com/romkatv/zsh-defer) に回している。defer した処理はプロンプトを待たせないだけで消えるわけではないので、**そもそも要らない処理は消す**方が先:

| 処理 | 扱い | 理由 |
| --- | --- | --- |
| keychain / ssh-agent | defer | プロンプト表示に不要 |
| `compinit` | defer | 約 30ms。**fpath を広げるプラグインより後**に走らせる必要がある |
| `zoxide init` | defer | `z` を打つまでに間に合えばよい |
| `starship init` | キャッシュ | プロンプトなので defer できない。出力を `$XDG_CACHE_HOME/zsh/starship-init.zsh` に保存 |
| `atuin init` | キャッシュ | 最初のコマンドから履歴hookと`Ctrl-R`が必要。出力を `$XDG_CACHE_HOME/zsh/atuin-init.zsh` に保存 |
| `mise completion` | 静的生成 | 毎起動の subprocess をやめ、補完ファイルとして `fpath` に置く |
| `carapace _carapace` | キャッシュ | 全completerの登録コードを更新時に生成し、`compinit`直後に読む |
| `bindkey` | defer | widget を定義するプラグイン（zeno / autosuggestions）が defer なので、即時に張ると読み込み前の入力が `No such widget` で捨てられる |

`apply = ["defer"]` は **inline プラグインには効かない**（テンプレートは `files` を展開するためのもの）。inline を遅延したいときは自分で `zsh-defer` を書く。[plugins.toml](../../dot_config/sheldon/plugins.toml) の読み込み順の制約は [設定ファイルの設計](configuration.md#sheldon) にまとめてある。

starship / Atuin の init 出力はツールが入れ替わると古くなるため、[.zshrc](../../dot_config/zsh/dot_zshrc) の `update` 関数が捨て、次のシェル起動で作り直される。補完ダンプの扱いは [`update` の手順](configuration.md#対話設定) と [refresh-zsh-completions](scripts.md#refresh-zsh-completions) を参照する。

## Windows 側の PATH

WSL は Windows の PATH（`/mnt/c/...`）を Linux 側の PATH 末尾に追加する。このディレクトリは 9P 越しに参照するため 1 件ごとに数 ms かかり、mise は `activate`・起動時の `hook-env`・**毎プロンプトの `hook-env`** で PATH を走査する。15 件あった環境では各回約 60ms かかり、起動が約 160ms になっていた。

Windows 側のコマンドは使わないため、[zshenv](../../dot_config/zsh/dot_zshenv) で `/mnt/[a-z]/*` を PATH から外している。mise を有効にした親（VS Code など）から継承した `__MISE_ORIG_PATH` からも同じものを外す。mise は `hook-env` でこの値から PATH を作り直すため、PATH だけを外しても戻ってしまう。Windows のコマンドが必要になった場合は、ディレクトリごと PATH へ戻すのではなく、個別にエイリアスや絶対パスで呼ぶ。
