# Makefile for the qemu-spice Homebrew tap.
#
# This tap ships a single formula: homebrew-core's `qemu` with SPICE enabled.
# See scripts/sync-check.sh for how we stay current with core.

.PHONY: help sync-check style audit install reinstall uninstall test verify \
        status deps doctor clean tap-add tap-remove

.DEFAULT_GOAL := help

BLUE  := \033[0;34m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RED   := \033[0;31m
NC    := \033[0m

TAP     := stuffbucket/qemu-spice
FORMULA := $(TAP)/qemu-spice

help: ## Show this help
	@echo "$(BLUE)qemu-spice tap$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-14s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Tap:$(NC) $(TAP)   $(YELLOW)Cache:$(NC) $$(brew --cache)"

sync-check: ## Diff our formula against homebrew-core's qemu (drift report)
	@bash scripts/sync-check.sh

style: ## Run brew style
	@brew style Formula/qemu-spice.rb
	@echo "$(GREEN)✓ style clean$(NC)"

audit: style ## Run brew style + strict audit
	@brew audit --strict $(FORMULA) && echo "$(GREEN)✓ audit clean$(NC)"

install: ## Build and install qemu-spice from source (~10-20 min)
	@echo "$(BLUE)=== Building qemu-spice ===$(NC)"
	@echo "$(YELLOW)Conflicts with core qemu; run 'brew unlink qemu' first if needed.$(NC)"
	@START=$$(date +%s); \
	brew install --build-from-source $(FORMULA) && \
	D=$$(( $$(date +%s) - START )) && \
	echo "$(GREEN)✓ built in $$((D / 60))m $$((D % 60))s$(NC)"

reinstall: ## Force a rebuild from source
	@brew reinstall --build-from-source $(FORMULA)

uninstall: ## Uninstall qemu-spice
	@brew uninstall qemu-spice && echo "$(GREEN)✓ uninstalled$(NC)"
	@echo "$(YELLOW)Run 'brew link qemu' to restore core qemu, and 'brew autoremove'"
	@echo "to drop spice-server/usbredir if nothing else needs them.$(NC)"

test: ## Run the formula test block plus SPICE smoke checks
	@brew test $(FORMULA)
	@echo ""
	@echo "$(BLUE)=== SPICE smoke test ===$(NC)"
	@qemu-system-aarch64 --version | head -1
	@qemu-system-aarch64 -spice help 2>&1 | grep -q "spice options:" && \
		echo "$(GREEN)✓ -spice accepted (SPICE compiled in)$(NC)" || \
		(echo "$(RED)✗ -spice rejected — this build has no SPICE$(NC)" && exit 1)
	@qemu-system-aarch64 -accel help | grep -q hvf && \
		echo "$(GREEN)✓ HVF available$(NC)" || \
		(echo "$(RED)✗ HVF missing$(NC)" && exit 1)

verify: ## Run the full verification script
	@bash scripts/verify-installation.sh

status: ## Show what is installed and linked
	@echo "$(BLUE)=== Status ===$(NC)"
	@brew list --versions qemu-spice qemu spice-server usbredir 2>/dev/null || true
	@echo ""
	@for c in qemu-system-aarch64 qemu-system-x86_64 qemu-img; do \
		if command -v $$c >/dev/null 2>&1; then \
			echo "  $(GREEN)✓$(NC) $$c → $$(readlink -f $$(command -v $$c) 2>/dev/null || command -v $$c)"; \
		else \
			echo "  $(RED)✗$(NC) $$c not found"; \
		fi; \
	done

deps: ## Show the dependency tree
	@brew deps --tree $(FORMULA)

doctor: ## Run brew doctor
	@brew doctor || true

clean: ## Remove old versions and cached downloads
	@brew cleanup qemu-spice 2>/dev/null || true
	@echo "$(GREEN)✓ cleaned$(NC)"

tap-add: ## Add this tap
	@brew tap $(TAP) && echo "$(GREEN)✓ tapped$(NC)"

tap-remove: ## Remove this tap
	@brew untap $(TAP) 2>/dev/null || true
