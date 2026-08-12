#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test: test_cli.sh
# Description: Tests for CLI arguments, help, version, subcommands, and exit codes.
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

echo "Running test_cli.sh..."

# Test 1: Help command
help_out="$("${BIN}" --help)"
assert_eq "0" "$?" "CLI --help should exit with 0"
TESTS_RUN=$((TESTS_RUN + 1))
if echo "${help_out}" | grep -q "arch-postinstall <command>"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "FAIL: Help output missing Usage line" >&2
fi

# Test 2: Version command
ver_out="$("${BIN}" --version)"
assert_eq "0" "$?" "CLI --version should exit with 0"
TESTS_RUN=$((TESTS_RUN + 1))
if echo "${ver_out}" | grep -q "arch-postinstall v"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "FAIL: Version output missing arch-postinstall tag" >&2
fi

# Test 3: List categories command
list_out="$("${BIN}" list categories)"
assert_eq "0" "$?" "CLI list categories should exit with 0"
TESTS_RUN=$((TESTS_RUN + 1))
if echo "${list_out}" | grep -q "base" && echo "${list_out}" | grep -q "systemd"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "FAIL: List output missing expected categories" >&2
fi

# Test 4: Invalid option exit code (must be 3)
set +e
"${BIN}" --invalid-flag-123 &>/dev/null
inv_exit=$?
set -e
assert_eq "3" "${inv_exit}" "Invalid flag should exit with code 3"

# Test 5: Invalid subcommand exit code (must be 3)
set +e
"${BIN}" nonexistentcommand &>/dev/null
inv_cmd_exit=$?
set -e
assert_eq "3" "${inv_cmd_exit}" "Invalid command should exit with code 3"

echo "  -> test_cli.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
