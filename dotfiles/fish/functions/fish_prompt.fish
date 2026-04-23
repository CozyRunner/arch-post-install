function fish_prompt
    set -l last_status $status

    # Logo
    set_color cyan
    printf ' '

    # Time
    set_color yellow
    printf '%s ' (date "+%H:%M")

    # User@Host
    set_color green
    printf '%s@%s ' $USER (prompt_hostname)

    # CWD
    set_color blue
    printf '%s ' (__short_cwd)

    # Git (built-in)
    set_color magenta
    printf '%s ' (fish_git_prompt)

    # Error code
    if test $last_status -ne 0
        set_color red
        printf '[%d] ' $last_status
    end

    # Prompt symbol
    if test (id -u) -eq 0
        set_color red
        printf '# '
    else
        set_color white
        printf '$ '
    end

    set_color normal
end
