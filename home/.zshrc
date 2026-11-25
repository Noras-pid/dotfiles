# Rei terminal: completion, history, suggestions and a matching prompt.
export PATH="$HOME/.local/bin:$HOME/.spicetify:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$PATH:$DOTNET_ROOT"
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt HIST_VERIFY INTERACTIVE_COMMENTS AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS

autoload -Uz compinit
compinit -d "$HOME/.cache/zsh-zcompdump"
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}── %d ──%f'
zstyle ':completion:*' list-colors 'di=38;2;156;207;255' 'ln=38;2;139;214;239' 'ex=38;2;149;213;167'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh-completion"
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lh --group-directories-first --icons=auto --git'
alias la='eza -lah --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
alias c='clear'
alias ff='fastfetch'
alias q='exit'
alias ..='cd ..'
alias ...='cd ../..'
alias ports='ss -tulpn'
alias myip='ip -brief address'
alias termhelp='rei-terminal-help'
function take() { mkdir -p -- "$1" && cd -- "$1"; }

export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --exclude .cache --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --exclude .cache --exclude node_modules'
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border=rounded --info=inline --prompt="❯ " --pointer="▶" --marker="✓" --color=bg:#0b1022,bg+:#17243a,fg:#e1e9f4,fg+:#c1e2ff,hl:#8bd6ef,hl+:#9ccfff,border:#38516b,prompt:#9ccfff,pointer:#e66a7d,marker:#95d5a7,header:#71869f,info:#9caec5 --bind=ctrl-/:toggle-preview'
export FZF_CTRL_T_OPTS='--preview="$HOME/.local/bin/rei-fzf-preview {}" --preview-window=right,55%,border-left --header="Файлы · Enter: вставить путь · Ctrl+/: предпросмотр"'
export FZF_ALT_C_OPTS='--preview="eza --tree --level=2 --color=always --icons=always {}" --preview-window=right,55%,border-left --header="Папки · Enter: перейти"'
export FZF_CTRL_R_OPTS='--header="История · Enter: вставить команду · Esc: отменить"'
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#92a5bb'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^@' autosuggest-accept

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

eval "$(starship init zsh)"
if [[ -o interactive && -n ${KITTY_WINDOW_ID:-} ]]; then
    printf '\n\033[1;38;2;156;207;255m  Noras\033[0m  \033[38;2;146;165;187m/  Rei Ayanami\033[0m\n'
    printf '  \033[38;2;156;174;197mTab — дополнить   Ctrl+R — история   termhelp — помощь\033[0m\n\n'
fi
# Highlighting must follow completion, prompt and all custom widgets.
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#95d5a7'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#95d5a7'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#95d5a7'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#e66a7d,underline'
ZSH_HIGHLIGHT_STYLES[path]='fg=#9ccfff'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#d6c791'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#d6c791'
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Claude CLI / Anthropic API
[[ -f "$HOME/.config/anthropic/env" ]] && source "$HOME/.config/anthropic/env"
alias codex='command codex --dangerously-bypass-approvals-and-sandbox'





# RE bench
export GHIDRA_INSTALL_DIR="$HOME/.local/opt/ghidra_12.2_PUBLIC"
export JAVA_HOME_REV="$HOME/.local/opt/jdk-25.0.5.1+2"
export PATH="$PATH:$HOME/.dotnet/tools"
