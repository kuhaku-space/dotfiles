# /etc/zsh/zshenv → ~/.zshenv 移行記録

`ZDOTDIR` の宣言を `/etc/zsh/zshenv` への追記から、chezmoi 管理下の `~/.zshenv`（ソースは [dot_zshenv](../dot_zshenv)）へ移した際の記録。**既存マシンで `/etc/zsh/zshenv` を元に戻す手順**を含む。

新規マシンでは何もしなくてよい（[run_once_after_10-setup.sh](../run_once_after_10-setup.sh) は `/etc` を触らない）。以前このリポジトリでセットアップしたマシンにだけ追記が残っている。

## なぜ /etc/zsh/zshenv をやめたか

| 問題 | 内容 |
| --- | --- |
| 全ユーザーに影響する | `/etc/zsh/zshenv` は root を含む全ユーザーの全 zsh 起動（`#!/bin/zsh` の非対話スクリプトも）で読まれる。個人の `$HOME` を絶対パスで焼き込むと `sudo zsh` した root が他人の設定を読む |
| 回避できない | 読み込みを止められるのは `zsh -f`（`NO_RCS`）だけ。`--no-globalrcs` / `-o noglobalrcs` を付けても読まれる（`NO_GLOBAL_RCS` が効くのは `zprofile` 以降） |
| chezmoi の管理外 | sudo が必要で、`chezmoi diff` / `chezmoi status` に出ず、`chezmoi apply` で再現もされない |
| conffile 競合 | dpkg の conffile なので、追記があると `zsh-common` 更新時に「設定ファイルが変更されています」と競合を聞かれる |

`~/.zshenv` に置く方式は `$HOME` 直下にファイルが1枚増えるが、zsh は `ZDOTDIR` 未設定時に `$HOME` を `ZDOTDIR` とみなす仕様なので、これは避けられない最小コスト。詳細は [dot_zshenv](../dot_zshenv) 冒頭のコメント。

## 一括実行

以下の手順 0〜5 をまとめて行うスクリプトを用意している。既存マシンではこれを1回叩けば終わる:

```sh
scripts/revert-etc-zshenv.sh --dry-run   # 何が変わるか差分だけ表示
scripts/revert-etc-zshenv.sh             # 実行（/etc の書き換え時のみ sudo を聞かれる）
```

やることは手動手順と同じで、stub の先置き → バックアップ → 追記行の削除と末尾空行の正規化 → md5 照合 → `ZDOTDIR` の解決確認まで行う。何度実行しても安全で、既に元の状態なら「変更不要」と表示して sudo も要求しない。`chezmoi apply` からは呼ばれない（sudo を apply の経路に戻さないため、手動実行に留めている）。

以下は、スクリプトが何をしているかの説明と、手で確認したいときの手順。

## 手順

### 0. 先に ~/.zshenv を配置する（順序が重要）

`/etc` の行を先に消すと `ZDOTDIR` が未設定になり、zsh は `$HOME` を `ZDOTDIR` として扱う。`~/.zshrc` は存在しないので、**新しいシェルが設定なしの素の zsh になる**。必ずこちらを先に実行する:

```sh
chezmoi apply ~/.zshenv   # このファイルだけ配置（run_once スクリプトは走らない）
test -f ~/.zshenv && echo OK
```

ターゲットを指定しない `chezmoi apply` でもよいが、その場合は `run_once_after_10-setup.sh` の再実行を伴う（内容ハッシュが変わったため。中身は冪等）。

### 1. バックアップを取る

読み取りは sudo 不要:

```sh
cp /etc/zsh/zshenv ~/zshenv.etc.bak
```

### 2. 追記行を削除する

```sh
sudo sed -i '/^export ZDOTDIR=/d' /etc/zsh/zshenv
```

### 3. 末尾の空行を落とす

追記時に `\n` が先頭に入っていたため、行を消しただけでは末尾が `fi\n\n` になり、元ファイル（`fi\n`）と1バイト違う状態が残る:

```sh
sudo perl -0pi -e 's/\n+\z/\n/' /etc/zsh/zshenv
```

dpkg は conffile を md5 で照合するので、この1バイトを残すと以後も「変更済み」と判定され、`zsh-common` 更新時に競合を聞かれ続ける。動作上は無害だが、消しておくと後が静か。

### 4. 元ファイルと一致したか検証する

期待値は dpkg が記録している conffile の md5 から取る（zsh のバージョンが変わっても追随する）:

```sh
test "$(md5sum /etc/zsh/zshenv | cut -d' ' -f1)" \
  = "$(dpkg-query -W -f='${Conffiles}\n' zsh-common | awk '$1=="/etc/zsh/zshenv"{print $2}')" \
  && echo "一致" || echo "不一致"
```

Ubuntu 24.04 / `zsh-common 5.9-6ubuntu2` では `5a8a0ff4f6ff945a5aa6ba7f6f1e8c97`。この検証は dpkg 前提なので、apt 系以外のディストリでは手順 3 までで止め、バックアップとの差分（手順 2 で消した1行だけか）で確認する。

### 5. 動作確認

`ZDOTDIR` が `~/.zshenv` 経由で解決されることを確認する。環境変数から `ZDOTDIR` を外して起動するのが要点（親シェルの値が漏れると検証にならない）:

```sh
env -u ZDOTDIR zsh -c 'print -r -- "ZDOTDIR=$ZDOTDIR"; print -r -- "HISTFILE=$HISTFILE"; print -r -- "fpath[1]=$fpath[1]"'
```

`/etc` はもう `ZDOTDIR` を設定しないので、値が出れば出所は `~/.zshenv` しかない。期待値:

```
ZDOTDIR=/home/<user>/.config/zsh
HISTFILE=/home/<user>/.local/state/zsh/history
fpath[1]=/home/<user>/.local/share/zsh/completions
```

`HISTFILE` と `fpath` は本体 [dot_config/zsh/dot_zshenv](../dot_config/zsh/dot_zshenv) が設定する値なので、これが出れば stub からの `source` も効いている。対話シェルまで確認するなら `env -u ZDOTDIR zsh -i -c 'exit'` がエラーなく終わることを見る。

## バックアップが無い状態から復元する

手順 1 を飛ばしてしまった場合や、編集をやり直したい場合は、パッケージから元ファイルを取り出せる。dpkg はディスク上に pristine なコピーを持たないので、`.deb` を落として展開する:

```sh
cd "$(mktemp -d)"
apt-get download zsh-common                                    # sudo 不要
dpkg-deb --fsys-tarfile zsh-common_*.deb | tar -xO ./etc/zsh/zshenv > zshenv.orig
md5sum zshenv.orig                                             # 手順 4 の期待値と一致するか確認
sudo cp zshenv.orig /etc/zsh/zshenv
```

`tar` から直接 `sudo tee /etc/zsh/zshenv` へ流さず一旦ファイルに落としているのは、md5 を確認してから上書きするため。

なお、この方式で `/etc/zsh/zshenv` を復元すると `ZDOTDIR` の追記も消えるため、`~/.zshenv` が未配置なら手順 0 を先に済ませておくこと。
