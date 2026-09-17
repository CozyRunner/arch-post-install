.PHONY: help install full base dotfiles packages fonts fish flatpak lint clean check health doctor fix status plan test restore prereq zram btrfs firewall

help: ## Show this help
	@echo ""
	@echo "  Arch Post-Install Workbench & System-Health Engine"
	@echo "  ──────────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Flags:"
	@echo "    V=1              Enable verbose mode"
	@echo "    JSON=1           Enable JSON output format"
	@echo "    DRY=1            Dry-run mode (preview only)"
	@echo ""
	@echo "  Examples:"
	@echo "    make check       Run declarative post-install validation"
	@echo "    make health      Run runtime system-health checks"
	@echo "    make doctor      Run diagnostic intelligence engine"
	@echo "    make fix         Interactively apply diagnostic remediations"
	@echo "    make status      Run full system status scorecard"
	@echo "    make test        Execute automated test suite"
	@echo "    make full V=1    Verbose full install"

install: ## Run interactive installer
	@chmod +x install.sh bin/arch-postinstall
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,)

full: ## Full install (base + Hyprland + dotfiles + optimizations)
	@chmod +x install.sh bin/arch-postinstall
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) full

base: ## Install base packages only (no DE)
	@chmod +x install.sh bin/arch-postinstall
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) base

dotfiles: ## Deploy dotfiles only
	@chmod +x install.sh bin/arch-postinstall
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) dotfiles

check: ## Run post-installation declarative configuration validation
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall check $(if $(V),-v,) $(if $(JSON),--json,)

health: ## Run runtime system-health and service daemon checks
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall health $(if $(V),-v,) $(if $(JSON),--json,)

doctor: ## Diagnose system issues and display suggested remediation commands
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall doctor $(if $(V),-v,) $(if $(JSON),--json,)

fix: ## Interactively apply suggested remediation commands from doctor
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall fix $(if $(V),-v,)

status: ## Run full status dashboard (configuration validation + runtime health)
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall status $(if $(V),-v,) $(if $(JSON),--json,)

plan: ## Generate dry-run execution plan without modifying system state
	@chmod +x bin/arch-postinstall
	@./bin/arch-postinstall plan $(if $(V),-v,) $(if $(JSON),--json,) $(if $(PROFILE),--profile $(PROFILE),) $(if $(CONFIG),--config $(CONFIG),)

test: ## Execute complete test suite
	@chmod +x tests/test_runner.sh tests/*.sh
	@bash tests/test_runner.sh

prereq: ## Check for missing prerequisites
	@echo "Checking required commands..."
	@for cmd in sudo pacman git curl yq; do \
		if command -v $$cmd &>/dev/null; then \
			echo "  [OK] $$cmd"; \
		else \
			echo "  [MISSING] $$cmd"; \
		fi \
	done
	@echo "Done."

zram: ## Setup ZRAM swap
	@bash -c 'source modules/core.sh && source modules/system.sh && setup_zram'

btrfs: ## Setup Btrfs Snapper automated snapshots
	@bash -c 'source modules/core.sh && source modules/btrfs.sh && setup_btrfs_snapshots'

firewall: ## Setup UFW firewall
	@bash -c 'source modules/core.sh && source modules/system.sh && setup_firewall'

packages: ## Install Hyprland packages only
	@bash -c 'source modules/core.sh && source modules/packages.sh && install_packages_from_config config/hyprland.yaml'

fonts: ## Install fonts
	@chmod +x scripts/fonts.sh
	@bash scripts/fonts.sh

fish: ## Setup Fish + Fisher
	@chmod +x scripts/setup_fish.sh
	@bash scripts/setup_fish.sh

lint: ## Lint all shell scripts with shellcheck
	@echo "Running shellcheck..."
	@shellcheck bin/arch-postinstall lib/*.sh scripts/check/*.sh tests/*.sh install.sh modules/*.sh scripts/*.sh 2>/dev/null || echo "shellcheck not installed. Install with: sudo pacman -S shellcheck"
	@echo "Done."

flatpak: ## Install Flatpak and Flathub apps
	@bash -c 'source modules/core.sh && source modules/flatpak.sh && setup_flatpak'

restore: ## Restore configs from latest backup
	@echo "Looking for backups in ~/.config-backup-*..."
	@latest=$$(ls -dt ~/.config-backup-* 2>/dev/null | head -1); \
	if [ -z "$$latest" ]; then \
		echo "  No backups found."; \
		exit 1; \
	fi; \
	echo "  Found: $$latest"; \
	echo "  Contents:"; ls "$$latest"; \
	echo ""; \
	read -rp "  Restore all configs from this backup? [y/N]: " yn; \
	case "$$yn" in \
		[Yy]*) \
			for dir in "$$latest"/*/; do \
				name=$$(basename "$$dir"); \
				dest="$$HOME/.config/$$name"; \
				if [ -L "$$dest" ]; then \
					rm "$$dest"; \
				elif [ -d "$$dest" ]; then \
					mv "$$dest" "$${dest}.overridden-$$(date +%s)"; \
				fi; \
				cp -r "$$dir" "$$dest"; \
				echo "  Restored: $$name"; \
			done; \
			echo "  Done. Log out and back in to apply.";; \
		*) \
			echo "  Aborted.";; \
	esac

clean: ## Remove logs
	@rm -rf logs/*
	@echo "Logs cleared."
