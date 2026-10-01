# AGENTS.md

Bash-only. No build system, no package manager — everything is sourced by `bash`.
There is no compiler step, so "it runs" is the only compile check you get.

## Commands

```bash
make test                          # full suite: 6 suites, ~121 assertions
bash tests/test_regressions.sh     # fast subset (~1.5s) — run this while iterating
bash tests/lint_check_slots.sh     # remediation-slot linter (also inside `make lint`)
./bin/arch-postinstall check base            # one category
./bin/arch-postinstall health boot network   # several categories
./bin/arch-postinstall check base --json     # machine-readable
```

`make help` lists all targets. `V=1`, `JSON=1`, `DRY=1` are Makefile flags (`make plan JSON=1`).

### `make lint` does not fail on shellcheck findings

The recipe is `shellcheck ... 2>/dev/null || echo "shellcheck not installed. ..."`, so a
non-zero shellcheck exit is swallowed and `make lint` still returns 0. Only
`tests/lint_check_slots.sh` can fail it. **CI (`ludeeus/action-shellcheck`, `severity: warning`,
`scandir: ./`) is the real shellcheck gate** — run `shellcheck` yourself before claiming lint is clean.

### Adding a test file

`tests/test_runner.sh` uses a hardcoded `SUITES=(...)` array, not a glob. A new
`tests/test_*.sh` is silently ignored until you add it there.

### Tests are host-dependent

`test_plan.sh`, `test_categories.sh`, and `test_json.sh` shell out to the real system
(`plan`, `pacman -Q`, `findmnt`, mountpoints), so results vary per machine. They still pass on
the Ubuntu CI runner because checks degrade to `SKIP`, not because they are hermetic.
`test_framework.sh` and `test_regressions.sh` are the unit-level suites.

## Hard dependency: `yq`

Every config read goes through `yq`. There is deliberately **no fallback parser** — the old
grep-based one returned empty for every nested key while exiting 0. `require_yaml_parser`
guards each entry point and exits **4** with an install hint. `_yaml_list_fallback` /
`_yaml_value_fallback` are error stubs kept only to give a clear message; do not call them.

Two independent copies of the YAML helpers exist and must stay in sync:
`lib/common.sh` (`yaml_list_get`, `yaml_value_get`, validator side) and `modules/core.sh`
(`yaml_list`, `yaml_value`, installer side). Extraction was attempted and deferred
(`IMPROVEMENTS.md` item 12).

## Two independent engines

| | Mutating installer | Read-only validator/planner |
|---|---|---|
| Entry | `install.sh` | `bin/arch-postinstall` |
| Sources | `modules/*.sh` + every `profiles/*.sh` | `lib/*.sh` + every `scripts/check/*.sh` |
| Reads | `config/base.yaml`, `config/hyprland.yaml` | same |
| Modes | `full`, `base`, `dotfiles` | `check`, `health`, `doctor`, `fix`, `status`, `plan` |

- **`install.sh -d` delegates to `arch-postinstall plan`.** Never add a second dry-run
  implementation — an earlier one was removed for exactly this reason (`IMPROVEMENTS.md` item 4).
- `install.sh` calls `require_root` *after* the dry-run short-circuit, so `plan` needs no sudo.
- Profiles are auto-globbed; modules are explicitly listed at the top of `install.sh`.

### Adding a check category

1. Create `scripts/check/<cat>.sh` defining **both** `check_<cat>()` and `health_<cat>()`.
2. Add `<cat>` to `ALL_CATEGORIES` in `bin/arch-postinstall`.

Check scripts are auto-globbed, but `ALL_CATEGORIES` is not — without step 2 the category is
unreachable. `doctor` and `status` run both the `check_` and `health_` functions per category.

### Adding a dotfile

Directory under `dotfiles/` **and** an entry in `dotfiles:` of `config/hyprland.yaml`. That list
is what `deploy_dotfiles_from_config` symlinks into `~/.config/`. Existing destinations are moved
to `~/.config-backup-<timestamp>/` first.

## The 7-argument `warn`/`fail` contract

```bash
warn <category> <name> <message> <details> <fix_cmd> <expected> <current>
fail <category> <name> <message> <details> <fix_cmd> <expected> <current>
```

**Putting a remediation in slot 4 (`details`) silently breaks it.** `fix_cmd` stays empty, so
`render_json` omits `suggested_fix` and `doctor --fix` filters the row out — the check still
reports, the remediation just quietly vanishes. Nine such misplacements existed here and were
invisible. `tests/lint_check_slots.sh` fails on this; run it after touching any check script.

### Fix strings are `eval`'d under sudo

`fix_cmd_is_safe` (`lib/checks.sh`) is an **allowlist**: it rejects backticks, `;`, `<`, `>`,
**all** `$` (including `$(...)`), newlines, lone `&`, and unbalanced quotes, then requires every
`&&`/`||`/`|`-separated segment to start with a word in `FIX_CMD_ALLOWED_CMDS`. Consequences:

- No command substitution in a fix string. Compute the value into a variable first, then
  interpolate it — the source-level `${...}` is fine, the expansion just can't happen at eval time.
- Adding a new command to a fix requires editing `FIX_CMD_ALLOWED_CMDS` too, or the fix is refused.
- `run_doctor_fix` returns 1 if any remediation failed; that propagates to the CLI exit code.

### Record format

`CHECKS_RESULTS` records are **US-delimited** (`CHECK_FIELD_SEP=$'\x1f'`), not `|`, because `|` is
legal data and a normal shell pipeline operator. 8 fields:

```bash
IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "$record"
```

Do not re-parse or re-delimit these by hand.

## Shell conventions

4-space indent · `[[ ... ]]` over `[ ... ]` · `$(...)` over backticks · `set -euo pipefail` ·
`log_info/log_success/log_warn/log_error/log_step` from `modules/core.sh` · comment non-obvious logic.

**Use `run_logged`, not `cmd | tee -a "$LOG_FILE"` inside an `if`.** Without `set -o pipefail` the
branch reads *tee's* status, so a failed command looks like success. The Makefile targets source
`core.sh` directly and do **not** set pipefail, so this silently inverts those decisions.

## Desktop layer

`dotfiles/hypr/` targets Hyprland 0.55+ and is **Lua, not conf**: `hyprland.lua` is the entrypoint,
`package.path` is augmented to `~/.config/hypr/` so submodules load via `require("config.x")`.
Keybinds use `hl.bind("MOD + KEY", hl.dsp.exec_cmd("..."))`; startup daemons use
`hl.on("hyprland.start", ...)`. Do not add new `.conf` files. Reload with `hyprctl reload`.

## Don't run these unattended

- `make fix` / `doctor --fix` prompt per remediation. Use `-y` / `AUTO_YES`.
- `make restore` prompts and overwrites `~/.config` from the newest `~/.config-backup-*`.
- `install.sh` refuses to run as root (`require_root`) and mutates the machine.

## Docs vs. code

`IMPROVEMENTS.md` is the live defect backlog — status legend, `file:line` citations, and a
reproduction for each entry. Read it before touching the engine; P0–P2 items 12–48 are open.
Fixed defects get a regression test in `tests/test_regressions.sh` (assertions are written to fail
against the pre-fix tree).

`README.md` and `ARCHITECTURE.md` file trees are stale — they omit `lib/planner.sh`,
`tests/test_plan.sh`, `tests/test_regressions.sh`, `tests/lint_check_slots.sh`, and `profiles/`.
`ARCHITECTURE.md` also claims unconditional idempotency that the code does not honour
(`IMPROVEMENTS.md` item 14). Trust the code.
