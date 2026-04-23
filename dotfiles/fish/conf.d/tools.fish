# Load tools conditionally

if type -q zoxide
    zoxide init fish | source
end

if type -q vfox
    vfox activate fish | source
end
