# 実機 Linux で問題になる点と、その対処

長らく WSL2 (Ubuntu) だけを想定していたため、実機の Linux（別ディストリ・別アーキテクチャ・管理された端末・デスクトップ環境）では黙って壊れる箇所がいくつかあった。何をどう直したかと、それでも手が必要な部分を残す。

WSL と実機の差はおおむね次の4つに集約される。

- **ディストリとアーキテクチャ**: WSL のイメージは常に Ubuntu の x86_64。実機は Fedora/Arch かもしれないし arm64 かもしれない
- **管理された端末**: アカウントが LDAP/SSSD 管理だったり、sudo が無かったり、`$HOME` が NFS だったりする
- **デスクトップ環境**: Wayland、既に動いている ssh-agent、フォント。WSL ではこれらを Windows 側が持っていた
- **最小構成のインストール**: WSL のイメージには最初から入っているものが無い（`unzip`、`git`、UTF-8 ロケール）

## 直したもの

### apply が止まる・壊す

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| 既存の鍵があると `apply` が全面停止し、その鍵を消すまで復旧できない | `.chezmoiignore` が `ssh-keygen` を `output` で直接呼んでいた。chezmoi の `output` は非ゼロ終了をテンプレート評価のエラーにする | 判定を [scripts/needs-bitwarden.sh](../scripts/needs-bitwarden.sh) に一本化し、終了コードを文字列で受け取る |
| 前から使っていた `~/.ssh/id_ed25519` が黙って消える | chezmoi は自分が一度も書いていないファイルを確認なしで上書きする | [run_before_00-backup-ssh-key.sh](../run_before_00-backup-ssh-key.sh) が指紋の違う鍵を `.bak.<日時>` へ退避する |
| `chsh` で `apply` が止まり、mise の導入も補完生成も走らない | LDAP/SSSD 管理のアカウントは `chsh` を拒否する。sudo が無いと `/etc/shells` も書けない | 警告を出して続行する。ログインシェルは手で直せる |
| `mise self-update` で同上 | self-update は standalone インストール専用。apt/pacman/nix/brew 版では失敗する | 同上 |
| 最小構成のマシンで初回 `apply` が必ず失敗する | `unzip` を入れるのは 05 だが、それを要求する `before_` の 01 が先に走る | 01 が apt で自分で確保する |

### 黙って機能が欠ける

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| Rust のビルドが `cannot find -lssl` になる | `OPENSSL_LIB_DIR` が `/usr/lib/x86_64-linux-gnu` 決め打ち。`openssl-sys` はこの変数があると pkg-config を見ずに信じる | `libssl.so` が実在する場所だけを export する。無ければ pkg-config に任せる |
| arm64 の実機で `bw` が `Exec format error` | 取得先が `?platform=linux`（x86_64 ビルドのみ）だった | `mise.lock` からアーキテクチャ別の URL と sha256 を引く |
| apt が無いディストリで、成功したように見えて何も入っていない | 05 が1行出して `exit 0` していた | 必要なパッケージ一覧を出す |
| 日本語のファイル名や記号が化ける | `LANG` 未設定（＝C）の最小構成インストール | 未設定のときだけ `C.UTF-8` に倒す |

### デスクトップ / 端末

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| 記号が全部豆腐（□）になる | Nerd Font を Linux 側に入れていなかった（WSL では Windows Terminal 側にあった） | [run_once_after_15-nerd-font.sh](../run_once_after_15-nerd-font.sh) が導入する。端末側でフォントを選ぶ操作だけ手動 |
| クリップボードにコピーできない | `xclip` 決め打ち。Wayland 専用セッションや ssh 越し・TTY では動かない | `clip` 関数が wl-copy / xclip / OSC 52 を実行時に選ぶ |
| GUI の git クライアントや VS Code と鍵が共有されない | デスクトップの ssh-agent がいるのに keychain が別の agent を立てていた | `ssh-add -l` の終了コードで判定し、既存の agent があればそこへ足す |
| 全 ssh が `unix_listener: cannot bind to path` | `$HOME` が NFS だと ControlPath の Unix socket を作れない | `/run/user/$UID` を優先し、無い環境だけ `~/.ssh/control` に落とす |

## 残っている手作業

- **端末のフォント設定**: フォントの導入までは自動だが、どのフォントで描くかは端末エミュレータ側の設定。導入後に "JetBrainsMono Nerd Font" を選ぶ
- **apt 以外のディストリのパッケージ**: 05 が出す一覧を自分のパッケージマネージャで入れる。パッケージ名がディストリごとに違うので自動化していない
- **ログインシェル**: `chsh` が拒否される環境では手で設定する（管理者に依頼するか、`~/.bashrc` から `exec zsh` する）

## CI で見ているもの

`validate` ジョブが、鍵として読めない `~/.ssh/id_ed25519`（破損・空・別の鍵）でもテンプレート評価が落ちないことと、`mise.lock` に `bw` の linux-x64 / linux-arm64 エントリがあることを検査する。

一方、**Bitwarden を要求する経路（`run_once_before_01/02`）は CI では一度も走らない**。`CI=true` で [needs-bitwarden.sh](../scripts/needs-bitwarden.sh) が常に「不要」を返すため。ここに入る変更は手で確認すること。
