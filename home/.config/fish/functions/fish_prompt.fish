function fish_prompt
    set -l last_status $status
    set_color brblue
    printf '╭─ '
    set_color --bold blue
    printf '%s' (prompt_pwd)
    set_color brmagenta
    printf '%s' (fish_git_prompt ' [%s]')
    if test $last_status -ne 0
        set_color red
        printf ' ✕ %s' $last_status
    end
    set_color normal
    printf '\n'
    set_color brblue
    printf '╰─❯ '
    set_color normal
end
