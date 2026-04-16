if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Environment
set -gx EDITOR nvim
set -gx TERM xterm-256color

# Aliases
alias ls="eza --icons"
alias cat="bat"
alias find="fd"
alias grep="rg"
alias gs="git status"

# Path (example)
fish_add_path ~/.local/bin

# Greeting off
set -g fish_greeting ""

# Arch Logo 
set_color normal
function fish_prompt
    set_color cyan
    printf ' '
    set_color normal
    printf '%s@%s ' (whoami) (hostname -s)
    #set_color yellow
    printf '%s ' (basename (prompt_pwd))
    set_color normal
    printf '%s ' (if test (id -u) -eq 0; echo '#'; else; echo '$'; end)
end

# ls --color=auto
# echo foo | grep color=always foo

# alias ls='ls --color=never'

# Zoxide
if type -q zoxide
    zoxide init fish | source
end

# Disk Unlocker alias                                                                         
alias unlock='~/unlocker.sh'

# Arch Deep Cleanup                                                                           
alias cleanup='~/cleanup.sh'

# TERM Color Reset On Exit                                                                    
function fish_right_prompt
end

#vfox
vfox activate fish | source

# Harlequin TUI SQL 
alias sql='harlequin'
export PATH="$HOME/.local/bin:$PATH"

# pnpm
set -gx PNPM_HOME "/home/sachin/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
