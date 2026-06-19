# yadm → chezmoi 移行記録

このリポジトリの dotfiles 管理を [yadm](https://yadm.io/) から [chezmoi](https://www.chezmoi.io/) へ移行した際の作業記録。手順と、各所での設計判断の理由を残す。

## 背景：yadm と chezmoi のモデルの違い

移行を理解する上で最も重要な前提。

| | yadm | chezmoi |
| --- | --- | --- |
| ファイルの実体 | `$HOME` のファイルを **直接** バージョン管理（bare リポジトリ `~/.local/share/yadm/repo.git`） | **ソースディレクトリ**にコピーを置き、`chezmoi apply` で `$HOME` に展開 |
| ファイル名 | `$HOME` 上のパスそのまま（`.config/git/config`） | 特殊な命名規則（`dot_config/git/config` → `~/.config/git/config`） |
| 除外 | sparse-checkout | `.chezmoiignore` |
| セットアップ処理 | `yadm bootstrap`（手動実行する単一スクリプト） | `run_once_` / `run_onchange_` スクリプト（`apply` 時に自動実行） |
| テンプレート | `##` 記法 | Go template（`.tmpl`） |

yadm は「$HOME がそのままリポジトリの作業ツリー」だが、chezmoi は「ソース → $HOME への一方向の展開」である点が根本的に異なる。

## 採用した構成

- ソースディレクトリは **ghq 配下のクローン**（`~/ghq/github.com/kuhaku-space/dotfiles`）をそのまま使う。chezmoi のデフォルト（`~/.local/share/chezmoi`）ではなく、`~/.config/chezmoi/chezmoi.toml` の `sourceDir` で ghq パスを指す。
- chezmoi 本体は mise で管理（`mise/config.toml` の `yadm` を `chezmoi` に置換）。
- `chezmoi.toml` は **マシン固有の状態**なのでリポジトリにはコミットしない。

## 手順

### 1. ファイルレイアウトを chezmoi のソース命名に変換

`$HOME` のパスを chezmoi のソース名に `git mv` でリネーム（履歴を保つためリネームとして扱う）。

```sh
git mv .config dot_config
# dot_config 配下の隠しファイルにも dot_ プレフィックスが必要
git mv dot_config/zsh/.zshenv dot_config/zsh/dot_zshenv
git mv dot_config/zsh/.zshrc  dot_config/zsh/dot_zshrc
```

ディレクトリ（`dot_config`）配下の通常ファイル（`git/config` など）は追加のリネーム不要。隠しファイルのみ `dot_` が要る。

### 2. bootstrap をスクリプトに変換し、実行頻度で分割

yadm の単一 `bootstrap` を、性質ごとに分割した（→ [設計判断](#bootstrap-を3つに分割した理由)）。

| ファイル | プレフィックスの意味 | 内容 |
| --- | --- | --- |
| `run_once_after_10-setup.sh` | 初回1回だけ | シェル変更 / SSH 鍵生成 / ZDOTDIR 追記 / ディレクトリ作成 / mise 本体導入 |
| `run_once_after_15-apt-packages.sh` | 初回1回だけ | apt パッケージの不足分を install |
| `run_onchange_after_30-mise-install.sh.tmpl` | mise の設定変更時 | `mise install` / `mise prune` |

- 実行順は **ファイル名のソート順**（プレフィックスを除いた `10` → `15` → `30`）。
- `run_onchange_` の `.tmpl` には、別ファイル `dot_config/mise/config.toml` のハッシュをコメントとして埋め込み、config 変更を検知させる：
  ```
  # config.toml hash: {{ include "dot_config/mise/config.toml" | sha256sum }}
  ```

### 3. README を `$HOME` に展開しないよう除外

yadm の sparse-checkout（`/*` `!/README.md`）の代替。

```
# .chezmoiignore
README.md
```

`run_*` スクリプトや `.chezmoi*` は chezmoi が自動的に「$HOME に展開しない」扱いにするため、列挙不要。README のような通常ファイルのみ明示する。

### 4. yadm への参照を chezmoi に置換

リポジトリ内の `yadm` 参照をすべて置換した。

- `dot_config/zsh/dot_zshrc` の `is_dirty()`：`yadm status --porcelain` → `chezmoi git -- status --porcelain`
- `dot_config/zeno/config.yml` の zeno スニペット：yadm 系（`y`/`b`/`st`/`cm`/`cma`）→ chezmoi 系（`cz`/`a`/`up`/`st`/`cm`/`cma`）
- `dot_config/mise/config.toml`：`yadm = "latest"` → `chezmoi = "latest"`

加えて apt/mise/dotfiles を一括更新する `update()` 関数を `dot_zshrc` に追加し、zeno に `up` スニペットを足した。

### 5. このマシンへ適用

```sh
# chezmoi を導入
mise use -g chezmoi

# ソースを ghq クローンに固定（init では永続化されないため手書き）
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
sourceDir = "/home/kuhaku/ghq/github.com/kuhaku-space/dotfiles"
EOF

# 適用前に必ず read-only で差分確認
chezmoi diff

# ファイルのみ先に適用（スクリプトは別途判断）
chezmoi apply --exclude=scripts
```

> **適用前の差分確認で判明したこと**：ghq クローンが yadm より **3コミット先行**していた（共通祖先 `3c8ac80`、先行分 `4772260` git/config 整形・`b6ca8da` .aliases 削除・`9461132` sheldon 更新）。
> `$HOME` 側（yadm 作業ツリー）が「新しく見えた」が、実際には **古い**内容だったため、`chezmoi apply` で最新化されただけで**データ損失はなし**。
> 教訓：**適用前に必ず `chezmoi diff` を取り、差分の方向（どちらが新しいか）を確認する**こと。

## bootstrap スクリプトの扱い（既存マシンへの適用）

既にセットアップ済みのマシンでは、`run_once_` スクリプトを実行せず「実行済み」として記録した。

### scriptState のキー形式（調査結果）

chezmoi はスクリプトの実行履歴を persistent state（`~/.config/chezmoi/chezmoistate.boltdb`）の `scriptState` バケットに記録する。キーは以下と判明した：

- **キー = レンダリング後のスクリプト内容（末尾改行込み）の SHA256**
- 値 = `{"name": "<ターゲット名>", "runAt": "<RFC3339 時刻>"}`

`run_once_` も `run_onchange_` も同じ形式。`run_once_` は「この内容ハッシュが state に無ければ実行」、`run_onchange_` は「内容が変わったら実行」という違い。

### 実行済みとして記録する手順

```sh
# 各スクリプトのレンダリング後内容のハッシュを得る
H10=$(sha256sum run_once_after_10-setup.sh | awk '{print $1}')
H15=$(sha256sum run_once_after_15-apt-packages.sh | awk '{print $1}')
# .tmpl はレンダリングしてからハッシュ
H30=$(chezmoi execute-template < run_onchange_after_30-mise-install.sh.tmpl | sha256sum | awk '{print $1}')

# scriptState に書き込む
for pair in "$H10:10-setup.sh" "$H15:15-apt-packages.sh" "$H30:30-mise-install.sh"; do
  key=${pair%%:*}; name=${pair#*:}
  chezmoi state set --bucket=scriptState --key="$key" \
    --value="{\"name\":\"$name\",\"runAt\":\"2026-06-19T07:30:00Z\"}"
done
```

> **注意**：`run_onchange_` はこの手動記録だけでは抑止しきれない場合がある（今回 `30-mise-install.sh` は記録しても再実行された）。`mise install` / `mise prune` は冪等かつ「config 通りにツールを同期する」正当な処理なので、これは**実際に実行**して問題ない。`run_once_`（`chsh` や SSH 鍵生成など、既存環境で再実行したくないもの）の抑止が主目的。

### 検証（冪等性）

```sh
chezmoi apply --dry-run --verbose   # 何も出なければ OK
chezmoi diff                        # 空なら $HOME == source
chezmoi verify                      # 成功なら一致
```

## 移行後の日常運用

```sh
chezmoi edit ~/.config/zsh/.zshrc   # ソースを編集
chezmoi apply                       # $HOME に反映
chezmoi git -- status               # ソースリポジトリの状態
chezmoi git -- commit -am "..."     # コミット
chezmoi git -- push                 # push
chezmoi update                      # pull + apply
update                              # apt + mise + dotfiles 一括更新（独自関数）
```

## 設計判断

### ソース命名に変換（`.chezmoiroot` で現状維持にしなかった理由

chezmoi は `.chezmoiroot` 等で `$HOME` ミラー構造のまま使うことも一応可能だが非標準で、テンプレートや属性（`private_`, `executable_` など）が使いにくくなる。将来の拡張性を取り、`dot_config/` への変換を選んだ。

### chezmoi 本体を mise で管理

元々 yadm を mise で入れていたのと同じ流儀に合わせた。`mise/config.toml` の1行を置換するだけで済む。

### `chezmoi.toml` をコミットしない

`chezmoi.toml` はマシンごとに異なる状態（`sourceDir` のパス等）を持ち、秘密情報が入りうる場所でもあるため、リポジトリには含めない。各マシンで手書きするか `chezmoi init --source` 時に生成する。

### bootstrap を3つに分割した理由

元の `bootstrap` には「1回だけでよい処理（シェル変更・SSH 鍵）」と「いつでも実行したい処理（パッケージ更新）」が混在していた。chezmoi のプレフィックスで実行頻度を制御できるため、性質ごとに分割した：

- **`run_once_`**：シェル変更・SSH 鍵・ZDOTDIR・ディレクトリ・mise 本体・apt パッケージ。一度実行すれば再実行不要。
- **`run_onchange_`**：mise のツール同期。`config.toml` を編集したら再実行されてほしい。

apt は当初 `run_onchange_` にしたが、「パッケージは一度入れれば終わり」という判断で `run_once_` に変更（後から追加する場合は手動実行する運用）。

## 残作業

移行時点で未完了のもの。

1. **ghq リポジトリの移行差分を push**：yadm→chezmoi 化の変更が未コミット。
   ```sh
   chezmoi git -- add -A
   chezmoi git -- commit -m "Migrate from yadm to chezmoi"
   chezmoi git -- push
   ```
2. **古い yadm の削除**：動作確認後に。
   ```sh
   sudo apt remove yadm        # もしくは mise で入れていれば mise rm
   rm -rf ~/.local/share/yadm
   ```
3. **GitHub リポジトリ名**：リモートが `kuhaku-space/yadm.git` のまま。ghq クローンの origin は既に `dotfiles.git` を指す。GitHub 側でのリネームを検討。
