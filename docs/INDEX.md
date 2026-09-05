# Documentation index

このファイルを、プロジェクト文書を探すときの入口にする。現在の挙動を調べる場合は、まず以下の対応表から必要な文書だけを読む。

## Current documentation

| 文書 | 読むとき |
| --- | --- |
| [current/bare-metal-linux.md](current/bare-metal-linux.md) | WSL2 以外の Linux、別アーキテクチャ、管理端末、デスクトップ環境での制約や手作業を確認するとき |
| [current/configuration.md](current/configuration.md) | chezmoi、Git、jj、mise、zsh、Sheldon、SSH、Zellij の設定値と設計理由を変更するとき |
| [current/ssh-keys-bitwarden.md](current/ssh-keys-bitwarden.md) | SSH 鍵の Bitwarden 連携、初回取得、既存鍵の保護、SSH クライアント設定を変更するとき |
| [current/scripts.md](current/scripts.md) | chezmoi の実行スクリプト、補完生成、検証スクリプトの役割や実装理由を変更するとき |
| [current/zsh-startup.md](current/zsh-startup.md) | zsh の起動時間、遅延読み込み、キャッシュ、補完生成を変更するとき |
| [commands.md](commands.md) | 変更後に実行する検証コマンドを選ぶとき |

プロジェクト全体の概要、セットアップ、日常運用、ファイル構成は [README.md](../README.md) を参照する。

## Decisions

現在、独立した decision record はない。継続的に有効な設計理由は、対応する `docs/current/` の文書に置く。

## Archive

完了済みの移行記録は `archive/` にある。現在の実装を理解するために通常は読まず、移行の経緯や旧環境の復旧手順が明示的に必要な場合だけ参照する。

- [archive/migration-yadm-to-chezmoi.md](archive/migration-yadm-to-chezmoi.md)
- [archive/migration-etc-zshenv-to-home-zshenv.md](archive/migration-etc-zshenv-to-home-zshenv.md)
