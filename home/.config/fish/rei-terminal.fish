# Shared Rei terminal style for Fish sessions.
if status is-interactive
    set -g fish_color_normal e1e9f4
    set -g fish_color_command 95d5a7
    set -g fish_color_param e1e9f4
    set -g fish_color_quote d6c791
    set -g fish_color_error e66a7d --underline
    set -g fish_color_autosuggestion 92a5bb
    set -g fish_color_operator 8bd6ef
    set -g fish_color_search_match --background=17243a
    set -g fish_pager_color_prefix 9ccfff --bold
    set -g fish_pager_color_completion e1e9f4
    set -g fish_pager_color_description 71869f
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git --exclude .cache --exclude node_modules'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --exclude .git --exclude .cache --exclude node_modules'
    set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border=rounded --prompt="❯ " --color=bg:#0b1022,bg+:#17243a,fg:#e1e9f4,fg+:#c1e2ff,hl:#8bd6ef,hl+:#9ccfff,border:#38516b,prompt:#9ccfff,pointer:#e66a7d,marker:#95d5a7,header:#71869f'
    set -gx FZF_CTRL_T_OPTS '--preview="$HOME/.local/bin/rei-fzf-preview {}" --preview-window=right,55%,border-left'
    set -gx FZF_ALT_C_OPTS '--preview="eza --tree --level=2 --color=always --icons=always {}" --preview-window=right,55%,border-left'
    fzf --fish | source
    if command -q zoxide
        zoxide init fish | source
    end
    starship init fish | source
    alias termhelp='rei-terminal-help'
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lh --group-directories-first --icons=auto --git'
    alias la='eza -lah --group-directories-first --icons=auto --git'
    alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
    function take --argument-names folder
        mkdir -p -- "$folder"; and cd -- "$folder"
    end
    function fish_greeting
        printf '\n\033[1;38;2;156;207;255m  Noras\033[0m  \033[38;2;146;165;187m/  Rei Ayanami\033[0m\n'
        printf '  \033[38;2;156;174;197mTab — дополнить   Ctrl+R — история   termhelp — помощь\033[0m\n\n'
    end
end
