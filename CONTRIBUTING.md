# Contributing to Arch Post-Install Workbench

First off, thank you for considering contributing to this project! It's people like you who make the open-source community such an amazing place to learn, inspire, and create.

## How Can I Contribute?

### Reporting Bugs

- Use the GitHub Issue Tracker.
- Describe the bug in detail, including steps to reproduce.
- Include your system information (though this project is specific to Arch Linux).
- Attach relevant logs from the `logs/` directory.

### Suggesting Enhancements

- Open an issue with the "enhancement" label.
- Explain why the feature would be useful.
- Provide examples of how it might work.

### Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add unit or regression tests.
3. If you've changed APIs, update the documentation.
4. Run the full test suite (`make test` or `bash tests/test_regressions.sh`).
5. Run the remediation slot linter (`bash tests/lint_check_slots.sh`).
6. Run `shellcheck` across modified shell scripts (`make lint`).
7. Make sure your code follows the existing style guidelines below.

## Prerequisites & Development Tools

To develop and run the test suites locally, ensure you have:
- `bash` (5.0+)
- `yq` (v4+; mandatory YAML engine)
- `jq` (JSON verification and testing)
- `shellcheck` (static analysis)
- `git`

## Style Guide & Engineering Conventions

- Use 4 spaces for indentation in Bash scripts.
- Use `[[ ... ]]` for conditions instead of `[ ... ]`.
- Quote variables to prevent word splitting (`"${VAR}"`).
- Use `$(...)` instead of backticks for command substitution.
- Use `set -euo pipefail` in scripts.
- Use `run_logged`, not `cmd | tee -a "$LOG_FILE"` inside `if` statements (preserving pipefail semantics).
- Provide comments for non-obvious logic.
- Use the `log_` functions (`log_info`, `log_success`, `log_warn`, `log_error`, `log_step`) from `modules/core.sh` for output.

## Check Framework & Remediation Contract

When adding or modifying check scripts in `scripts/check/`:
- Always follow the 7-argument contract for `warn` and `fail`:
  ```bash
  warn <category> <name> <message> <details> <fix_cmd> <expected> <current>
  fail <category> <name> <message> <details> <fix_cmd> <expected> <current>
  ```
- **Never put a remediation command in slot 4 (`details`)**. Remediation commands must go in slot 5 (`fix_cmd`).
- Remediations must be static commands valid under the `fix_cmd_is_safe` allowlist (no runtime `$` or `$(...)` expansion).
- Run `bash tests/lint_check_slots.sh` before submitting your PR.

## Testing

```bash
make test                      # Run all 6 test suites
bash tests/test_regressions.sh # Fast regression suite (~1.5s, 80 assertions)
bash tests/lint_check_slots.sh # Static linter for check slot contracts
make lint                      # ShellCheck static analysis
```

## Modularity & Architecture

This project is built on a modular engine. When adding new functionality:

- **New Packages/Configs**: Update the YAML files in `config/`.
- **New Logic**: Create a new module in `modules/`.
- **New Profiles**: Add a profile script in `profiles/`.

Refer to [ARCHITECTURE.md](ARCHITECTURE.md) for more details.
