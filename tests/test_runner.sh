#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test Runner: test_runner.sh
# Description: Executes all test suites and reports overall pass/fail status.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo "  Arch Post-Install Test Suite"
echo "============================================================"
echo ""

SUITES=(
    "test_framework.sh"
    "test_cli.sh"
    "test_json.sh"
    "test_categories.sh"
)

TOTAL_SUITES=0
PASSED_SUITES=0

for suite in "${SUITES[@]}"; do
    suite_path="${SCRIPT_DIR}/${suite}"
    if [[ -f "${suite_path}" ]]; then
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        chmod +x "${suite_path}"
        if bash "${suite_path}"; then
            PASSED_SUITES=$((PASSED_SUITES + 1))
        else
            echo "FAILED: ${suite}" >&2
        fi
        echo ""
    fi
done

echo "============================================================"
echo "  Test Summary: ${PASSED_SUITES}/${TOTAL_SUITES} test suites passed"
echo "============================================================"

if [[ ${PASSED_SUITES} -eq ${TOTAL_SUITES} ]]; then
    exit 0
else
    exit 1
fi
