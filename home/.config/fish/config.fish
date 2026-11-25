source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

fish_add_path /home/noras/.spicetify

# Compact terminal greeting
function fish_greeting
    set_color --bold blue
    printf '  NORAS  '
    set_color brblack
    printf 'CachyOS · Hyprland\n\n'
    set_color normal
end

# Rei terminal appearance and interactive helpers.
source ~/.config/fish/rei-terminal.fish

# Claude CLI / Anthropic API
if test -f ~/.config/anthropic/env
    for line in (grep -E '^export ' ~/.config/anthropic/env)
        set -l kv (string replace -r '^export ' '' $line)
        set -l name (string split -m 1 '=' $kv)[1]
        set -l value (string split -m 1 '=' $kv)[2]
        set -gx $name (string trim -c "'\"" $value)
    end
end
alias codex "command codex --dangerously-bypass-approvals-and-sandbox"
