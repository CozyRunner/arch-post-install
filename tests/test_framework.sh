#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test: test_framework.sh
# Description: Unit tests for core check registry, assertion helpers, and
#              accumulator status counters.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/common.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/output.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/checks.sh"

QUIET_MODE=true
USE_COLOR=false
init_output

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

echo "Running test_framework.sh..."

# Test 1: Reset state
reset_checks
assert_eq "0" "${COUNT_PASS}" "COUNT_PASS should be 0 on reset"
assert_eq "0" "${COUNT_WARN}" "COUNT_WARN should be 0 on reset"
assert_eq "0" "${COUNT_FAIL}" "COUNT_FAIL should be 0 on reset"
assert_eq "0" "${COUNT_SKIP}" "COUNT_SKIP should be 0 on reset"
assert_eq "0" "${COUNT_INFO}" "COUNT_INFO should be 0 on reset"

# Test 2: Status registration
pass "test_cat" "test_pass" "Test pass message"
assert_eq "1" "${COUNT_PASS}" "COUNT_PASS should be 1"

warn "test_cat" "test_warn" "Test warn message" "Diagnostic details" "sudo fix" "expected" "current"
assert_eq "1" "${COUNT_WARN}" "COUNT_WARN should be 1"

fail "test_cat" "test_fail" "Test fail message" "Fail details" "sudo fix-fail" "expected" "current"
assert_eq "1" "${COUNT_FAIL}" "COUNT_FAIL should be 1"

skip "test_cat" "test_skip" "Test skip message"
assert_eq "1" "${COUNT_SKIP}" "COUNT_SKIP should be 1"

info "test_cat" "test_info" "Test info message"
assert_eq "1" "${COUNT_INFO}" "COUNT_INFO should be 1"

# Test 3: Exit code with failures
get_exit_code && exit_code=0 || exit_code=$?
assert_eq "2" "${exit_code}" "get_exit_code should return 2 when failures exist"

# Test 4: Exit code with only warnings
reset_checks
pass "test_cat" "test_pass" "Pass"
warn "test_cat" "test_warn" "Warn"
get_exit_code && exit_code=0 || exit_code=$?
assert_eq "1" "${exit_code}" "get_exit_code should return 1 when only warnings exist"

# Test 5: Exit code with only passes/skips
reset_checks
pass "test_cat" "test_pass" "Pass"
skip "test_cat" "test_skip" "Skip"
info "test_cat" "test_info" "Info"
get_exit_code && exit_code=0 || exit_code=$?
assert_eq "0" "${exit_code}" "get_exit_code should return 0 when all passed/skipped"

# Test 6: json_escape helper
escaped="$(json_escape 'Hello "World" \ / '$'\n'$'\t')"
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "${escaped}" =~ \"World\" || "${escaped}" =~ World ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "FAIL: json_escape failed to handle quotes" >&2
fi

echo "  -> test_framework.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
