function __git_dirty
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        if not git diff --quiet --ignore-submodules --cached; or not git diff --quiet --ignore-submodules
            echo "●"
        end
    end
end
