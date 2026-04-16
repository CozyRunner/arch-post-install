.PHONY: help install full base dotfiles packages fonts fish lint clean check

help: ## Show this help
	@echo ""
	@echo "  Arch Post-Install Makefile (Hyprland)"
	@echo "  ─────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Flags:"
	@echo "    V=1              Enable verbose mode"
	@echo "    DRY=1            Dry-run mode (preview only)"
	@echo ""
	@echo "  Examples:"
	@echo "    make full V=1    Verbose full install"
	@echo "    make dotfiles DRY=1  Preview dotfiles deployment"

install: ## Run interactive installer
	@chmod +x install.sh
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,)

full: ## Full install (base + Hyprland + dotfiles)
	@chmod +x install.sh
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) full

base: ## Install base packages only (no DE)
	@chmod +x install.sh
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) base

dotfiles: ## Deploy dotfiles only
	@chmod +x install.sh
	@bash install.sh $(if $(V),-v,) $(if $(DRY),-d,) dotfiles

packages: ## Install Hyprland packages only
	@bash -c 'source modules/core.sh && source modules/packages.sh && install_packages_from_config config/hyprland.yaml'

fonts: ## Install fonts
	@chmod +x scripts/fonts.sh
	@bash scripts/fonts.sh

fish: ## Setup Fish + Fisher
	@chmod +x scripts/setup_fish.sh
	@bash scripts/setup_fish.sh

check: ## Check for missing dependencies
	@echo "Checking required commands..."
	@for cmd in sudo pacman git curl; do \
		if command -v $$cmd &>/dev/null; then \
			echo "  [OK] $$cmd"; \
		else \
			echo "  [MISSING] $$cmd"; \
		fi \
	done
	@echo "Done."

lint: ## Lint all shell scripts with shellcheck
	@echo "Running shellcheck..."
	@shellcheck install.sh modules/*.sh scripts/*.sh 2>/dev/null || echo "shellcheck not installed. Install with: sudo pacman -S shellcheck"
	@echo "Done."

clean: ## Remove logs
	@rm -rf logs/*
	@echo "Logs cleared."
