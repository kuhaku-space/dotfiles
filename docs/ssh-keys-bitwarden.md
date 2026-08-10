# SSH 鍵（Bitwarden 連携）

秘密鍵は Bitwarden の **SSH Key item** 1件に保存し、`chezmoi apply` 時に取得して `~/.ssh/` へ展開する。1つの鍵を認証と git 署名の両方に使い、全マシンで共有する（マシンごとの鍵生成はしない）。リポジトリには秘密鍵そのものも暗号化済みの秘密鍵も置かず、取得テンプレートだけが入る。**公開鍵は秘密ではない**ので平文でリポジトリに置く。

| ファイル | 展開先 | パーミッション | 用途 |
| --- | --- | --- | --- |
| [private_dot_ssh/private_id_ed25519.tmpl](../private_dot_ssh/private_id_ed25519.tmpl) | `~/.ssh/id_ed25519` | 0600 | 秘密鍵（認証 + 署名）。Bitwarden から取得 |
| [private_dot_ssh/id_ed25519.pub](../private_dot_ssh/id_ed25519.pub) | `~/.ssh/id_ed25519.pub` | 0644 | 公開鍵（git の `signingKey` が参照）。平文 |
| [private_dot_ssh/private_config](../private_dot_ssh/private_config) | `~/.ssh/config` | 0600 | ssh クライアント設定 |
| [private_dot_ssh/private_known_hosts.chezmoi](../private_dot_ssh/private_known_hosts.chezmoi) | `~/.ssh/known_hosts.chezmoi` | 0600 | GitHub のホスト鍵（初回 push の TOFU 確認を出さないため） |

`bw` CLI は初回だけ [run_once_before_01-bitwarden-cli.sh](../run_once_before_01-bitwarden-cli.sh) が公式バイナリで先行導入し、以降は mise（`npm:@bitwarden/cli`）で管理する。

## 公開鍵を平文で持つ理由

**鍵の期待値の出典を1箇所にする**ため。[.chezmoiignore](../.chezmoiignore) はこのファイルからフィンガープリントを都度導出して「ローカルの鍵が期待どおりか」を判定し、[allowed_signers](../dot_config/git/allowed_signers.tmpl) もこのファイルを `include` する。鍵をローテーションするときに差し替えるのはこの1ファイルだけでよく、フィンガープリントを別途書き写す必要がない。ついでに公開鍵の取得で `bw` を呼ばなくなる。

## 初回マシンでの取得手順

事前準備は不要。鍵取得が必要なときに、セットアップが順に **bw 導入 → ログイン → アンロック** まで自動で促す。だから新しいマシンでも [README のワンライナー](../README.md#セットアップ)1本でよく、`export BW_SESSION=...` も `bw login` も手で打つ必要はない（入力自体は対話で求められる）。内訳:

| 段階 | 担当 | 自動化の中身 |
| --- | --- | --- |
| 導入 | [run_once_before_01-bitwarden-cli.sh](../run_once_before_01-bitwarden-cli.sh) | `bw` が無ければ公式バイナリで先行導入 |
| ログイン | [run_once_before_02-bitwarden-login.sh](../run_once_before_02-bitwarden-login.sh) | 未ログインなら対話的に `bw login` を起動（メール+マスターパスワード+2FA を入力）。ログイン済みなら何もしない |
| アンロック | [chezmoi.toml](../.chezmoi.toml.tmpl) の `bitwarden.unlock = true` | テンプレート評価時に chezmoi が自動で `bw unlock` を実行（マスターパスワードを入力） |

> **ログインだけは無人化できない**。`bw login` は認証情報（メール+マスターパスワード、または API キー）を必要とし、それを public リポジトリに置けないため。上記はあくまで「適切なタイミングで自動的に入力を促す」もので、入力そのものは対話になる。非対話で済ませたい場合（CI など）は `BW_CLIENTID` / `BW_CLIENTSECRET` を環境変数に設定して `bw login --apikey` を使う方法があるが、API キーの取り扱いに注意。

鍵が既に正しく配置済み（ローカルの鍵のフィンガープリントがリポジトリの公開鍵と一致）のときは、[.chezmoiignore](../.chezmoiignore) が鍵を管理対象から外し、[scripts/needs-bitwarden.sh](../scripts/needs-bitwarden.sh) が 01/02 を空振りさせるので、通常の `chezmoi apply` では bw の導入・ログイン・アンロックのいずれも走らない。鍵を新しいマシンに増やしたいときは、Bitwarden の Web/アプリで対応する SSH Key item を作っておけばよい。

## ssh クライアント設定

非公開ホストを `~/.ssh/config.d/*.conf` に分ける方針と、`Include` を先頭に置く理由は [private_config](../private_dot_ssh/private_config) 冒頭のコメントにある。GitHub のホスト鍵を更新するときは:

```sh
curl -fsS https://api.github.com/meta | jq -r .ssh_keys[]
```

### 既存マシンでの注意

`~/.ssh/config` が管理下に入ったので、`chezmoi apply` は既存の `~/.ssh/config` を**上書きする**。ローカルにホスト定義があるマシンでは、apply する前に退避しておく:

```sh
mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh/config.d
cp ~/.ssh/config ~/.ssh/config.d/local.conf && chmod 600 ~/.ssh/config.d/local.conf
chezmoi diff ~/.ssh/config   # 上書き内容を確認してから
chezmoi apply
```
