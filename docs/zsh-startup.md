# zsh の起動時間

測定は `hyperfine -w 5 -r 50 'zsh -i -c exit'`（zeno スニペット `benchmark`）。現状は約 **100ms**（改善前は 210ms）。

プロンプト表示に間に合わせる必要のない処理は [zsh-defer](https://github.com/romkatv/zsh-defer) に回している。defer した処理はプロンプトを待たせないだけで消えるわけではないので、**そもそも要らない処理は消す**方が先:

| 処理 | 扱い | 理由 |
| --- | --- | --- |
| keychain / ssh-agent | defer | プロンプト表示に不要 |
| `compinit` | defer | 約 30ms。**fpath を広げるプラグインより後**に走らせる必要がある |
| `zoxide init` | defer | `z` を打つまでに間に合えばよい |
| `starship init` | キャッシュ | プロンプトなので defer できない。出力を `$XDG_CACHE_HOME/zsh/starship-init.zsh` に保存 |
| `mise completion` | 静的生成 | 毎起動の subprocess をやめ、補完ファイルとして `fpath` に置く |
| `bindkey` | defer | widget を定義するプラグイン（zeno / autosuggestions）が defer なので、即時に張ると読み込み前の入力が `No such widget` で捨てられる |

`apply = ["defer"]` は **inline プラグインには効かない**（テンプレートは `files` を展開するためのもの）。inline を遅延したいときは自分で `zsh-defer` を書く。読み込み順の約束は [plugins.toml](../dot_config/sheldon/plugins.toml) 冒頭のコメントにまとめてある。

生成物（starship の init 出力・補完ダンプ）はツールが入れ替わると古くなるため、[.zshrc](../dot_config/zsh/dot_zshrc) の `update` 関数がまとめて捨てる。次のシェル起動で作り直される。
