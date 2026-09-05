# Validation commands

変更した範囲に対応する検証だけを実行する。CI の正確な定義は [`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml) を優先する。

## Documentation-only changes

```sh
git diff --check
```

Markdown の相対リンクは、移動・改名した文書から参照先が存在することも確認する。

## Shell and chezmoi scripts

```sh
find . -path ./.git -prune -o -type f \
  \( -name '*.sh' -o -name '*.sh.tmpl' -o -path './dot_local/bin/*' \) \
  -print | sort | xargs shellcheck -e SC1091
shellcheck -e SC1091 .githooks/*
```

`*.sh.tmpl` を変更した場合は、レンダリング後の構文も確認する。

```sh
chezmoi --source . execute-template <run_onchange_after_30-mise-install.sh.tmpl | bash -n
chezmoi --source . execute-template <run_onchange_after_40-zsh-completions.sh.tmpl | bash -n
```

## zsh configuration

```sh
zsh -n dot_zshenv dot_config/zsh/dot_zshenv dot_config/zsh/dot_zshrc
```

起動経路やプラグイン読み込みを変更した場合は、対話シェルと起動時間も確認する。

```sh
zsh -i -c exit
hyperfine -w 5 -r 50 'zsh -i -c exit'
```

## Secrets and signing

```sh
bash scripts/check-secrets.sh --staged
bash scripts/check-secrets.sh --tracked
chezmoi --source . execute-template <dot_config/git/allowed_signers.tmpl >/tmp/allowed_signers
test -s /tmp/allowed_signers
```

履歴を変更した場合、または push 前に履歴全体を検査する場合:

```sh
bash scripts/check-secrets.sh --history
```

## mise lock

```sh
bash scripts/check-mise-lock.sh
```

一部のツールだけがインストールされた環境では、対象を指定する。

```sh
bash scripts/check-mise-lock.sh bat eza
```

## GitHub Actions

```sh
actionlint
```

ワークフローの YAML も変更した場合:

```sh
yamllint -d relaxed dot_config/zeno/config.yml .github/workflows/ci-cd.yml
```
