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
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes (if applicable).
5. Make sure your code follows the existing style (ShellCheck is used for linting).

## Style Guide

- Use 4 spaces for indentation in Bash scripts.
- Use `[[ ... ]]` for conditions instead of `[ ... ]`.
- Quote variables to prevent word splitting.
- Use `$(...)` instead of backticks for command substitution.
- Provide comments for non-obvious logic.
- Use the `log_` functions from `modules/core.sh` for output.

## Modularity & Architecture

This project is built on a modular engine. When adding new functionality:

- **New Packages/Configs**: Update the YAML files in `config/`.
- **New Logic**: Create a new module in `modules/`.
- **New Profiles**: Add a profile script in `profiles/`.

Refer to [ARCHITECTURE.md](ARCHITECTURE.md) for more details.
