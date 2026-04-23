# Theme selection - auto-detect based on terminal background or time
function __load_theme
    set -l theme_dir (status dirname)/../themes
    set -l theme_file

    # Check for explicit theme preference
    if set -q fish_theme
        if test "$fish_theme" = "dark"
            set theme_file dark.fish
        else if test "$fish_theme" = "light"
            set theme_file light.fish
        end
    end

    # Auto-detect from terminal background if available
    if test -z "$theme_file"
        set -l bg (echo $TERM_PROGRAM 2>/dev/null)
        if string match -qi "term*" (echo $bg)
            set theme_file dark.fish
        end
    end

    # Fallback: time-based (dark after 6pm, before 6am)
    if test -z "$theme_file"
        set -l hour (date +%-H)
        if test $hour -ge 18 -o $hour -lt 6
            set theme_file dark.fish
        else
            set theme_file light.fish
        end
    end

    # Load theme
    if test -n "$theme_file" -a -f $theme_dir/$theme_file
        source $theme_dir/$theme_file
    end
end

__load_theme
functions -e __load_theme

# Theme switcher commands
function dark
    set -gx fish_theme dark
    source (status dirname)/../themes/dark.fish
end

function light
    set -gx fish_theme light
    source (status dirname)/../themes/light.fish
end
