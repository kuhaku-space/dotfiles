export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=10000
export SAVEHIST=10000

# Rust
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"

# zeno.zsh
export ZENO_HOME="$XDG_CONFIG_HOME/zeno"
export ZENO_ENABLE_SOCK=1
export ZENO_GIT_CAT="bat --color=always"
export ZENO_GIT_TREE="eza --tree"

# fzf
export FZF_DEFAULT_OPTS="--reverse"

# OpenSSL
export OPENSSL_LIB_DIR="/usr/lib/x86_64-linux-gnu/"
export OPENSSL_INCLUDE_DIR="/usr/include/openssl/"

# Node.js
export NODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# compinit
skip_global_compinit=1

# bootstrap 等から bash で source される場合は zsh 専用構文を避ける
if [ -n "$ZSH_VERSION" ]; then
  typeset -U path  # PATH の重複エントリを自動で除去
  path+=("$HOME/.local/bin" "$CARGO_HOME/bin")
else
  export PATH="$PATH:$HOME/.local/bin:$CARGO_HOME/bin"
fi
