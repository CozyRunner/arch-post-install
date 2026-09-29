# Improvement Backlog

Prioritized list of defects and structural improvements identified during a full code review of the engine (`install.sh`, `bin/`, `lib/`, `modules/`, `scripts/`) and the desktop layer (`dotfiles/`).

**Status legend:** `[ ]` open · `[~]` in progress · `[x]` done · `[~]` deferred with reason

Every entry cites `file:line` and, where the defect is behavioural, a concrete reproduction or measurement so it can be confirmed without re-reading the whole engine.

**Baseline at time of writing:** `make test` passes 5/5 suites, 66 assertions, ~3m33s.

---

## Progress

**P0, P1, and P2 item 11 complete. Items 1–11 are all fixed and covered by regression tests.**

All eleven shared a root cause worth naming: the engine *failed silently*. A missing parser, an unexpected file type, a missing binary, a command that never ran, a failed remediation, an uninitialised variable, a record delimiter that couldn't survive its own data, and a remediation filed in the wrong positional slot all produced the same outcome — a successful-looking run that did the wrong thing, or a destructive one. Each now fails loudly and refuses to act on state it has not verified.

| # | Item | Resolution |
|---|---|---|
| 1 | YAML fallback returned empty for every nested key | `yq` is now a hard dependency; every config path aborts with an install hint and a non-zero exit |
| 2 | Dotfile deployment destroyed regular files | All three destination shapes (dir / file / symlink) are now preserved before linking |
| 3 | `rm -rf /.snapshots` behind a fail-open guard | `rm -rf` deleted; subvolume and directory cases handled explicitly, unknown state aborts |
| 4 | Two disagreeing dry-run implementations | `install.sh -d` delegates to `plan`; the `run_cmd` shim is gone |
| 5 | Unbound variable killed the whole CLI | `current_tz` initialised in both check scripts |
| 6 | `set -e` aborted the install mid-flight | New `run_logged` helper; per-unit warnings instead of aborting the run |
| 7 | UFW deny-incoming with no SSH allow rule | SSH allowed *before* the deny policy; aborts rather than risk a lockout |
| 8 | Doctor failures never reached the exit code | `run_doctor_fix` returns 1 when any remediation failed |
| 9 | `eval` on config-derived fix strings | New allowlist validator; unsafe fixes are refused, not executed |
| 10 | `\|` delimiter corrupted fix commands and shifted fields | Records now US-delimited (`CHECK_FIELD_SEP`); nothing is rewritten, all 8 fields round-trip |
| 11 | Remediations filed in the `details` slot, prose in `fix_cmd` | 13 call sites corrected; remediations reaching `suggested_fix` went 1/12 → 12/12; `tests/lint_check_slots.sh` prevents recurrence |

`tests/test_regressions.sh` (55 assertions, ~1.5s) locks all eleven in. It is proven to fail against the pre-fix tree — **22 of its 55 assertions fail on a pristine `HEAD` checkout**. Full suite is now **6/6 suites, 121 assertions**.

**Still open:** items 12–48. Item 12 (duplicated YAML accessors) is effectively resolved by item 1 — the two copies no longer exist. Item 10a (planner's parallel `\|` delimiter) is display-only and deferred.

### Notable finding during this pass

Item 6's fix exposed a second, subtler bug in the same pattern. `if some_cmd | tee -a "$LOG"; then` is
only correct under `set -o pipefail`; without it the branch sees *tee's* status and always succeeds.
The Makefile targets source `core.sh` directly and do **not** set pipefail, so the SSH-safety decision
in item 7 would have silently inverted. This was caught by a fake `ufw` that failed but was reported
as succeeding. The new `run_logged` helper captures the command's own exit status and is
pipefail-independent — worth using for any future conditional command.

---

## P0 — Critical (data loss / silent total failure)

### 1. YAML fallback parser returns nothing for every nested key

- [x] **Fixed — `yq` is now a hard dependency and the tool fails loudly.** Decision: declare the dependency rather than reimplement a parser. A loud failure beats silent corruption.

`lib/common.sh` and `modules/core.sh` both gained a `require_yaml_parser` guard; the broken depth computation is deleted from both and the stubs return an explicit error. The `full`/`base` flows still bootstrap `yq` via `setup_core()` before the first config read. The `dotfiles` mode and every config-consuming module function (`install_packages_from_config`, `enable_services_from_config`, `setup_users`, `deploy_dotfiles_from_config`, `install_flatpaks_from_config`, `setup_hyprland`) each guard independently — necessary because `yaml_list` is consumed via process substitution, so its exit status is invisible to the caller.

Verified: nested keys now parse (30 / 7 lines, previously 0 / 0); with `yq` hidden, every path exits non-zero with an install hint; `arch-postinstall` returns its documented **exit 4** while `--version` and `list` still work.

<details><summary>Original defect detail</summary>

- **Site:** `lib/common.sh:266-310` and `modules/core.sh:163-216` (duplicated — see item 12).

```bash
local target_depth="${key//[^:]}"   # comment claims "count colons for depth"
target_depth="${#target_depth}"
```

`${key//[^:]}` deletes every non-colon character. Keys are **dot**-separated (`packages.pacman`, `user.groups`), so `target_depth` is always `0`. The parser additionally tracks no parent path at all, so the `packages.` prefix of the key is never used. The convention is also internally inconsistent: `services:` sits at depth 0 while `pacman:` sits at depth 1, so no single constant is correct for both.

| Call | Before | After |
|---|---|---|
| `packages.pacman` | **0** | 30 ✅ |
| `user.groups` | **0** | 7 ✅ |
| `hyprland.yaml packages.pacman` | **0** | ✅ |
| `services` | 7 | 7 ✅ |

**Impact without `yq` on `PATH`:** `install_base_packages` installed zero packages, `setup_users` added the user to no groups (not even `wheel`) while reporting success, and `plan` declared a clean system with no declared packages. Silent wrong behaviour is the worst failure mode for a provisioning tool.

</details>

### 2. Dotfile deployment destroys existing regular files with no backup

- [x] **Fixed.** `modules/dotfiles.sh:37-71`

The `if` handled `-d dest` (backup) and `-L dest` (unlink), but a **plain file** matched neither branch, so no backup occurred and `ln -sfn` overwrote it.

Reproduction (verified in sandbox, pre-fix):

```
before:  ~/.config/myapp  = regular file, "IMPORTANT USER DATA"
  -> branch: NONE (no backup performed)
after:   ~/.config/myapp -> /…/dotfiles/myapp   (symlink, DATA LOST)
```

This contradicted three places in the repo:

- `lib/planner.sh:284` — *"Existing file will be backed up and replaced with symlink"*
- `ARCHITECTURE.md:66` — *"automatically preserves timestamped backups"*
- `README.md:56` — *"automatic backups of existing configs"*

Now `-L` is tested first (so symlinked directories aren't mistaken for real ones), any remaining `-e` target — directory **or** file — is backed up, a failed `mv` skips the entry rather than proceeding, and the `ln` result is checked. `~/.config` is also created first, and the reason strings distinguish "existing directory" from "existing file". The planner's promise is now accurate.

### 3. `rm -rf /.snapshots` behind a guard that fails open

- [x] **Fixed.** `modules/btrfs.sh:41-100`

<details><summary>Original defect detail</summary>

- **Site:** `modules/btrfs.sh:46-56`

```bash
if ! sudo snapper list-configs 2>/dev/null | grep -qw "root"; then
    …
    sudo rm -rf /.snapshots 2>/dev/null || true
```

The guard failed open: if `snapper` was missing (the `pacman -S` at `btrfs.sh:43` was never checked), `list-configs` errored, the pipeline returned non-zero, `!` inverted it, and the code concluded "no root config exists" and deleted the snapshot store. A `grep` over a command that never ran is not a state check.

Secondary: `rm -rf` **cannot** delete a btrfs subvolume root — `unlink()` returns `ENOTEMPTY`, and `2>/dev/null` hid the failure, so the `# handle safely` comment was false.

</details>

`rm -rf` is gone entirely; only advisory text naming it as a manual remedy remains. The function now refuses to proceed on an unknown state:

- the `pacman -S` result is checked, and `command -v snapper` is verified before any reasoning about configs;
- `snapper list-configs` output is captured, and a **failed** invocation returns 1 rather than being read as "no config exists";
- `/.snapshots` is probed with `findmnt -n -o FSTYPE` — a mounted btrfs subvolume is removed via `btrfs subvolume delete` (which actually works, unlike `rm -rf`), with failure aborting;
- a plain directory is removed with `rmdir` only when empty; a non-empty `/.snapshots` aborts with a manual-remedy message, so this code path can never destroy user data;
- `create-config` failure aborts.

### 4. Two independent, disagreeing dry-run implementations

- [x] **Fixed.** `install.sh:181-199` — `plan` is now the single dry-run authority.

<details><summary>Original defect detail</summary>

- **Site:** `install.sh:154-160` vs `lib/planner.sh`

`DRY_RUN` appeared in only 4 places repo-wide and gated nothing but the top-level dispatch:

- `install.sh -d` printed 14 function names and performed **no state discovery**.
- `arch-postinstall plan` did real discovery and risk classification — and **contradicted** the executor (planner promised a dotfile backup that `dotfiles.sh` never performed; planner checks `^AutoEnable` while `system.sh:137` only matches the commented form).

Additionally, `install.sh -d` still required `sudo -v` and refused to run as root, and skipped `check_internet` entirely, so an offline machine previewed cleanly then hard-exited.

</details>

The `run_cmd` shim is deleted, so `DRY_RUN` no longer gates anything. `install.sh -d` now delegates to `bin/arch-postinstall plan`, so the preview and the executor can no longer disagree by construction. The delegation happens **before** `require_root`, so a preview needs no sudo and mutates nothing.

Verified: `./install.sh -d base` and `./bin/arch-postinstall plan` emit an identical 161-line operation set, and `require_root` appears only after the dry-run branch (both asserted by regression tests).

---

## P1 — High

### 5. Unbound variable kills the entire CLI

- [x] **Fixed.** `scripts/check/base.sh:56-60`, `scripts/check/time.sh:14-18`

<details><summary>Original defect detail</summary>

- **Site:** `scripts/check/base.sh:57-62` and `scripts/check/time.sh:15-20`

```bash
local expected_tz current_tz      # declares, does not assign
expected_tz="$(…)"
if command_exists timedatectl; then
    current_tz="$(…)"
fi
if [[ -z "${current_tz}" && -L /etc/localtime ]]; then   # ← dereferences unset
```

Under `set -uo pipefail` (`bin/arch-postinstall:8`) this was fatal: `current_tz: unbound variable`, exit 1, no summary, no JSON, no exit-code contract. `base` is the **first** entry in `ALL_CATEGORIES`, so `arch-postinstall check` died on its first category. Latent only because `timedatectl` always exists on real Arch — it fires in a chroot, container, or recovery shell.

</details>

Both sites now use `local expected_tz="" current_tz=""`, with a comment recording why the initialisation is load-bearing. Verified by hiding `timedatectl` and running `check base`: previously `current_tz: unbound variable`, exit 1; now 7/7 pass, exit 0.

### 6. `set -e` aborts the install mid-flight

- [x] **Fixed.** `modules/services.sh:38-88` and every `if … | tee -a` decision across `modules/`

<details><summary>Original defect detail</summary>

- **Site:** `modules/services.sh:41,44,47,50`; also `btrfs.sh:75`, `system.sh:105`, `system.sh:122-125`

```bash
if systemctl cat "${svc}" &>/dev/null; then
        sudo systemctl enable --now "${svc}" 2>&1 | tee -a "${LOG_FILE}"
```

Only the `if` **condition** is errexit-exempt; the pipeline in the **body** is not, and `pipefail` propagates `systemctl`'s status. Highest-risk call is `install.sh:188` `run_cmd enable_base_services`, which enables `docker` (`config/base.yaml:52`) — a unit that fails routinely. The abort left ZRAM, UFW, snapper, fonts, fish, flatpak and **all dotfiles** unconfigured, surfaced only by the generic trap message at `core.sh:39`.

The identical pattern was correctly guarded at `packages.sh:51` and `flatpak.sh:55` — the protection was accidental, not intentional.

</details>

`enable_services_from_config` now uses the new `run_logged` helper for every `enable`, warns per-unit instead of aborting, and reports a final `failed` list. The same helper replaced all remaining `if cmd | tee -a "$LOG_FILE"` decisions in `modules/` (11 sites).

**`run_logged` exists because the original pattern was wrong in a second way.** Without `set -o pipefail`, a pipeline's status is *tee's*, so `if sudo ufw allow OpenSSH | tee -a "$LOG"; then` takes the success branch even when `ufw` failed. The Makefile targets source `core.sh` directly and do **not** set pipefail — so the SSH-safety decision in item 7 would have silently inverted. I hit this while testing item 7: a fake `ufw` that failed was reported as succeeding. `run_logged` captures the command's own exit status and is pipefail-independent.

### 7. UFW `default deny incoming` with SSH enabled and no allow rule

- [x] **Fixed.** `modules/system.sh:114-170`

<details><summary>Original defect detail</summary>

- **Site:** `modules/system.sh:122-125`

`config/base.yaml:51` enables `sshd`; `system.sh:122-125` then hard-dropped all inbound traffic. No `ufw allow OpenSSH` / `22/tcp` existed anywhere in the repo. A `full` install run over SSH severed the session and locked the user out on next boot. The `install.sh:121-130` confirmation text did not mention the firewall.

Secondary: Docker's nat chain bypasses UFW's `INPUT` policy entirely, so the `log_success "…default deny incoming posture"` overstated the result.

</details>

`setup_firewall` now reads `services` from the config and, **before** applying any policy, allows SSH when `sshd`/`openssh`/`ssh`/`dropbear` is present — trying the `OpenSSH` profile and falling back to `22/tcp` for systems with no profile registered. The ordering is load-bearing and is asserted by a test.

Three safety properties:

- if neither allow method succeeds, it **aborts before `ufw default deny incoming`** — the lockout is never even staged;
- after the defaults are applied it re-checks `ufw status` and aborts rather than enabling if no SSH rule is present;
- a `SSH_CONNECTION` warning tells the user to keep the session open.

`ufw_has_rule_ssh` is a new helper matching either the profile name or `22/tcp`.

### 8. Doctor remediation failures never reach the exit code

- [x] **Fixed.** `lib/doctor.sh:146-186`

<details><summary>Original defect detail</summary>

- **Site:** `bin/arch-postinstall:344-345`, `lib/doctor.sh:115-163`

`get_exit_code` derives status only from `COUNT_FAIL`/`COUNT_WARN`, which the *checks* populate. `run_doctor_fix` tracked its own `applied`/`skipped`/`failed` locals, printed them, and returned the status of a trailing `echo` (0).

Result: `arch-postinstall doctor --fix -y` and `make fix` **exited 0 even when every remediation failed** — breaking the contract documented at `bin:105-110` and making the command unusable in automation.

</details>

`run_doctor_fix` now returns 1 when any remediation failed. The `eval` status is also captured explicitly first, so the failure message reports the real exit code — the old `$?` inside the `else` branch had already been clobbered by the `[[ ]]` test and always printed the same wrong value.

Verified: all-pass → 0, all-fail → 1, mixed → 1, nothing fixable → 0.

### 9. `eval` on config-derived fix strings

- [x] **Fixed.** `lib/checks.sh:52-125` (new `fix_cmd_is_safe`), `lib/doctor.sh:146-158`

<details><summary>Original defect detail</summary>

- **Site:** `lib/doctor.sh:148`

```bash
if eval "${fix}"; then
```

`fix` is field 6 of `CHECKS_RESULTS`, populated verbatim from YAML values by `scripts/check/security.sh:29,46`, `systemd.sh:38,65,74`, `base.sh:47,72,94`. Under `sudo` with `-y`, a group name like `` wheel`;id >/tmp/p` `` executed arbitrary commands. Confirmed by reproduction — `$(...)`, backticks and `;` payloads all executed.

</details>

Fix strings are now validated by `fix_cmd_is_safe` **before** `eval`. It is an allowlist, not a blocklist:

- hard-denies `` ` ``, `;`, `<`, `>`, `$` (so **no** expansion or substitution of any kind), newlines, and bare `&`;
- requires balanced quotes, so a stray quote cannot swallow the rest of the command;
- splits on `|`, `&&`, `||` and requires every segment to start with a command in `FIX_CMD_ALLOWED_CMDS` (~55 package/service tools);
- a rejected fix is counted as a failure, reported with the offending text, and **not** executed.

All 10 legitimate remediations in the repo are still permitted; all 7 injection payloads are refused with no side effects. `scripts/check/packages.sh:130` used `$(pacman -Qdtq)`, which the validator correctly refuses — rewritten as `pacman -Qdtq | xargs -r sudo pacman -Rns --noconfirm`.

This is a real behaviour change: an unsafe fix that previously ran now does not. That is the point, but it means a config carrying metacharacters will surface as a refused remediation rather than a silent success.


### 10. `|` → `&&` rewrite in fix commands reports false success

- [x] **Fixed.** `lib/checks.sh:32-41,146-174`, `lib/doctor.sh:19-27` and its four readers

<details><summary>Original defect detail</summary>

- **Site:** `lib/checks.sh:76`

`register_check` rewrote pipes in `fix_cmd` to `&&`. `scripts/check/base.sh:94` supplies:

```
sudo locale-gen && echo 'LANG=…' | sudo tee /etc/locale.conf
```

which became `… && sudo tee …` — printing to stdout instead of writing the file. `doctor.sh:149` then reported `✔ Fix applied successfully` while the locale was unchanged.

Related: only `message/details/fix/expected/current` were `|`-sanitised — `category` and `name` were not.

</details>

Records are now delimited by `CHECK_FIELD_SEP` = ASCII Unit Separator (`$'\x1f'`), exported as a named constant. A pipe is legal data in every field — most of all in `fix_cmd`, where `a | tee file` is an ordinary pipeline — so nothing is rewritten and `fix_cmd` is stored verbatim. A stray US is still stripped defensively, now from **all 8** fields rather than 5.

**The second half was worse than the backlog recorded.** A `|` in `name` did not merely corrupt `fix`; it shifted the record so that `fix` received the **details** string. Since `doctor` passes `fix` straight to `eval` (item 9), that was a second injection path, and it survived the item-9 validator only because item 9 now also validates the *shape* of the command. Reproduced before the fix:

```
name=group_wheel        <-- truncated at the injected '|'
fix=details             <-- field shifted: was 'sudo true'
```

After the change all 8 fields round-trip exactly with pipes in each.

**Incidental fix:** `lib/doctor.sh` now sources `lib/checks.sh` itself. It needs `CHECK_FIELD_SEP`, and previously only worked because `bin/arch-postinstall` happened to source `checks.sh` first — an implicit ordering dependency that would have broken the moment `CHECK_FIELD_SEP` was introduced.

Verified: `check base --json`, `check base` and `doctor` all still work end-to-end.

### 10a. Planner records use the same `|` delimiter (found while fixing item 10)

- [ ] `lib/planner.sh:90-99` builds `PLAN_RECORDS` with `|` and sanitises all 7 fields with `${x//|/ - }`. Because *all* fields are sanitised it cannot shift the way `CHECKS_RESULTS` did, so this is display corruption only — but a package, group or service name containing `|` renders as `foo - bar` in `plan` output. Convert to `CHECK_FIELD_SEP` for consistency. Deferred to keep the item-10 diff reviewable and to avoid disturbing the 30 `test_plan.sh` assertions.



## P2 — Medium

### 11. `register_check` argument misplacement hides remediations

- [x] **Fixed.** 13 call sites across 8 check scripts, plus a new `tests/lint_check_slots.sh`

<details><summary>Original defect detail</summary>

- **Site:** `scripts/check/desktop.sh:51-52,67-68`, `scripts/check/security.sh:64-65`

Signature is `warn cat name message details fix_cmd expected current`, but these calls pass the remediation as `details`, leaving `fix_cmd` empty. `render_json` then omits `suggested_fix` and `run_doctor_fix` filters the row out entirely. The `FAIL` at `security.sh:64` (unexpected UID-0 accounts — a real security finding) is unfixable by the tool.

</details>

**The scope was more than twice what the backlog recorded.** It named 4 sites in 2 files; there were **9 misplaced remediations across 6 files** (`audio.sh` ×2, `bluetooth.sh` ×4, `desktop.sh` ×2, `systemd.sh` ×1, plus one each in `base.sh` and `security.sh` where a config-derived `${...}` string was duplicated into `details`).

A **second, more expensive** defect lived in the same slots: **prose left in `fix_cmd`** (`"Check packages providing ${svc}"`, `"Kill high-memory processes using btop/htop"`, `"Inspect /etc/passwd immediately"`). These are not commands, so the item-9 `fix_cmd_is_safe` allowlist **refuses them at runtime** — a remediation that can never fire. And `./install.sh dotfiles` was refused because `./install.sh` was not in the allowlist, so even the correctly-slotted dotfile fix would have been silently dropped.

Also fixed: `filesystem.sh` passed `expected` (`"read-write"`) into the `fix_cmd` position — a 6-arg call that skipped the fix slot entirely, so JSON reported a nonsense `suggested_fix` and the real `expected`/`current` were both lost.

**Measured effect** (probe helpers stubbed to force every WARN branch, `check bluetooth audio desktop systemd`): remediations reaching `suggested_fix` went from **1/12 to 12/12**, and all 12 now pass `fix_cmd_is_safe` — i.e. every one is a command `doctor --fix` will actually attempt.

**Guard rail added:** `tests/lint_check_slots.sh` (wired into `make lint`) statically parses every `warn`/`fail` call in `scripts/check/*.sh` and fails if a remediation sits in `details`, or if `fix_cmd` is not an allowlisted command shape. It neutralises `${...}` and command substitution before tokenising, so it never executes source text. It reports **6 details-slot + 4 fix-slot violations** against a pristine `HEAD` and is clean on the fixed tree — proven to fire, not just to pass.

### 12. Duplicated YAML parsers that must be fixed together

- [ ] `lib/common.sh:266-319` and `modules/core.sh:163-225` are near-identical copies. Fixing item 1 in only one place reintroduces the bug. Extract into a single sourced file (`lib/yaml.sh`) and have both consumers use it.

### 13. `json_escape` defects

- [ ] `lib/common.sh:327` — the `jq -s -R -r '@json'` path already strips the surrounding quotes, so the leftover `sed 's/^"//;s/"$//'` corrupts any value ending in a literal `"` (jq emits `\"`, `s/"$//` then strips the escape's quote).
- [ ] `lib/common.sh:332-336` — the `sed` fallback escapes only the **first line**: the `:a;N;$!ba` loop joins lines *after* the escape substitutions have run, so quotes/backslashes/tabs on lines 2+ are emitted raw. Move the substitutions after the join.

### 14. Idempotency claims the code does not honour

- [ ] `ARCHITECTURE.md:65` and `README.md:54` promise state-checking and safe re-runs. Violations:
  - `modules/system.sh:106` — restarts `systemd-zram-setup@zram0` on every run with no state check, discarding swapped data.
  - `modules/users.sh:86` / `:80` — `tee` **overwrites** all of `/etc/vconsole.conf` and `/etc/locale.conf`, destroying existing `FONT=`/`LC_*` entries. Also `keymap: us` is a `localectl`/X11 name, not a console keymap.
  - `modules/dotfiles.sh:71` — unconditional `find … -exec chmod +x` over 22 tracked files, permanently dirtying the git tree every run. `lib/planner.sh:300-308` already models this as `NOOP`; the executor never adopted it.
  - `modules/system.sh:137-142` — appends a **second** `[Policy]` section to `/etc/bluetooth/main.conf` when none exists.
  - `modules/system.sh:73` — `sed` only matches the commented form, so a user who already set `ParallelDownloads = 8` keeps 8 while `log_success` claims it was applied.

### 15. Service probing and dual-bus handling

- [ ] `modules/services.sh:37-51` probes the **system** bus first, so `config/hyprland.yaml:130-132` (`pipewire`, `pipewire-pulse`, `wireplumber` — all dual-scope) are enabled system-wide while `scripts/check/audio.sh` validates **user** units. The repo contradicts itself three ways (`README.md:446`, `ARCHITECTURE.md:77`, the audio checks).
- [ ] `systemctl --user enable` needs a live user manager and lingering; without `loginctl enable-linger` those units never start at boot, yet `services.sh:48` reports success regardless.
- [ ] `lib/planner.sh:211-214,218-222` appends `.service` to any name that lacks a known suffix, but `service_exists` also matches `.timer`/`.socket` — so a config entry `reflector` with only `reflector.timer` installed plans a nonexistent `reflector.service`.

### 16. Desktop gaps in `full` mode

- [ ] No display manager is ever installed or enabled (repo-wide search for `seatd|gdm|lightdm|sddm` hits only `scripts/setup_kwallet.sh:7-9`), yet `install.sh:59` tells the user to *"select Hyprland from your display manager"*.
- [ ] `xdg-desktop-portal` / `xdg-desktop-portal-hyprland` are user units declared in **neither** `services:` list, so `scripts/check/desktop.sh:86` fails permanently on a correctly installed system. Screen-share and global shortcuts are broken.
- [ ] `config/base.yaml:53` enables `reflector.timer` but no module ever writes `/etc/xdg/reflector/reflector.conf`, so the distro default (`country = Germany`) rewrites the mirrorlist on a system pinned to `Asia/Kolkata`.
- [ ] `config/base.yaml:60-67` grants `wheel` **and** `docker` silently. Docker group membership is root-equivalent, and neither the group additions nor `sshd` appear in the `install.sh:121-130` confirmation text.

### 17. Planner summary arithmetic and `--config` semantics

- [ ] `lib/planner.sh:75-81` — `SKIP` records increment `PLAN_TOTAL` but neither `changes` nor `already_satisfied`, so `changes + already_satisfied != total_operations` in the emitted JSON.
- [ ] `lib/planner.sh:650-666` — `--config X` is an **overlay**, not a replacement: `config/base.yaml` is always planned too, so `plan --config /tmp/x.yaml` emits records for both. This contradicts `bin:101` (*"Custom configuration file path"*) and is what makes the dotfile test see 60 operations for a 3-entry config. A `dotfiles:` list in `base.yaml` is also never planned.
- [ ] `lib/planner.sh:487-488` — `plan_discover_profile`'s second parameter is dead; any `-p` other than `hyprland` yields an empty profile section.

### 18. CLI argument handling gaps

- [ ] `bin:262-276` — categories are not de-duplicated; `check base base` double-counts every result in the summary and JSON.
- [ ] `bin:191-194` — `arch-postinstall doctor fix` appends `fix` to `CATEGORIES` instead of enabling remediation; `fix` is only honoured as the first token.
- [ ] `bin:248-255` — `handle_list` ignores `CATEGORIES`; `list bogus` exits 0 instead of the documented 3.
- [ ] `bin:236` — `arch-postinstall install bogus` exits 1 from `install.sh:77` rather than 3.
- [ ] `bin:33-38` — an unchecked `*.sh` glob; a missing `scripts/check/` silently yields 0 checks and exit 0 instead of the documented 4.
- [ ] `lib/checks.sh:161-162` — `||` binds to the whole pipeline, so the `pacman -Qm` fallback never runs (`awk` exits 0 on empty input); AUR packages report as `Installed ()`.

### 19. Desktop layer — missing glassmorphism alacritty theme

- [ ] `dotfiles/alacritty/themes/` has no `glassmorphism-{dark,light}.toml`, so the active scheme falls back to `dark.toml`, which is **Catppuccin Mocha** (`#1e1e2e`/`#cdd6f4`) while kitty, waybar, rofi and hypr are glassmorphism. Add both files.

### 20. Documentation drift

- [ ] `ARCHITECTURE.md:155` — duplicate `## 4.` heading (two sections numbered 4).
- [ ] `ARCHITECTURE.md:141` — claims 14 Lua presets; 16 exist.
- [ ] `ARCHITECTURE.md` lists 7 theme schemes; 8 families (16 variants) ship.
- [ ] `yq` — the tool that decides whether the engine works — is documented as a dependency **nowhere** in `README.md`, `ARCHITECTURE.md`, `docs/`, or `CONTRIBUTING.md`, and `Makefile:70` lists it only as a soft prereq check.

---

## Regression tests to add

Every P0/P1 bug above is cheap to test for. Adding these fixtures would have caught all of them.

- [ ] **No-`yq` fixture** — run `make test` with `yq` absent from `PATH` and assert the package/group lists are non-empty. Currently CI (`.github/workflows/lint.yml:15`) installs only `jq`, so CI *is* exercising the broken path — this is likely why the suite is not actually green in CI today.
- [ ] **Regular-file dotfile** — create `~/.config/<app>` as a file, deploy, assert the file was backed up and is recoverable.
- [ ] **Pristine `pacman.conf`** — assert `plan` reports pacman tuning as `CHANGE`, not `NOOP`.
- [ ] **Doctor-fix failure** — point a fix at a command that fails, assert the CLI exits non-zero.
- [ ] **`plan --no-color`** — assert it terminates and exits 0. (Note: this is **not** currently broken; see below. It is only cheap insurance.)
- [ ] **Summary arithmetic** — assert `changes + already_satisfied + skipped == total_operations`.
- [ ] **JSON escaping** — feed multi-line strings with quotes, backslashes and tabs through `json_escape` and `jq`-validate the result.

---

## Investigated and found **not** to be bugs

Recorded so they are not re-investigated. All three were initially plausible and were disproven by direct testing.

- [x] ~~`run_cmd` invokes shell functions via `"$@"`~~ — **not a bug.** Bash command lookup resolves functions before `PATH`, so `run_cmd tune_pacman` works correctly. Verified by execution.
- [x] ~~`plan --no-color` hangs forever~~ — **not a bug.** It appeared to hang (15s timeout, zero output) but that was CPU contention from concurrent background jobs. On an idle machine it completes in ~4.07s. The test suite is not hanging either; it is genuinely slow (15 `plan` invocations × ~4s ≈ 3m33s).
- [x] ~~`planner.sh:393-396` pacman tuning check matches commented-out defaults~~ — **not a bug.** `^Color`, `^ParallelDownloads` and `^VerbosePkgLists` correctly reject `#Color`, `#ParallelDownloads = 5`, `#VerbosePkgLists`. Tested against a pristine stock `pacman.conf`: `pacman_ok=false`, correctly reporting that tuning is needed. Only `ILoveCandy` lacks its `^` anchor, which is harmless because the other three checks still fail.

---

## Performance

- [ ] The test suite takes **3m33s** because `tests/test_plan.sh` shells out to `plan` 15 times and each invocation re-does full system discovery. Add a `--cache`/`--fast` mode to the planner, or restructure the planner to take its state snapshot once and be called repeatedly in-process from the test. Nothing here is a hang — it is only too slow to run casually.
- [ ] `plan` shells out per package/service (`pacman -Qi`, `systemctl is-enabled`, …). Batching into a single `pacman -Q` / `systemctl list-unit-files` call would cut runtime substantially on systems with large package sets.
