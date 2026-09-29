#!/usr/bin/env bash
# Lint the details/fix slots of every check script.
#
# `warn`/`fail` take SEVEN POSITIONAL arguments:
#
#     warn <category> <name> <message> <details> <fix_cmd> <expected> <current>
#
# Nothing in that signature stops a caller from passing a remediation as the
# 4th argument. When that happens `fix_cmd` is left empty, so `render_json`
# omits `suggested_fix` and `run_doctor_fix` filters the row out entirely —
# the failure is reported but is silently unfixable by the tool. Nine such
# misplacements existed across six files, and they were invisible: the checks
# passed, the output looked right, the remediations just quietly vanished.
#
# Two rules, both derived from real defects found in this repo:
#
#   A. The `details` slot must not hold a remediation — unless the fix slot
#      already carries the identical string (redundant, but correct).
#   B. The `fix_cmd` slot must be an allowlisted command shape: every
#      `&&`/`||`/`|`-separated segment must start with a word in
#      FIX_CMD_ALLOWED_CMDS. This catches prose left in the fix slot
#      ("Check packages providing X"), allowlist gaps ("./install.sh"), and
#      callers that skip a slot so `expected` lands in `fix_cmd` — all of
#      which fix_cmd_is_safe refuses at runtime, silently losing the fix.
#
# Interpolated `${...}` / `$VAR` are replaced with a placeholder before the
# source text is tokenized, because a check script expands them before
# fix_cmd_is_safe ever sees the string — only the static shape is checkable
# here. Substituting first also means this linter never evaluates a variable
# reference written in the source, and never runs command substitution.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}" || exit 1

# The allowlist lives in lib/checks.sh. It can be sourced from a different tree
# than the one being linted, so this linter can be pointed at a pre-fix
# checkout to prove it actually fires.
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/checks.sh" >/dev/null 2>&1 || {
    echo "lint: could not source lib/checks.sh" >&2
    exit 4
}

REDIRECT='^[0-9]?>?(&[0-9]+)?$'   # in a variable so bash does not re-parse the ()s
ALLOWED=" $(for w in ${FIX_CMD_ALLOWED_CMDS}; do printf '%s ' "${w}"; done)"

# Reconstruct logical lines: join backslash continuations, keep the first line no.
logical_lines() {
    awk '
    { line[NR] = $0; cont[NR] = ($0 ~ /\\$/) }
    END {
        start = 1; out = ""
        for (i = 1; i <= NR; i++) {
            cur = line[i]
            # Drop the joining backslash: leaving it in makes it escape the
            # space that follows, which injects empty words into the token list.
            if (cont[i]) sub(/\\$/, "", cur)
            out = (out == "" ? cur : out " " cur)
            if (!cont[i]) { print start "\t" out; out = ""; start = i + 1 }
        }
    }' "$1"
}

# Tokenize a shell word list the way bash would. `set -f` stops pathname
# expansion; the caller has already removed `$` and command substitution.
words_of() {
    set -f
    eval "set -- $1" 2>/dev/null
    set +f
    printf '%s\n' "$@"
}

detail_violations=0
fix_violations=0

for f in scripts/check/*.sh; do
    while IFS=$'\t' read -r ln line; do
        [[ "${line}" =~ (warn|fail)[[:space:]]+(.*) ]] || continue
        rest="${BASH_REMATCH[2]}"
        rest="$(printf '%s' "${rest}" \
                 | sed -E 's/\$\{[^}]*\}/VAR/g; s/\$[A-Za-z_][A-Za-z0-9_]*/VAR/g; s/`[^`]*`/VAR/g; s/\$\([^)]*\)/VAR/g')"
        [[ "${rest}" == *'$('* || "${rest}" == *'`'* ]] && continue

        mapfile -t args < <(words_of "${rest}")
        (( ${#args[@]} >= 4 )) || continue
        # Drop trailing redirections the check scripts append.
        while (( ${#args[@]} > 4 )) && [[ "${args[-1]}" =~ ${REDIRECT} ]]; do
            unset 'args[-1]'
        done

        det="${args[3]}"
        fix="${args[4]:-}"

        # ── Rule A ─────────────────────────────────────────────────────────
        if [[ -n "${det}" ]]; then
            first="${det%% *}"; first="${first//[\"\']/}"
            if [[ "${det}" =~ ^(sudo[[:space:]]|\./) ]] || [[ "${ALLOWED}" == *" ${first} "* ]]; then
                if [[ "${det}" != "${fix}" ]]; then
                    printf 'DETAILS-HOLDS-FIX   %s:%-4s %s\n' "${f}" "${ln}" "${det}"
                    detail_violations=$((detail_violations + 1))
                fi
            fi
        fi

        # ── Rule B ─────────────────────────────────────────────────────────
        if [[ -n "${fix}" ]]; then
            bad=""
            while IFS= read -r seg; do
                seg="${seg#"${seg%%[![:space:]]*}"}"
                [[ -z "${seg}" ]] && continue
                first="${seg%%[[:space:]]*}"; first="${first//[\"\']/}"
                _fix_cmd_allowed "${first}" || bad="${bad}${bad:+, }'${first}'"
            done < <(tr ';|&' '\n' <<< "${fix}")
            if [[ -n "${bad}" ]]; then
                printf 'FIX-NOT-ALLOWLISTED %s:%-4s not allowed: %s\n                       -> %s\n' \
                    "${f}" "${ln}" "${bad}" "$(printf '%s' "${fix}" | tr -d "\"'")"
                fix_violations=$((fix_violations + 1))
            fi
        fi
    done < <(logical_lines "${f}")
done

if (( detail_violations + fix_violations > 0 )); then
    echo ""
    echo "lint: ${detail_violations} details-slot violation(s), ${fix_violations} fix-slot violation(s)" >&2
    echo "      A remediation in \`details\` is invisible to doctor --fix and to JSON consumers." >&2
    exit 1
fi

echo "lint_check_slots: OK"
exit 0
