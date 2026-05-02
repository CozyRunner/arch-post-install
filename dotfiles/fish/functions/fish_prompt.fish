function fish_prompt
    set -l last_status $status

    # Git prompt settings
    set -g __fish_git_prompt_show_informative_status 1
    set -g __fish_git_prompt_showcolorhints 1
    set -g __fish_git_prompt_char_stateseparator ' '

    # 1. Arch Logo
    set_color $fish_prompt_color_logo
    printf ' '

    # 2. User & Host
    set_color $fish_prompt_color_user
    printf '  %s@%s' $USER (prompt_hostname)

    # 3. Directory
    set_color $fish_prompt_color_cwd
    printf '  %s' (__short_cwd)

    # 4. Git Info
    set -l git_info (fish_git_prompt)
    if test -n "$git_info"
        set_color $fish_prompt_color_git
        set -l branch (string trim -c ' ()' $git_info)
        printf '  %s' $branch

        # Add dirty indicator from our helper if it's not already in fish_git_prompt
        if functions -q __git_dirty
            set -l dirty (__git_dirty)
            if test -n "$dirty"
                set_color $fish_color_error
                printf '%s' $dirty
            end
        end
    end

    # 5. Error Code
    if test $last_status -ne 0
        set_color $fish_color_error
        printf '  %d' $last_status
    end

    # 6. Prompt Symbol (on new line)
    echo
    if test (id -u) -eq 0
        set_color $fish_color_error
        printf '# '
    else
        set_color $fish_prompt_color_symbol
        printf '❯ '
    end

    set_color normal
end
