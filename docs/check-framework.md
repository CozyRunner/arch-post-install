# Arch Post-Installation Validation & System-Health Framework

A declarative, modular, and read-only validation and diagnostics subsystem for the **Arch Linux Post-Installation Workbench**.

---

## 1. Overview & Architectural Lifecycle

The repository provides a complete lifecycle from bare metal to a verified workstation:

```mermaid
graph LR
    A[1. Install] --> B[2. Configure]
    B --> C[3. Validate / Check]
    C --> D[4. System Health]
    D --> E[5. Diagnose / Doctor]
    E --> F[6. Suggested Fixes]
```

### Core Tenets
- **Declarative Conformance (`check`)**: Validates that installed packages, systemd units, dotfiles, user permissions, and boot configs match declarations in `config/base.yaml`, `config/hyprland.yaml`, and active profiles.
- **Runtime Health (`health`)**: Inspects live system performance, failed systemd units, filesystem utilization, DNS/network routing, memory pressure, and hardware status.
- **Root-Cause Diagnostics (`doctor`)**: Translates `WARN` and `FAIL` findings into clear state comparisons (`Expected` vs `Current`), diagnostic details, and actionable copy-paste remediation commands.
- **Read-Only Safety**: All check, health, doctor, and status commands are strictly non-destructive.
- **Non-Root Friendly**: Can be executed by regular unprivileged users without requiring mandatory `sudo`.

---

## 2. Directory Structure

```
arch-post-install/
├── bin/
│   └── arch-postinstall       # Unified CLI entry point
├── lib/
│   ├── common.sh              # System introspection, YAML parser fallbacks, privilege checks
│   ├── output.sh              # Terminal formatting, TTY detection, scorecards, headers
│   ├── checks.sh              # Check accumulator, assertions API, JSON serializer
│   └── doctor.sh              # Diagnostic analysis and remediation generator
├── scripts/
│   └── check/                 # Category validation & health check modules
│       ├── base.sh            # OS release, hostname, timezone, locale, microcode, kernel
│       ├── boot.sh            # UEFI/BIOS mode, ESP partition, bootloader, initramfs sync
│       ├── packages.sh        # Pacman DB lock, YAML package conformance, orphans, updates
│       ├── systemd.sh         # Systemd state, failed units, declarative services, user units
│       ├── filesystem.sh      # Mountpoints, disk capacity %, inode %, read-only checks, SMART
│       ├── network.sh         # Interfaces, IP assignment, default gateway, DNS, connectivity
│       ├── time.sh            # Clock synchronization, timezone conformance, NTP daemons
│       ├── security.sh        # User accounts, wheel group, UID 0 accounts, SSH posture, firewall
│       ├── hardware.sh        # CPU topology, RAM & swap utilization, GPU controllers
│       ├── desktop.sh         # Hyprland configuration, Wayland session, portals, dotfiles
│       ├── audio.sh           # PipeWire stack, wireplumber, user audio units, sound sinks
│       ├── bluetooth.sh       # Controller detection, bluez daemon, rfkill block state
│       ├── power.sh           # Chassis detection, battery health, power profiles, thermals
│       └── maintenance.sh     # Package updates, orphan hygiene, journal size, timers, mirrors
├── config/
│   ├── base.yaml              # Core declarative package and system specification
│   ├── hyprland.yaml          # Desktop profile declarative specification
│   └── checks.conf            # Check thresholds, timeouts, and override rules
└── tests/
    ├── test_runner.sh         # Master test harness
    ├── test_framework.sh      # Core assertion and state unit tests
    ├── test_cli.sh            # CLI argument and exit code tests
    ├── test_json.sh           # JSON schema and ANSI compliance tests
    └── test_categories.sh     # Mocked assertion category tests
```

---

## 3. CLI Usage & Commands

```bash
# Run full post-installation configuration validation
./bin/arch-postinstall check

# Run specific validation categories
./bin/arch-postinstall check boot network security

# Run live runtime health checks
./bin/arch-postinstall health

# Run diagnostic doctor (analyzes failures with suggested fixes)
./bin/arch-postinstall doctor

# Run combined status dashboard
./bin/arch-postinstall status

# Output clean, parseable JSON
./bin/arch-postinstall status --json

# List available check categories
./bin/arch-postinstall list categories
```

### CLI Flags

| Flag | Long Flag | Description |
|---|---|---|
| `-j` | `--json` | Output results in valid, ANSI-free JSON schema |
| `-v` | `--verbose` | Show verbose diagnostics for all checks |
| `-q` | `--quiet` | Suppress PASS/SKIP output (show only WARN and FAIL) |
| `-n` | `--no-color` | Disable ANSI color sequences (respects `NO_COLOR`) |
| `-p` | `--profile` | Specify target profile (e.g. `--profile hyprland`) |
| `-c` | `--config` | Custom configuration file override |
| `-V` | `--version` | Display version information |
| `-h` | `--help` | Display CLI help menu |

---

## 4. Status Model & Exit Codes

### Status Levels

- `PASS`: Configuration matches expectations or health probe is normal.
- `WARN`: Suboptimal posture, non-critical package updates, or optional feature absent.
- `FAIL`: Configuration mismatch or critical runtime failure.
- `SKIP`: Feature not configured in YAML or hardware not present.
- `INFO`: Informational environment context (e.g. container detection, hardware model).

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | All checks passed or skipped |
| `1` | One or more warnings detected (zero failures) |
| `2` | One or more check failures |
| `3` | Invalid command-line argument or syntax error |
| `4` | Missing core system dependency or framework error |

---

## 5. Writing a New Check Module

To add a new validation category (e.g. `docker` or `virtualization`), create a script in `scripts/check/<category>.sh`:

```bash
#!/usr/bin/env bash

check_docker() {
    print_category_header "Docker Subsystem Configuration"

    # Verify binary presence
    if package_installed "docker"; then
        pass "docker" "pkg_docker" "Docker package is installed"
    else
        warn "docker" "pkg_docker" "Docker package is not installed" \
             "Install docker package" "sudo pacman -S docker"
    fi

    # Verify service enablement
    assert_service_enabled "docker" "docker"
}

health_docker() {
    print_category_header "Docker Runtime Health"

    if service_active "docker"; then
        pass "docker" "daemon_active" "Docker daemon is running"
    else
        warn "docker" "daemon_active" "Docker daemon is inactive" \
             "Start daemon: sudo systemctl start docker"
    fi
}
```

Register the category name in `bin/arch-postinstall` in the `ALL_CATEGORIES` array.

---

## 6. Assertion API Reference

The framework provides standardized helper functions in `lib/checks.sh`:

- `pass(category, check_name, message, [details])`
- `warn(category, check_name, message, [details], [suggested_fix], [expected], [current])`
- `fail(category, check_name, message, [details], [suggested_fix], [expected], [current])`
- `skip(category, check_name, message, [details])`
- `info(category, check_name, message, [details])`
- `assert_package_installed(pkg_name, [category])`
- `assert_aur_package_installed(pkg_name, [category])`
- `assert_service_enabled(service_name, [category])`
- `assert_service_active(service_name, [category])`
- `assert_mount(mountpoint, [category])`
- `assert_user_group(username, group_name, [category])`
