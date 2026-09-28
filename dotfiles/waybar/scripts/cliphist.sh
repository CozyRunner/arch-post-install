#!/usr/bin/env bash

# Legacy wrapper redirecting to Clipse-backed clipboard script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/clipboard.sh" "$@"
