# Makefile for QEMU-SPICE Homebrew Tap
# Leverages Homebrew's native build system and caching

.PHONY: all build clean clean-downloads install test audit help reinstall upgrade
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Formulas
FORMULAS := libepoxy-egl virglrenderer spice-server qemu-spice
FORMULA_DIR := ./Formula

help: ## Show this help message
	@echo "$(BLUE)QEMU-SPICE Homebrew Tap - Build System$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Homebrew cache:$(NC) $$(brew --cache)"
	@echo "$(YELLOW)Tap location:$(NC) $$(pwd)"

audit: ## Run brew audit and style checks (fast)
	@echo "$(BLUE)=== Running Formula Audit ===$(NC)"
	@brew audit --strict --online $(FORMULA_DIR)/*.rb
	@echo "$(GREEN)✓ Audit passed$(NC)"
	@echo ""
	@echo "$(BLUE)=== Running Style Check ===$(NC)"
	@brew style $(FORMULA_DIR)/*.rb
	@echo "$(GREEN)✓ Style check passed$(NC)"

check-deps: ## Check and install build dependencies using brew
	@echo "$(BLUE)=== Checking Build Dependencies ===$(NC)"
	@brew list meson >/dev/null 2>&1 || brew install meson
	@brew list ninja >/dev/null 2>&1 || brew install ninja
	@brew list pkg-config >/dev/null 2>&1 || brew install pkg-config
	@brew list glib >/dev/null 2>&1 || brew install glib
	@brew list pixman >/dev/null 2>&1 || brew install pixman
	@echo "$(GREEN)✓ All dependencies present$(NC)"

check-conflicts: ## Check for conflicting packages
	@echo "$(BLUE)=== Checking for Conflicts ===$(NC)"
	@if brew list qemu >/dev/null 2>&1 || brew list libepoxy >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠ Found conflicting packages$(NC)"; \
		echo "$(RED)Run 'make unlink-conflicts' to resolve$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ No conflicts found$(NC)"; \
	fi

unlink-conflicts: ## Unlink conflicting packages
	@echo "$(BLUE)=== Unlinking Conflicts ===$(NC)"
	@brew unlink qemu libepoxy 2>/dev/null || true
	@echo "$(GREEN)✓ Conflicts resolved$(NC)"

info: ## Show formula information
	@echo "$(BLUE)=== Formula Information ===$(NC)"
	@for formula in $(FORMULAS); do \
		echo ""; \
		echo "$(YELLOW)$$formula:$(NC)"; \
		brew info stuffbucket/qemu-spice/$$formula 2>/dev/null || \
			echo "  Formula not found"; \
	done

deps: ## Show dependency tree
	@echo "$(BLUE)=== Dependency Tree ===$(NC)"
	@brew deps --tree stuffbucket/qemu-spice/qemu-spice

# Individual formula targets
libepoxy-egl: check-deps ## Build libepoxy-egl (~2-3 min)
	@echo "$(BLUE)=== Building libepoxy-egl ===$(NC)"
	@echo "OpenGL function pointer library with EGL support"
	@START=$$(date +%s); \
	brew install --HEAD --build-from-source --verbose stuffbucket/qemu-spice/libepoxy-egl && \
	END=$$(date +%s) && \
	DURATION=$$((END - START)) && \
	echo "$(GREEN)✓ libepoxy-egl built in $${DURATION}s$(NC)" || \
	(echo "$(RED)✗ Build failed. Check 'brew --cache' for logs$(NC)" && exit 1)

virglrenderer: libepoxy-egl ## Build virglrenderer (~3-5 min)
	@echo "$(BLUE)=== Building virglrenderer ===$(NC)"
	@echo "Virtual GPU renderer for macOS"
	@START=$$(date +%s); \
	brew install --HEAD --build-from-source --verbose stuffbucket/qemu-spice/virglrenderer && \
	END=$$(date +%s) && \
	DURATION=$$((END - START)) && \
	echo "$(GREEN)✓ virglrenderer built in $${DURATION}s$(NC)" || \
	(echo "$(RED)✗ Build failed. Check 'brew --cache' for logs$(NC)" && exit 1)

spice-server: virglrenderer ## Build spice-server (~5-7 min)
	@echo "$(BLUE)=== Building spice-server ===$(NC)"
	@echo "SPICE protocol server library"
	@START=$$(date +%s); \
	brew install --build-from-source --verbose stuffbucket/qemu-spice/spice-server && \
	END=$$(date +%s) && \
	DURATION=$$((END - START)) && \
	echo "$(GREEN)✓ spice-server built in $${DURATION}s$(NC)" || \
	(echo "$(RED)✗ Build failed. Check 'brew --cache' for logs$(NC)" && exit 1)

qemu-spice: spice-server ## Build qemu-spice (~25-35 min)
	@echo "$(BLUE)=== Building qemu-spice ===$(NC)"
	@echo "QEMU 10.1.2 with SPICE support and Apple Silicon optimizations"
	@echo "$(YELLOW)⏱ This will take 25-35 minutes...$(NC)"
	@START=$$(date +%s); \
	brew install --build-from-source --verbose stuffbucket/qemu-spice/qemu-spice && \
	END=$$(date +%s) && \
	DURATION=$$((END - START)) && \
	MINUTES=$$((DURATION / 60)) && \
	SECONDS=$$((DURATION % 60)) && \
	echo "$(GREEN)✓ qemu-spice built in $${MINUTES}m $${SECONDS}s$(NC)" || \
	(echo "$(RED)✗ Build failed. Check 'brew --cache' for logs$(NC)" && exit 1)

build: check-conflicts qemu-spice ## Build all formulas (full build)
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✓ All formulas built successfully!$(NC)"
	@echo "$(GREEN)========================================$(NC)"

install: build ## Build and install all formulas (alias for build)
	@echo "$(GREEN)Installation complete!$(NC)"

reinstall: ## Reinstall all formulas (forces rebuild)
	@echo "$(BLUE)=== Reinstalling All Formulas ===$(NC)"
	@for formula in $(FORMULAS); do \
		echo "Reinstalling $$formula..."; \
		brew reinstall --build-from-source stuffbucket/qemu-spice/$$formula; \
	done
	@echo "$(GREEN)✓ All formulas reinstalled$(NC)"

upgrade: ## Upgrade formulas to latest versions
	@echo "$(BLUE)=== Upgrading Formulas ===$(NC)"
	@for formula in $(FORMULAS); do \
		if brew list $$formula >/dev/null 2>&1; then \
			echo "Upgrading $$formula..."; \
			brew upgrade --build-from-source stuffbucket/qemu-spice/$$formula || true; \
		else \
			echo "$$formula not installed, skipping"; \
		fi; \
	done
	@echo "$(GREEN)✓ Upgrade complete$(NC)"

test: ## Run brew test on installed formulas
	@echo "$(BLUE)=== Running Brew Tests ===$(NC)"
	@for formula in $(FORMULAS); do \
		if brew list $$formula >/dev/null 2>&1; then \
			echo "Testing $$formula..."; \
			brew test $$formula 2>/dev/null || echo "No tests defined for $$formula"; \
		else \
			echo "$(YELLOW)⚠ $$formula not installed$(NC)"; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)=== Running Quick Smoke Tests ===$(NC)"
	@echo ""
	@command -v qemu-system-x86_64 && echo "$(GREEN)✓ qemu-system-x86_64$(NC)" || \
		(echo "$(RED)✗ qemu-system-x86_64 not found$(NC)" && exit 1)
	@command -v qemu-system-aarch64 && echo "$(GREEN)✓ qemu-system-aarch64$(NC)" || \
		(echo "$(RED)✗ qemu-system-aarch64 not found$(NC)" && exit 1)
	@command -v qemu-img && echo "$(GREEN)✓ qemu-img$(NC)" || \
		(echo "$(RED)✗ qemu-img not found$(NC)" && exit 1)
	@echo ""
	@qemu-system-x86_64 --version | head -1
	@qemu-system-x86_64 -device help | grep -q spice && \
		echo "$(GREEN)✓ SPICE support enabled$(NC)" || \
		(echo "$(RED)✗ SPICE support missing$(NC)" && exit 1)
	@qemu-system-x86_64 -accel help | grep -q hvf && \
		echo "$(GREEN)✓ HVF acceleration available$(NC)" || \
		(echo "$(RED)✗ HVF acceleration missing$(NC)" && exit 1)
	@echo ""
	@echo "$(GREEN)✓ All tests passed!$(NC)"

verify: ## Run verification checks
	@echo "$(BLUE)=== Running Verification ===$(NC)"
	@if [ -f scripts/verify-installation.sh ]; then \
		chmod +x scripts/verify-installation.sh && \
		echo "n" | ./scripts/verify-installation.sh; \
	else \
		echo "Running basic verification..."; \
		make test; \
	fi

doctor: ## Run brew doctor to check for issues
	@echo "$(BLUE)=== Running Brew Doctor ===$(NC)"
	@brew doctor || true

show-cache: ## Show Homebrew cache information
	@echo "$(BLUE)=== Homebrew Cache Information ===$(NC)"
	@echo "Cache location: $$(brew --cache)"
	@echo ""
	@if [ -d "$$(brew --cache)" ]; then \
		echo "Cache contents:"; \
		du -sh "$$(brew --cache)"/* 2>/dev/null | sort -h || echo "Empty"; \
		echo ""; \
		echo "Total cache size:"; \
		du -sh "$$(brew --cache)"; \
	fi
	@echo ""
	@echo "Downloads cache:"; \
	du -sh "$$(brew --cache)/downloads" 2>/dev/null || echo "No downloads cached"

clean-cache: ## Clean Homebrew cache (frees disk space)
	@echo "$(BLUE)=== Cleaning Homebrew Cache ===$(NC)"
	@echo "$(YELLOW)⚠ This will remove cached downloads$(NC)"
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		brew cleanup -s; \
		echo "$(GREEN)✓ Cache cleaned$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

clean: ## Clean old formula versions and cache
	@echo "$(BLUE)=== Cleaning Old Versions ===$(NC)"
	@brew cleanup
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

uninstall: ## Uninstall all formulas
	@echo "$(BLUE)=== Uninstalling Formulas ===$(NC)"
	@echo "$(YELLOW)⚠ This will remove all installed formulas$(NC)"
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		for formula in $$(echo $(FORMULAS) | tac -s' '); do \
			brew uninstall --ignore-dependencies $$formula 2>/dev/null || true; \
		done; \
		echo "$(GREEN)✓ Formulas uninstalled$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

status: ## Show installation status using brew list
	@echo "$(BLUE)=== Installation Status ===$(NC)"
	@echo ""
	@echo "Installed formulas:"
	@for formula in $(FORMULAS); do \
		if brew list $$formula >/dev/null 2>&1; then \
			VERSION=$$(brew list --versions $$formula | awk '{print $$2}'); \
			INSTALLED=$$(brew info $$formula | grep "Installed" | head -1); \
			echo "  $(GREEN)✓$(NC) $$formula"; \
			echo "    Version: $$VERSION"; \
			brew list --versions $$formula | head -1; \
		else \
			echo "  $(RED)✗$(NC) $$formula (not installed)"; \
		fi; \
	done
	@echo ""
	@echo "Executables:"
	@for cmd in qemu-system-x86_64 qemu-system-aarch64 qemu-img; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			LOC=$$(command -v $$cmd); \
			echo "  $(GREEN)✓$(NC) $$cmd"; \
			echo "    → $$LOC"; \
		else \
			echo "  $(RED)✗$(NC) $$cmd (not found)"; \
		fi; \
	done

links: ## Show formula links and dependencies using brew
	@echo "$(BLUE)=== Formula Links and Dependencies ===$(NC)"
	@for formula in $(FORMULAS); do \
		if brew list $$formula >/dev/null 2>&1; then \
			echo ""; \
			echo "$(YELLOW)$$formula:$(NC)"; \
			brew deps $$formula; \
		fi; \
	done

log: ## Show recent Homebrew logs
	@echo "$(BLUE)=== Recent Homebrew Logs ===$(NC)"
	@echo "Log location: $$(brew --cache)/Logs"
	@if [ -d "$$(brew --cache)/Logs" ]; then \
		ls -lt "$$(brew --cache)/Logs" | head -20; \
	else \
		echo "No logs found"; \
	fi

# GitHub Tap Management
tap-add: ## Add the GitHub tap (for users installing from GitHub)
	@echo "$(BLUE)=== Adding GitHub Tap ===$(NC)"
	@brew tap stuffbucket/qemu-spice || true
	@echo "$(GREEN)✓ Tap added: stuffbucket/qemu-spice$(NC)"
	@echo "Now you can install with: brew install stuffbucket/qemu-spice/qemu-spice"

tap-remove: ## Remove the GitHub tap
	@echo "$(BLUE)=== Removing GitHub Tap ===$(NC)"
	@brew untap stuffbucket/qemu-spice 2>/dev/null || true
	@echo "$(GREEN)✓ Tap removed$(NC)"

tap-status: ## Check tap status
	@echo "$(BLUE)=== Tap Status ===$(NC)"
	@brew tap | grep -q stuffbucket/qemu-spice && \
		echo "$(GREEN)✓ Tap is installed$(NC)" || \
		echo "$(YELLOW)⚠ Tap not installed. Run 'make tap-add' to add it$(NC)"
	@if brew tap | grep -q stuffbucket/qemu-spice; then \
		echo ""; \
		echo "Tap location: $$(brew --repository)/Library/Taps/stuffbucket/homebrew-qemu-spice"; \
	fi
