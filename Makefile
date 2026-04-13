.PHONY: help install full base dotfiles packages fonts fish lint clean

help: ## Show this help
	@echo ""
	@echo "  Arch Post-Install Makefile (Hyprland)"
	@echo "  ─────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

install: ## Run interactive installer
	@chmod +x install.sh
	@bash install.sh

full: ## Full install (base + Hyprland + dotfiles)
	@chmod +x install.sh
	@bash install.sh full

base: ## Install base packages only (no DE)
	@chmod +x install.sh
	@bash install.sh base

dotfiles: ## Deploy dotfiles only
	@chmod +x install.sh
	@bash install.sh dotfiles

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
	@shellcheck install.sh modules/*.sh scripts/*.sh || true
	@echo "Done."

clean: ## Remove logs
	@rm -rf logs/*
	@echo "Logs cleared."
