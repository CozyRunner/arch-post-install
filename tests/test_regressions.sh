#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
# Test: test_regressions.sh
# Description: Regression tests for defects found during code review. Each test
#              here failed before its corresponding fix and passes after.
#
#   1. YAML: nested keys must parse (the removed fallback returned empty)
#   2. YAML: a missing parser must fail loudly, never silently return empty
#   3. Dotfiles: a regular file at the destination must be backed up, not lost
#   4. Dotfiles: real directories backed up, stale symlinks repointed
#   5. Btrfs: the unguarded `rm -rf /.snapshots` must not return
#   6. Dry-run: install.sh -d must defer to the planner, not a second engine
#
# This suite is intentionally fast (no full `plan` invocations) so it can be
# run on every change.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
TMP_DIR=""

TESTS_RUN=0
TESTS_PASSED=0
FAILED_NAMES=()

cleanup() {
    [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# Non-fatal assertion helpers: record and continue, so one run reports
# every failure instead of aborting on the first.
ok() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    FAILED_NAMES+=("$1")
    echo "FAIL: ${1}" >&2
    [[ $# -gt 1 ]] && echo "      ${2}" >&2
    return 0
}

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        ok
    else
        fail "${name}" "expected '${expected}', got '${actual}'"
    fi
}

assert_ne() {
    local not_expected="$1" actual="$2" name="$3"
    if [[ "${not_expected}" != "${actual}" ]]; then
        ok
    else
        fail "${name}" "expected anything but '${not_expected}'"
    fi
}

TMP_DIR="$(mktemp -d /tmp/arch-regress.XXXXXX)"

echo "Running test_regressions.sh..."

# ── 1. Nested YAML keys must parse ────────────────────────────────────────────
# Before the fix, `_yaml_list_fallback` computed depth with ${key//[^:]}, which
# is always 0 for dot-separated keys, so every nested list came back EMPTY.
{
    source "${ROOT_DIR}/lib/common.sh" >/dev/null 2>&1
    source "${ROOT_DIR}/lib/output.sh" >/dev/null 2>&1

    if ! declare -f yaml_list_get &>/dev/null; then
        fail "yaml_list_get is defined"
    else
        ok
    fi

    pacman_count="$(yaml_list_get "${ROOT_DIR}/config/base.yaml" "packages.pacman" 2>/dev/null | grep -c .)"
    assert_ne "0" "${pacman_count}" "packages.pacman must be non-empty (was 0)"

    groups_count="$(yaml_list_get "${ROOT_DIR}/config/base.yaml" "user.groups" 2>/dev/null | grep -c .)"
    assert_ne "0" "${groups_count}" "user.groups must be non-empty (was 0)"

    services_count="$(yaml_list_get "${ROOT_DIR}/config/base.yaml" "services" 2>/dev/null | grep -c .)"
    assert_ne "0" "${services_count}" "services must be non-empty"

    # A specific value, to catch a parser that returns the right *count* of junk.
    first_pkg="$(yaml_list_get "${ROOT_DIR}/config/base.yaml" "packages.pacman" 2>/dev/null | head -1)"
    assert_eq "base-devel" "${first_pkg}" "packages.pacman yields real package names"

    # yq must be the declared parser, and the depth-computation bug must be gone.
    if grep -q 'target_depth' "${ROOT_DIR}/lib/common.sh" "${ROOT_DIR}/modules/core.sh" 2>/dev/null; then
        fail "broken depth computation removed" "target_depth still present"
    else
        ok
    fi
}

# ── 2. Missing yq must fail loudly, not silently return empty ─────────────────
# Build a PATH with coreutils but no yq, then confirm the guard trips and the
# CLI exits 4 ("Missing dependency or framework error", bin/arch-postinstall).
{
    NOYQ_BIN="${TMP_DIR}/noyq_bin"
    mkdir -p "${NOYQ_BIN}"
    for tool in bash sh sed grep awk head cat cut tr wc date id basename \
               dirname uname readlink ls stat find mktemp rm ln cp mv chmod; do
        real_path="$(command -v "${tool}" 2>/dev/null)" && ln -sf "${real_path}" "${NOYQ_BIN}/${tool}"
    done

    if PATH="${NOYQ_BIN}" command -v yq &>/dev/null; then
        fail "test harness can hide yq" "yq still visible in restricted PATH"
    else
        ok
    fi

    # The guard must return non-zero and mention the package to install.
    guard_out="$(
        set +e
        PATH="${NOYQ_BIN}" bash -c "
            source '${ROOT_DIR}/lib/common.sh' >/dev/null 2>&1
            require_yaml_parser
        " 2>&1
    )"
    guard_rc=$?
    assert_ne "0" "${guard_rc}" "require_yaml_parser fails when yq is absent"
    if [[ "${guard_out}" == *"pacman -S --needed yq"* ]]; then
        ok
    else
        fail "require_yaml_parser suggests the install command" "got: ${guard_out}"
    fi

    # The CLI must exit 4 rather than report a clean system.
    for cmd in plan check; do
        PATH="${NOYQ_BIN}" "${ROOT_DIR}/bin/arch-postinstall" "${cmd}" >/dev/null 2>&1
        assert_eq "4" "$?" "${cmd} exits 4 without yq"
    done

    # Metadata commands must keep working without yq.
    PATH="${NOYQ_BIN}" "${ROOT_DIR}/bin/arch-postinstall" --version >/dev/null 2>&1
    assert_eq "0" "$?" "--version works without yq"
}

# ── 3 & 4. Dotfile deployment must never destroy user state ──────────────────
# Before the fix, a plain file at ~/.config/<app> matched neither the
# directory nor the symlink branch, so `ln -sfn` overwrote it with no backup.
{
    D="${TMP_DIR}/dotfiles"
    H="${TMP_DIR}/home"
    mkdir -p "${D}"/{dirapp,fileapp,linkedapp} "${H}/.config" "${TMP_DIR}/other"

    printf 'dotfiles:\n  - dirapp\n  - fileapp\n  - linkedapp\n' > "${D}/cfg.yaml"
    for app in dirapp fileapp linkedapp; do
        echo "repo-content" > "${D}/${app}/repo.txt"
    done

    # Seed all three destination shapes.
    mkdir -p "${H}/.config/dirapp"
    echo "USER DIR DATA" > "${H}/.config/dirapp/keep.txt"
    echo "USER FILE DATA - irreplaceable" > "${H}/.config/fileapp"
    ln -sfn "${TMP_DIR}/other" "${H}/.config/linkedapp"

    (
        export HOME="${H}"
        source "${ROOT_DIR}/modules/core.sh" >/dev/null 2>&1
        source "${ROOT_DIR}/modules/dotfiles.sh" >/dev/null 2>&1
        # core.sh derives these at source time; override for isolation.
        DOTFILES_DIR="${D}"
        BACKUP_DIR="${TMP_DIR}/backups"
        QUIET_MODE=true
        deploy_dotfiles_from_config "${D}/cfg.yaml" >/dev/null 2>&1
    )

    for app in dirapp fileapp linkedapp; do
        if [[ -L "${H}/.config/${app}" ]]; then
            ok
        else
            fail "dotfile ${app} becomes a symlink" "still a plain $(stat -c %F "${H}/.config/${app}" 2>/dev/null || echo missing)"
        fi
    done

    # The regression: a regular file must be preserved, not overwritten.
    if [[ -f "${TMP_DIR}/backups/fileapp" ]] && \
       grep -q "irreplaceable" "${TMP_DIR}/backups/fileapp" 2>/dev/null; then
        ok
    else
        fail "regular file is backed up" "contents lost — no backup at ${TMP_DIR}/backups/fileapp"
    fi

    # Real directories must still be backed up intact.
    if [[ -f "${TMP_DIR}/backups/dirapp/keep.txt" ]]; then
        ok
    else
        fail "existing directory is backed up" "not found at ${TMP_DIR}/backups/dirapp"
    fi

    # A stale symlink to an unrelated checkout is repointed, not nested.
    if [[ "$(readlink "${H}/.config/linkedapp")" == "${D}/linkedapp" ]]; then
        ok
    else
        fail "stale symlink is repointed" "points to $(readlink "${H}/.config/linkedapp")"
    fi

    # Repo content must be reachable through the new symlink.
    if [[ "$(cat "${H}/.config/fileapp/repo.txt" 2>/dev/null)" == "repo-content" ]]; then
        ok
    else
        fail "repo content reachable via symlink"
    fi
}

# ── 5. The destructive btrfs path must stay removed ───────────────────────────
{
    # An unguarded `rm -rf /.snapshots` destroyed a live snapshot store when
    # snapper was absent (the guard failed open). Only advisory text may remain.
    rm_hits="$(grep -nE '^[[:space:]]*sudo rm -rf /\.snapshots' "${ROOT_DIR}/modules/btrfs.sh" 2>/dev/null | wc -l)"
    assert_eq "0" "${rm_hits}" "no executable 'rm -rf /.snapshots' in btrfs.sh"

    # And the failure-open guard must be gone.
    if grep -q 'if ! sudo snapper list-configs' "${ROOT_DIR}/modules/btrfs.sh" 2>/dev/null; then
        fail "btrfs guard verifies snapper presence" "old failure-open guard still present"
    else
        ok
    fi

    if grep -q 'command -v snapper' "${ROOT_DIR}/modules/btrfs.sh" 2>/dev/null; then
        ok
    else
        fail "btrfs checks for snapper before proceeding"
    fi
}

# ── 6. Dry-run must defer to the planner ─────────────────────────────────────
# Before the fix, `install.sh -d` printed 14 function names with no state
# discovery and contradicted the planner's findings.
{
    if grep -q 'run_cmd' "${ROOT_DIR}/install.sh" 2>/dev/null; then
        fail "the run_cmd shim is removed" "still present in install.sh"
    else
        ok
    fi

    if grep -q 'show_execution_plan' "${ROOT_DIR}/install.sh" 2>/dev/null; then
        ok
    else
        fail "dry-run delegates to the planner"
    fi

    # require_root must appear after the dry-run branch so previews need no sudo.
    dry_line="$(grep -n 'show_execution_plan$' "${ROOT_DIR}/install.sh" 2>/dev/null | tail -1 | cut -d: -f1)"
    root_line="$(grep -nE '^[[:space:]]*require_root$' "${ROOT_DIR}/install.sh" 2>/dev/null | tail -1 | cut -d: -f1)"
    if [[ -n "${dry_line}" && -n "${root_line}" && "${dry_line}" -lt "${root_line}" ]]; then
        ok
    else
        fail "dry-run short-circuits before require_root" "plan at line ${dry_line:-?}, require_root at ${root_line:-?}"
    fi
}

# ── 7. No unbound-variable crash in the check scripts (P1 item 5) ─────────────
# `local expected_tz current_tz` declares without assigning. Under `set -u` the
# later `[[ -z "${current_tz}" ]]` is fatal, killing the whole CLI in any
# chroot or container where timedatectl is absent. `base` is the first category,
# so `arch-postinstall check` died before printing anything.
{
    # A static "declared but not assigned" grep cannot distinguish the bug from
    # the legitimate declare-then-assign pattern, so assert the specific fix
    # and prove the behaviour: the timezone locals must be initialised.
    for f in "${ROOT_DIR}/scripts/check/base.sh" "${ROOT_DIR}/scripts/check/time.sh"; do
        if grep -q 'current_tz=""' "${f}" 2>/dev/null; then
            ok
        else
            fail "$(basename "${f}"): current_tz is initialised" \
                 "declared without a value and dereferenced under 'set -u'"
        fi
    done

    # The crash itself, reproduced: hide timedatectl and run the timezone check.
    NOTZ_BIN="${TMP_DIR}/notz_bin"
    mkdir -p "${NOTZ_BIN}"
    for tool in bash sh env cat sed grep awk head tail cut tr wc date id \
               basename dirname uname readlink ls stat find mktemp rm ln cp \
               mv chmod sleep printf tee sort uniq; do
        real="$(command -v "${tool}" 2>/dev/null)" && ln -sf "${real}" "${NOTZ_BIN}/${tool}" 2>/dev/null
    done

    if PATH="${NOTZ_BIN}" command -v timedatectl &>/dev/null; then
        fail "test harness can hide timedatectl"
    else
        ok
    fi

    out="$(PATH="${NOTZ_BIN}" "${ROOT_DIR}/bin/arch-postinstall" check base 2>&1)"
    rc=$?
    if grep -q 'unbound variable' <<< "${out}"; then
        fail "check base survives a missing timedatectl" "crashed: unbound variable"
    else
        ok
    fi
    assert_ne "1" "${rc}" "check base does not die on a missing timedatectl"
}

# ── 8. run_logged preserves exit status without pipefail (P1 item 6) ──────────
# The engine decided on `if some_cmd | tee -a "$LOG"; then`. Without
# `set -o pipefail` a pipeline's status is tee's, so a failed command read as
# success. Makefile targets source core.sh directly and do NOT set pipefail.
{
    (
        source "${ROOT_DIR}/modules/core.sh" >/dev/null 2>&1
        LOG_FILE="/dev/null"

        # Confirm the hazard the helper exists to avoid.
        if false | tee -a "${LOG_FILE}"; then
            printf 'UNSAFE\n'
        fi
    ) > "${TMP_DIR}/haz.txt" 2>&1

    if grep -q UNSAFE "${TMP_DIR}/haz.txt"; then
        fail "pipeline-in-condition hazard is understood" "harness assumption wrong"
    else
        ok
    fi

    (
        source "${ROOT_DIR}/modules/core.sh" >/dev/null 2>&1
        LOG_FILE="/dev/null"
        if run_logged false; then echo "IF-TRUE"; else echo "IF-FALSE"; fi
        if run_logged cat /etc/hostname >/dev/null; then echo "OK-TRUE"; else echo "OK-FALSE"; fi
    ) > "${TMP_DIR}/rl.txt" 2>&1

    if grep -q '^IF-FALSE$' "${TMP_DIR}/rl.txt"; then
        ok
    else
        fail "run_logged reports a failing command as failure" \
             "got: $(tr '\n' ' ' < "${TMP_DIR}/rl.txt")"
    fi

    if grep -q '^OK-TRUE$' "${TMP_DIR}/rl.txt"; then
        ok
    else
        fail "run_logged reports a succeeding command as success"
    fi

    # No conditional in the engine may still branch on a `| tee` pipeline.
    leftovers="$(grep -rn 'if .*| tee -a' "${ROOT_DIR}/modules/"*.sh 2>/dev/null | grep -v 'Prefer this over' | wc -l)"
    assert_eq "0" "${leftovers}" "no 'if cmd | tee' decisions remain in modules/"
}

# ── 9. Doctor refuses to eval an unsafe fix, and reports failures (P1 8 & 9) ──
# Fix strings are built from config-derived values and executed with `eval`
# under sudo, so a group name like 'wheel`id >/tmp/pwned`' was arbitrary root
# code execution. Separately, run_doctor_fix ended on a bare `echo` and so
# always returned 0, making `doctor --fix` report success on total failure.
{
    (
        set +u
        source "${ROOT_DIR}/lib/common.sh"  >/dev/null 2>&1
        source "${ROOT_DIR}/lib/output.sh"  >/dev/null 2>&1
        source "${ROOT_DIR}/lib/checks.sh"  >/dev/null 2>&1
        source "${ROOT_DIR}/lib/doctor.sh"  >/dev/null 2>&1
        C_RED=''; C_GREEN=''; C_RESET=''; C_GRAY=''
        C_BOLD=''; C_BLUE=''; C_CYAN=''; C_YELLOW=''

        declare -F fix_cmd_is_safe &>/dev/null || { echo "NO-VALIDATOR"; exit 0; }

        # Legitimate remediations must still be allowed.
        while IFS= read -r c; do
            [[ -z "${c}" ]] && continue
            fix_cmd_is_safe "${c}" && echo "ALLOW ${c}" || echo "REFUSE ${c}"
        done <<'ALLOWED'
sudo hostnamectl set-hostname arch-box
sudo timedatectl set-timezone Asia/Kolkata
sudo pacman -S ufw && sudo systemctl enable --now ufw && sudo ufw default deny
sudo locale-gen && echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
sudo usermod -aG wheel sachin
sudo systemctl restart systemd-resolved || cat /etc/resolv.conf
sudo paccache -r && sudo journalctl --vacuum-size=100M
ALLOWED
    ) > "${TMP_DIR}/allow.txt" 2>&1

    allow_n="$( { grep -c '^ALLOW ' "${TMP_DIR}/allow.txt" 2>/dev/null || true; } | head -1)"
    assert_eq "7" "${allow_n}" "all legitimate remediations are permitted"

    # Injection payloads must be refused, and must not execute.
    PAYLOAD_DIR="${TMP_DIR}/leak"
    mkdir -p "${PAYLOAD_DIR}"
    (
        set +u
        source "${ROOT_DIR}/lib/common.sh" >/dev/null 2>&1
        source "${ROOT_DIR}/lib/output.sh" >/dev/null 2>&1
        source "${ROOT_DIR}/lib/checks.sh" >/dev/null 2>&1
        while IFS= read -r c; do
            [[ -z "${c}" ]] && continue
            fix_cmd_is_safe "${c}" && echo "ALLOW" || echo "REFUSE"
        done <<EOF
usermod -aG wheel\`id >${PAYLOAD_DIR}/a\`
usermod -aG wheel\$(id >${PAYLOAD_DIR}/b)
usermod -aG wheel; id >${PAYLOAD_DIR}/c
usermod -aG wheel > ${PAYLOAD_DIR}/d
usermod -aG 'wheel
usermod -aG wheel & wget evil
bash -c 'id >${PAYLOAD_DIR}/e'
EOF
    ) > "${TMP_DIR}/deny.txt" 2>&1

    leak_n="$( { grep -c '^REFUSE' "${TMP_DIR}/deny.txt" 2>/dev/null || true; } | head -1)"
    assert_eq "7" "${leak_n}" "every injection payload is refused"
    if grep -q '^ALLOW' "${TMP_DIR}/deny.txt" 2>/dev/null; then
        fail "no payload is allowed through the validator"
    else
        ok
    fi

    # Refusing must mean refusing: none of the payloads may have run.
    if [[ -n "$(ls -A "${PAYLOAD_DIR}" 2>/dev/null)" ]]; then
        fail "no injection payload executed" \
             "created: $(ls -A "${PAYLOAD_DIR}" | tr '\n' ' ')"
    else
        ok
    fi

    # Exit-code contract for run_doctor_fix.
    for rc_test in "1:all fail" "0:all pass"; do
        want="${rc_test%%:*}"; label="${rc_test#*:}"
        got="$(
            AUTO_YES=true
            export AUTO_YES
            (
                set +u
                source "${ROOT_DIR}/lib/common.sh" >/dev/null 2>&1
                source "${ROOT_DIR}/lib/output.sh" >/dev/null 2>&1
                source "${ROOT_DIR}/lib/checks.sh" >/dev/null 2>&1
                source "${ROOT_DIR}/lib/doctor.sh" >/dev/null 2>&1
                C_RED=''; C_GREEN=''; C_RESET=''; C_GRAY=''
                C_BOLD=''; C_BLUE=''; C_CYAN=''; C_YELLOW=''
                if [[ "${want}" == "1" ]]; then
                    US=$'\x1f'
                    CHECKS_RESULTS=("net${US}dns${US}WARN${US}m${US}d${US}cat /nonexistent-xyz-123${US}e${US}c")
                else
                    US=$'\x1f'
                    CHECKS_RESULTS=("net${US}dns${US}WARN${US}m${US}d${US}cat /etc/hostname${US}e${US}c")
                fi
                run_doctor_fix >/dev/null 2>&1
                echo $?
            )
        )"
        assert_eq "${want}" "${got}" "doctor --fix returns ${want} when ${label}"
    done
}

# ── 10. Enabling the firewall must not lock out SSH (P1 item 7) ───────────────
# `config/base.yaml` enables sshd. The old code applied `default deny
# incoming` with no allow rule anywhere in the repo, so a `full` install run
# over SSH severed the session and locked the user out on next boot.
{
    if grep -q 'ufw allow' "${ROOT_DIR}/modules/system.sh" 2>/dev/null; then
        ok
    else
        fail "firewall adds an SSH allow rule" "no 'ufw allow' in system.sh"
    fi

    # The allow rule must be added BEFORE the deny policy, or it is useless.
    allow_line="$(grep -n 'ufw allow' "${ROOT_DIR}/modules/system.sh" 2>/dev/null | head -1 | cut -d: -f1)"
    deny_line="$(grep -n 'ufw default deny incoming' "${ROOT_DIR}/modules/system.sh" 2>/dev/null | head -1 | cut -d: -f1)"
    if [[ -n "${allow_line}" && -n "${deny_line}" && "${allow_line}" -lt "${deny_line}" ]]; then
        ok
    else
        fail "SSH is allowed before 'deny incoming'" \
             "allow at ${allow_line:-?}, deny at ${deny_line:-?}"
    fi

    # The deny policy must not be applied if no SSH rule can be established.
    if grep -q 'Refusing to enable the firewall' "${ROOT_DIR}/modules/system.sh" 2>/dev/null; then
        ok
    else
        fail "firewall aborts rather than locking out SSH"
    fi
}

# ── 11. Check records must not be delimited by '|' (P1 item 10) ──────────────
# CHECKS_RESULTS used '|' as its field separator and register_check rewrote
# pipes in fix commands to '&&'. Two consequences:
#   A) "echo 'LANG=…' | sudo tee /etc/locale.conf" became "… && sudo tee …",
#      so the locale file was never written — yet doctor reported success.
#   B) Only 5 of 8 fields were sanitised, so a '|' in category or name shifted
#      every later field, moving a message into the fix slot that doctor evals.
{
    R="$(
        set +u
        source "${ROOT_DIR}/lib/common.sh" >/dev/null 2>&1
        source "${ROOT_DIR}/lib/output.sh" >/dev/null 2>&1
        source "${ROOT_DIR}/lib/checks.sh" >/dev/null 2>&1

        [ -n "${CHECK_FIELD_SEP:-}" ] || { echo "NO-SEP"; exit 0; }

        # A) a genuine shell pipeline must survive verbatim
        reset_checks
        register_check "base" "locale" "WARN" "msg" "d" \
            "sudo locale-gen && echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf" "e" "c" >/dev/null 2>&1
        IFS="${CHECK_FIELD_SEP}" read -r _cat _name _st _msg _det fix _exp _cur <<< "${CHECKS_RESULTS[0]}"
        if [[ "${fix}" == *"echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf" ]]; then
            echo "PIPE-PRESERVED"
        else
            echo "PIPE-CORRUPTED: ${fix}"
        fi

        # B) pipes in EVERY field must not shift the record
        reset_checks
        register_check "se|c" "na|me" "FA|IL" "ms|g" "de|tails" "fi|x" "ex|p" "cu|r" >/dev/null 2>&1
        IFS="${CHECK_FIELD_SEP}" read -r a1 a2 a3 a4 a5 a6 a7 a8 <<< "${CHECKS_RESULTS[0]}"
        printf 'FIELDS %s %s %s %s %s %s %s %s\n' "$a1" "$a2" "$a3" "$a4" "$a5" "$a6" "$a7" "$a8"

        # C) the delimiter must be US, not '|'
        if [[ "${CHECK_FIELD_SEP}" == $'\x1f' ]]; then echo "SEP-IS-US"; else echo "SEP-WRONG"; fi
    )" 2>&1

    if grep -q '^PIPE-PRESERVED$' <<< "${R}"; then
        ok
    else
        fail "a piped fix command survives register_check" \
             "$(grep '^PIPE-CORRUPTED' <<< "${R}" | head -1)"
    fi

    if grep -q '^SEP-IS-US$' <<< "${R}"; then
        ok
    else
        fail "CHECK_FIELD_SEP is the US control character"
    fi

    # All eight fields must round-trip exactly, pipes and all.
    fields_line="$(grep '^FIELDS ' <<< "${R}" | head -1)"
    assert_eq "FIELDS se|c na|me FA|IL ms|g de|tails fi|x ex|p cu|r" "${fields_line}" \
        "all 8 fields round-trip without shifting"

    # No reader may still split a CHECKS_RESULTS record on '|'.
    pipe_readers="$(grep -c "IFS='|' read" "${ROOT_DIR}/lib/checks.sh" "${ROOT_DIR}/lib/doctor.sh" 2>/dev/null \
                   | awk -F: '{s+=$2} END {print s+0}')"
    assert_eq "0" "${pipe_readers}" "no reader splits check records on '|'"

    # The old corrupting rewrite must be gone.
    if grep -q 'fix_cmd//|/' "${ROOT_DIR}/lib/checks.sh" 2>/dev/null; then
        fail "the '|' -> '&&' rewrite is removed" "still present in checks.sh"
    else
        ok
    fi

    # doctor.sh must source checks.sh itself: it needs CHECK_FIELD_SEP, and
    # previously only worked because the CLI happened to source it first.
    if grep -q 'checks.sh' "${ROOT_DIR}/lib/doctor.sh" 2>/dev/null; then
        ok
    else
        fail "doctor.sh sources checks.sh" "relies on an implicit sourcing order"
    fi

    sep_standalone="$(
        set +u
        LIB_DIR="${ROOT_DIR}/lib"
        source "${ROOT_DIR}/lib/doctor.sh" >/dev/null 2>&1
        [ -n "${CHECK_FIELD_SEP:-}" ] && echo present || echo absent
    )"
    assert_eq "present" "${sep_standalone}" "CHECK_FIELD_SEP available when doctor.sh is sourced alone"
}

# ── 12. Remediations must reach the fix_cmd slot (P2 item 11) ────────────────
# warn/fail take (cat name message details fix_cmd expected current). Passing a
# remediation as the 4th argument leaves fix_cmd empty, so render_json omits
# `suggested_fix` and run_doctor_fix filters the row out — the failure is
# reported but is silently unfixable. Nine such misplacements existed across
# six files; the backlog named only four of them in two files.
#
# A second, related defect: prose left in the fix slot is refused at runtime by
# fix_cmd_is_safe, so those remediations were lost too.
{
    # 1. The dedicated linter must pass on the current tree.
    if lint_out="$(bash "${ROOT_DIR}/tests/lint_check_slots.sh" 2>&1)"; then
        ok
    else
        fail "no remediation sits in the details slot" \
             "$(printf '%s' "${lint_out}" | grep -E 'DETAILS-HOLDS-FIX' | head -1)"
    fi

    # 2. Forcing every probe to fail must make the remediations observable.
    #    Stubbing the probes is what drives the WARN branches that carry a fix.
    forced="$(
        set +u
        cd "${ROOT_DIR}"
        source lib/common.sh  >/dev/null 2>&1
        source lib/output.sh >/dev/null 2>&1
        source lib/checks.sh  >/dev/null 2>&1
        CONFIG_DIR="${ROOT_DIR}/config"; DEFAULT_PROFILE=hyprland; PROFILE=hyprland
        export CONFIG_DIR DEFAULT_PROFILE PROFILE JSON_OUTPUT=true DOCTOR_MODE=true
        package_installed()    { return 1; }
        service_exists()       { return 1; }
        service_enabled()      { return 1; }
        service_active()       { return 1; }
        user_service_exists()  { return 1; }
        aur_package_installed(){ return 1; }
        # Report every *checked* command as missing, but keep the YAML parser
        # resolvable: check_desktop reads the dotfiles list, which calls
        # require_yaml_parser, which itself probes command_exists yq.
        command_exists()       { [[ "${1}" == yq ]] && command -v yq &>/dev/null; }
        for c in bluetooth audio desktop systemd; do
            source "scripts/check/${c}.sh"
            "check_${c}"
        done
        render_json
    ) 2>/dev/null"

    # audio/pkg_pipewire is one of the rows that used to lose its fix.
    pkg_fix="$(printf '%s' "${forced}" \
        | jq -r '.checks[] | select(.name=="pkg_pipewire") | .suggested_fix // "MISSING"' 2>/dev/null)"
    assert_eq "sudo pacman -S --needed pipewire" "${pkg_fix}" \
        "a missing audio package carries its remediation in suggested_fix"

    # 3. Every emitted remediation must be one the validator will actually run.
    #    A fix the validator refuses is a fix that silently does nothing.
    emitted="$(printf '%s' "${forced}" | jq -r '.checks[] | .suggested_fix // empty' 2>/dev/null | sort -u)"
    n_emitted=0; refused=0; refusal_detail=""
    while IFS= read -r cmd; do
        [[ -z "${cmd}" ]] && continue
        n_emitted=$((n_emitted + 1))
        if ! ( set +u
                source "${ROOT_DIR}/lib/checks.sh" >/dev/null 2>&1
                fix_cmd_is_safe "${cmd}" ) >/dev/null 2>&1; then
            refused=$((refused + 1))
            refusal_detail="${refusal_detail} [${cmd}]"
        fi
    done <<< "${emitted}"

    assert_eq "0" "${refused}" \
        "every emitted remediation passes fix_cmd_is_safe${refusal_detail:+ — refused:${refusal_detail}}"

    if [[ ${n_emitted} -ge 10 ]]; then
        ok
    else
        fail "forced checks emit a full set of remediations" \
             "only ${n_emitted} suggested_fix values; expected >= 10"
    fi

    # 4. A fix the validator accepts must reach the allowlist, so that
    #    ./install.sh is a runnable remediation rather than a refused one.
    if bash -c 'source lib/checks.sh >/dev/null 2>&1
                fix_cmd_is_safe "sudo ./install.sh dotfiles"' 2>/dev/null; then
        ok
    else
        fail "./install.sh is an allowlisted remediation command"
    fi
}

# ── Summary ──────────────────────────────────────────────────────────────────

if [[ ${#FAILED_NAMES[@]} -gt 0 ]]; then
    echo "  -> test_regressions.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed, ${#FAILED_NAMES[@]} FAILED:" >&2
    for name in "${FAILED_NAMES[@]}"; do
        echo "       - ${name}" >&2
    done
    exit 1
fi

echo "  -> test_regressions.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
exit 0
