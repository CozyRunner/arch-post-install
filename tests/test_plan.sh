#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test: test_plan.sh
# Description: Comprehensive test suite for declarative 'plan' / dry-run capability.
#              Tests CLI flags, JSON output, idempotent execution, desired-state
#              transitions, unconfigured/configured systems, and safety guarantees.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${SCRIPT_DIR}/bin/arch-postinstall"

TESTS_RUN=0
TESTS_PASSED=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${expected}" == "${actual}" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: ${msg} - expected '${expected}', got '${actual}'" >&2
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local msg="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "${condition}"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: ${msg}" >&2
        return 1
    fi
}

echo "Running test_plan.sh..."

# ── 1. CLI Execution & Flags ──────────────────────────────────────────────────

# Test 1.1: Default plan execution exits 0
set +e
plan_out="$("${BIN}" plan 2>&1)"
plan_exit=$?
set -e
assert_eq "0" "${plan_exit}" "arch-postinstall plan should exit with 0"
assert_true "echo \"${plan_out}\" | grep -q 'Arch Post-Install Plan'" "Plan output has title banner"
assert_true "echo \"${plan_out}\" | grep -q 'Summary:'" "Plan output has summary"

# Test 1.2: Plan with --profile hyprland
set +e
prof_out="$("${BIN}" plan --profile hyprland 2>&1)"
prof_exit=$?
set -e
assert_eq "0" "${prof_exit}" "arch-postinstall plan --profile hyprland should exit with 0"

# Test 1.3: Plan with --no-color
set +e
nocolor_out="$("${BIN}" plan --no-color 2>&1)"
set -e
assert_true "! echo \"${nocolor_out}\" | grep -q $'\033\\['" "Plan with --no-color contains no ANSI escape codes"

# Test 1.4: Invalid configuration file path exits with code 3
set +e
bad_cfg_out="$("${BIN}" plan --config /nonexistent/path/to/config.yaml 2>&1)"
bad_cfg_exit=$?
set -e
assert_eq "3" "${bad_cfg_exit}" "Plan with nonexistent config file should exit with code 3"

# ── 2. JSON Output & Schema Conformance ───────────────────────────────────────

set +e
json_out="$("${BIN}" plan --json 2>/dev/null)"
json_exit=$?
set -e
assert_eq "0" "${json_exit}" "arch-postinstall plan --json should exit with 0"

# Validate JSON parseability
if command -v jq &>/dev/null; then
    assert_true "echo '${json_out}' | jq . >/dev/null 2>&1" "Plan JSON output is parseable by jq"

    schema_ver="$(echo "${json_out}" | jq -r '.schema_version // empty')"
    assert_eq "1.0.0" "${schema_ver}" "Plan JSON schema_version is 1.0.0"

    status_val="$(echo "${json_out}" | jq -r '.status // empty')"
    assert_eq "success" "${status_val}" "Plan JSON status is success"

    plan_len="$(echo "${json_out}" | jq -r '.plan | length')"
    assert_true "[[ ${plan_len} -ge 1 ]]" "Plan contains at least one operation record"

    # Validate schema fields of first item
    first_op="$(echo "${json_out}" | jq -r '.plan[0].operation // empty')"
    first_sub="$(echo "${json_out}" | jq -r '.plan[0].subsystem // empty')"
    first_res="$(echo "${json_out}" | jq -r '.plan[0].resource // empty')"
    first_cur="$(echo "${json_out}" | jq -r '.plan[0].current_state // empty')"
    first_des="$(echo "${json_out}" | jq -r '.plan[0].desired_state // empty')"
    first_risk="$(echo "${json_out}" | jq -r '.plan[0].risk_level // empty')"

    assert_true "[[ -n '${first_op}' && '${first_op}' =~ ^(ADD|REMOVE|CHANGE|ENABLE|DISABLE|CREATE|UPDATE|SKIP|NOOP)$ ]]" "Operation type is valid (${first_op})"
    assert_true "[[ -n '${first_sub}' ]]" "Subsystem field is present (${first_sub})"
    assert_true "[[ -n '${first_res}' ]]" "Resource field is present (${first_res})"
    assert_true "[[ -n '${first_cur}' ]]" "Current state field is present (${first_cur})"
    assert_true "[[ -n '${first_des}' ]]" "Desired state field is present (${first_des})"
    assert_true "[[ -n '${first_risk}' && '${first_risk}' =~ ^(safe|caution|destructive)$ ]]" "Risk level is valid (${first_risk})"
elif command -v python3 &>/dev/null; then
    assert_true "python3 -c 'import json, sys; json.loads(sys.stdin.read())' <<< '${json_out}' >/dev/null 2>&1" "Plan JSON is valid python json"
fi

# ── 3. Missing Package vs Already-Installed Package ───────────────────────────

TEMP_DIR="$(mktemp -d /tmp/arch-plan-test.XXXXXX)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Create a test YAML config
cat > "${TEMP_DIR}/packages_test.yaml" << 'EOF'
packages:
  pacman:
    - bash
    - non-existent-mock-package-12345
  aur:
    - mock-aur-package-not-installed-999
  flatpak:
    - mock.flatpak.not.installed.App
EOF

set +e
pkg_test_json="$("${BIN}" plan --config "${TEMP_DIR}/packages_test.yaml" --json 2>/dev/null)"
set -e

if command -v jq &>/dev/null; then
    # bash must be NOOP (already installed)
    bash_op="$(echo "${pkg_test_json}" | jq -r '.plan[] | select(.resource == "bash") | .operation')"
    assert_eq "NOOP" "${bash_op}" "Already-installed package 'bash' should have operation NOOP"

    # non-existent package must be ADD
    missing_op="$(echo "${pkg_test_json}" | jq -r '.plan[] | select(.resource == "non-existent-mock-package-12345") | .operation')"
    assert_eq "ADD" "${missing_op}" "Missing package should have operation ADD"

    # missing current_state
    missing_cur="$(echo "${pkg_test_json}" | jq -r '.plan[] | select(.resource == "non-existent-mock-package-12345") | .current_state')"
    assert_eq "missing" "${missing_cur}" "Missing package current_state should be missing"
fi

# ── 4. Missing Service vs Enabled Service ─────────────────────────────────────

cat > "${TEMP_DIR}/services_test.yaml" << 'EOF'
services:
  - nonexistent-dummy-daemon-xyz
EOF

set +e
svc_test_json="$("${BIN}" plan --config "${TEMP_DIR}/services_test.yaml" --json 2>/dev/null)"
set -e

if command -v jq &>/dev/null; then
    # nonexistent service must be SKIP
    svc_op="$(echo "${svc_test_json}" | jq -r '.plan[] | select(.resource == "nonexistent-dummy-daemon-xyz") | .operation')"
    assert_eq "SKIP" "${svc_op}" "Nonexistent service should have operation SKIP"
fi

# ── 5. Dotfile Testing: Missing vs Existing Dir vs Symlink ─────────────────────

mkdir -p "${TEMP_DIR}/dotfiles/test_app1"
mkdir -p "${TEMP_DIR}/dotfiles/test_app2"
mkdir -p "${TEMP_DIR}/dotfiles/test_app3"

# Mock DOTFILES_DIR for this test by creating custom config
cat > "${TEMP_DIR}/dotfiles_test.yaml" << EOF
dotfiles:
  - test_app1
  - test_app2
EOF

# Subshell testing with overridden DOTFILES_DIR and HOME
(
    export DOTFILES_DIR="${TEMP_DIR}/dotfiles"
    export HOME="${TEMP_DIR}/fake_home"
    mkdir -p "${HOME}/.config"

    # test_app1: dest does not exist -> should be CREATE
    # test_app2: dest is already symlinked to source -> should be NOOP
    ln -s "${DOTFILES_DIR}/test_app2" "${HOME}/.config/test_app2"
    # test_app3: dest is a physical directory -> should be UPDATE (with caution)
    mkdir -p "${HOME}/.config/test_app3"

    cat > "${TEMP_DIR}/dotfiles_sub_test.yaml" << 'SUB_EOF'
dotfiles:
  - test_app1
  - test_app2
  - test_app3
SUB_EOF

    df_out="$("${BIN}" plan --config "${TEMP_DIR}/dotfiles_sub_test.yaml" --json 2>/dev/null)"

    if command -v jq &>/dev/null; then
        app1_op="$(echo "${df_out}" | jq -r '.plan[] | select(.resource == "~/.config/test_app1") | .operation')"
        assert_eq "CREATE" "${app1_op}" "Missing dotfile target should have operation CREATE"

        app2_op="$(echo "${df_out}" | jq -r '.plan[] | select(.resource == "~/.config/test_app2") | .operation')"
        assert_eq "NOOP" "${app2_op}" "Already symlinked dotfile should have operation NOOP"

        app3_op="$(echo "${df_out}" | jq -r '.plan[] | select(.resource == "~/.config/test_app3") | .operation')"
        assert_eq "UPDATE" "${app3_op}" "Existing real directory dotfile target should have operation UPDATE"

        app3_risk="$(echo "${df_out}" | jq -r '.plan[] | select(.resource == "~/.config/test_app3") | .risk_level')"
        assert_eq "caution" "${app3_risk}" "Replacing existing real directory has risk_level caution"
    fi
)

# ── 6. Fully Configured System Test (0 changes scenario) ──────────────────────

cur_host="$(cat /etc/hostname 2>/dev/null | tr -d '[:space:]' || hostname)"
cur_tz=""
[[ -L /etc/localtime ]] && cur_tz="$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
[[ -z "${cur_tz}" ]] && cur_tz="UTC"

cat > "${TEMP_DIR}/fully_configured.yaml" << EOF
system:
  hostname: ${cur_host}
  timezone: ${cur_tz}

packages:
  pacman:
    - bash
  aur: []
  flatpak: []

services: []
dotfiles: []
EOF

set +e
full_cfg_json="$("${BIN}" plan --config "${TEMP_DIR}/fully_configured.yaml" --json 2>/dev/null)"
set -e

if command -v jq &>/dev/null; then
    # hostname and bash should both be NOOP
    host_op="$(echo "${full_cfg_json}" | jq -r '.plan[] | select(.resource == "hostname") | .operation')"
    assert_eq "NOOP" "${host_op}" "Matching hostname should have operation NOOP"

    bash_op="$(echo "${full_cfg_json}" | jq -r '.plan[] | select(.resource == "bash") | .operation')"
    assert_eq "NOOP" "${bash_op}" "Matching package should have operation NOOP"
fi

# ── 7. Repeated Plan Execution (Idempotency) ──────────────────────────────────

set +e
plan_run1="$("${BIN}" plan --json 2>/dev/null)"
plan_run2="$("${BIN}" plan --json 2>/dev/null)"
set -e

if command -v jq &>/dev/null; then
    # The summary numbers and plan lengths must be completely identical
    ops1="$(echo "${plan_run1}" | jq -c '.summary')"
    ops2="$(echo "${plan_run2}" | jq -c '.summary')"
    assert_eq "${ops1}" "${ops2}" "Repeated plan runs must produce identical summary stats"

    total1="$(echo "${plan_run1}" | jq -r '.summary.total_operations')"
    total2="$(echo "${plan_run2}" | jq -r '.summary.total_operations')"
    assert_eq "${total1}" "${total2}" "Repeated plan runs must produce identical total operations"
fi

# ── 8. Non-Root Execution Check ───────────────────────────────────────────────

assert_true "[[ \${EUID:-1} -ne 0 ]]" "Test runs as non-root user"
set +e
non_root_out="$("${BIN}" plan --json 2>/dev/null)"
non_root_exit=$?
set -e
assert_eq "0" "${non_root_exit}" "Plan executes successfully without root privilege"

# ── 9. Safety & Regression Check: Zero System Changes During Planning ──────────

# Snapshot checksums of key files before plan
hash_pacman_before="$(md5sum /etc/pacman.conf 2>/dev/null || echo "none")"
hash_host_before="$(md5sum /etc/hostname 2>/dev/null || echo "none")"
dotconfig_count_before="$(find "${HOME}/.config" -maxdepth 2 2>/dev/null | wc -l)"

# Run planner multiple times
"${BIN}" plan >/dev/null 2>&1
"${BIN}" plan --profile hyprland >/dev/null 2>&1
"${BIN}" plan --json >/dev/null 2>&1

# Snapshot checksums after plan
hash_pacman_after="$(md5sum /etc/pacman.conf 2>/dev/null || echo "none")"
hash_host_after="$(md5sum /etc/hostname 2>/dev/null || echo "none")"
dotconfig_count_after="$(find "${HOME}/.config" -maxdepth 2 2>/dev/null | wc -l)"

assert_eq "${hash_pacman_before}" "${hash_pacman_after}" "Safety: /etc/pacman.conf must remain unchanged"
assert_eq "${hash_host_before}" "${hash_host_after}" "Safety: /etc/hostname must remain unchanged"
assert_eq "${dotconfig_count_before}" "${dotconfig_count_after}" "Safety: ~/.config structure must remain untouched"

echo "  -> test_plan.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
