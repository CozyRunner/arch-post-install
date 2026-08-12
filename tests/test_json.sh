#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Test: test_json.sh
# Description: Validates JSON output formatting, schema compliance, and verifies
#              that zero ANSI escape codes pollute JSON output.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${SCRIPT_DIR}/bin/arch-postinstall"

TESTS_RUN=0
TESTS_PASSED=0

echo "Running test_json.sh..."

# 1. Generate JSON output from base check
set +e
json_out="$("${BIN}" check base --json 2>/dev/null)"
set -e

# 2. Check for ANSI escape sequences (e.g. \033[)
TESTS_RUN=$((TESTS_RUN + 1))
if echo "${json_out}" | grep -q $'\033\\['; then
    echo "FAIL: JSON output contains ANSI color escape sequences!" >&2
else
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# 3. Validate JSON parseability with jq or python
TESTS_RUN=$((TESTS_RUN + 1))
if command -v jq &>/dev/null; then
    if echo "${json_out}" | jq . >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: JSON output failed jq parse validation" >&2
    fi
elif command -v python3 &>/dev/null; then
    if python3 -c 'import json, sys; json.loads(sys.stdin.read())' <<< "${json_out}" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: JSON output failed python3 json parse validation" >&2
    fi
fi

# 4. Validate top-level schema fields (status, summary, checks)
if command -v jq &>/dev/null; then
    status_field="$(echo "${json_out}" | jq -r '.status // empty')"
    pass_cnt="$(echo "${json_out}" | jq -r '.summary.pass // empty')"
    checks_len="$(echo "${json_out}" | jq -r '.checks | length')"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "${status_field}" && "${status_field}" =~ ^(pass|warn|fail)$ ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: Invalid status field in JSON: '${status_field}'" >&2
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "${pass_cnt}" && "${pass_cnt}" -ge 1 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: Invalid summary.pass in JSON: '${pass_cnt}'" >&2
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "${checks_len}" && "${checks_len}" -ge 1 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL: checks array is empty in JSON" >&2
    fi
fi

echo "  -> test_json.sh: ${TESTS_PASSED}/${TESTS_RUN} assertions passed."
