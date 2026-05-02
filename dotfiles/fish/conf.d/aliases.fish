# Only load in interactive shells
if status is-interactive
    # eza shortcuts
    alias ls="eza --icons"
    alias ll="eza -l --icons --git"
    alias la="eza -la --icons"
    alias tree="eza --tree"

    # Modern CLI tools
    alias cat="bat"
    alias find="fd"
    alias grep="rg"

    # Git shortcuts
    alias gs="git status -sb"

    # Check BIOS Update
    alias bios-update="fwupdmgr get-updates"
end
