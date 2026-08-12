#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test: test_categories.sh
# Description: Unit tests for category check logic, simulated assertions, and
#              mock environments.
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

echo "Running test_categories.sh..."

# ── Test Package Assertions with Mocking ──────────────────────────────────────

# Mock package_installed function
package_installed() {
    case "$1" in
        "installed-pkg") return 0 ;;
        *) return 1 ;;
    esac
}

reset_checks
assert_package_installed "installed-pkg" "test_pkg" || true
assert_eq "1" "${COUNT_PASS}" "assert_package_installed should register pass for installed pkg"

assert_package_installed "missing-pkg" "test_pkg" || true
assert_eq "1" "${COUNT_FAIL}" "assert_package_installed should register fail for missing pkg"

# ── Test Service Assertions with Mocking ──────────────────────────────────────

service_exists() {
    case "$1" in
        "active-svc"|"disabled-svc") return 0 ;;
        *) return 1 ;;
    esac
}

service_enabled() {
    case "$1" in
        "active-svc") return 0 ;;
        *) return 1 ;;
    esac
}

service_active() {
    case "$1" in
        "active-svc") return 0 ;;
        *) return 1 ;;
    esac
}

reset_checks
assert_service_enabled "active-svc" "test_svc" || true
assert_eq "1" "${COUNT_PASS}" "assert_service_enabled should pass for enabled svc"

assert_service_enabled "disabled-svc" "test_svc" || true
assert_eq "1" "${COUNT_FAIL}" "assert_service_enabled should fail for disabled svc"

assert_service_enabled "nonexistent-svc" "test_svc" || true
assert_eq "1" "${COUNT_WARN}" "assert_service_enabled should warn for missing svc"

# ── Test Mount Assertions with Mocking ────────────────────────────────────────

mount_exists() {
    case "$1" in
        "/") return 0 ;;
        *) return 1 ;;
    esac
}

reset_checks
assert_mount "/" "test_fs" || true
assert_eq "1" "${COUNT_PASS}" "assert_mount should pass for mounted root"

assert_mount "/nonexistent-mount" "test_fs" || true
assert_eq "1" "${COUNT_FAIL}" "assert_mount should fail for unmounted filesystem"

# ── Test User Group Assertions with Mocking ────────────────────────────────────

reset_checks
# Test with actual user group if available
current_user="${USER:-$(id -un)}"
assert_user_group "${current_user}" "wheel" "test_sec" || true
TESTS_RUN=$((TESTS_RUN + 1))
if [[ ${COUNT_PASS} -gt 0 || ${COUNT_FAIL} -gt 0 || ${COUNT_SKIP} -gt 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

echo "  -> test_categories.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
