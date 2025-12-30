#!/usr/bin/env bash
# rebuild-smart.sh - Smart NixOS rebuild automation
#
# This script orchestrates a complete NixOS rebuild workflow:
#   1. Preparation - Check prerequisites, record state for rollback
#   2. Upstream Sync - Fetch and rebase upstream changes (jj preferred)
#   3. Dotfiles Sync - Sync chezmoi dotfiles with remote
#   4. Nix-Secrets Update - Pull and update nix-secrets flake input
#   5. Flake Update - Update all flake inputs (optional)
#   6. NixOS Rebuild - Run nh os switch
#   7. Post-Rebuild Checks - Verify system health
#   8. Commit & Push - Auto-commit successful builds
#
# Features:
#   - Conflict-free merging via jujutsu (jj)
#   - Graceful degradation in offline mode
#   - Automatic rollback on rebuild failure
#   - Clear progress indicators
#
# Usage:
#   ./scripts/rebuild-smart.sh [OPTIONS]
#
# Options:
#   --skip-upstream   Skip upstream sync (use local state only)
#   --skip-dotfiles   Skip chezmoi dotfiles sync
#   --skip-update     Skip nix flake update
#   --dry-run         Show what would be done without executing
#   --offline         Force offline mode (skip all network operations)
#   --help            Show this help message
#
# Examples:
#   ./scripts/rebuild-smart.sh                    # Full rebuild
#   ./scripts/rebuild-smart.sh --skip-update      # Rebuild without flake update
#   ./scripts/rebuild-smart.sh --offline          # Offline rebuild
#   ./scripts/rebuild-smart.sh --dry-run          # Preview what would happen

# ==============================================================================
# Strict Mode (without set -e, per style guide)
# ==============================================================================

set -o pipefail

# ==============================================================================
# Script Location
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to repo directory
cd "$REPO_DIR" || {
	echo "Error: Could not change to repository directory: $REPO_DIR" >&2
	exit 1
}

# ==============================================================================
# Source Helper Scripts
# ==============================================================================

# Source VCS helpers (git/jj abstraction)
if [[ -f "$SCRIPT_DIR/vcs-helpers.sh" ]]; then
	# shellcheck source=./vcs-helpers.sh
	source "$SCRIPT_DIR/vcs-helpers.sh"
else
	echo "Error: vcs-helpers.sh not found at $SCRIPT_DIR/vcs-helpers.sh" >&2
	exit 1
fi

# Source rebuild-smart helpers
if [[ -f "$SCRIPT_DIR/rebuild-smart-helpers.sh" ]]; then
	# shellcheck source=./rebuild-smart-helpers.sh
	source "$SCRIPT_DIR/rebuild-smart-helpers.sh"
else
	echo "Error: rebuild-smart-helpers.sh not found at $SCRIPT_DIR/rebuild-smart-helpers.sh" >&2
	exit 1
fi

# ==============================================================================
# Default Configuration
# ==============================================================================

SKIP_UPSTREAM=false
SKIP_DOTFILES=false
SKIP_UPDATE=true  # Default to skipping flake update (can be slow)
DRY_RUN=false
FORCE_OFFLINE=false

# ==============================================================================
# Help Function
# ==============================================================================

show_help() {
	cat << 'EOF'
Smart NixOS Rebuild

Orchestrates a complete NixOS rebuild with upstream sync, dotfile management,
and intelligent merging using jujutsu (jj) for conflict-free operations.

USAGE:
    rebuild-smart.sh [OPTIONS]

OPTIONS:
    --skip-upstream     Skip fetching/rebasing upstream changes
    --skip-dotfiles     Skip chezmoi dotfiles synchronization
    --skip-update       Skip nix flake update (default: skipped)
    --update            Run nix flake update (opposite of --skip-update)
    --dry-run           Show what would be done without executing
    --offline           Force offline mode (skip all network operations)
    --help, -h          Show this help message

PHASES:
    1. Preparation      Check prerequisites, record state for rollback
    2. Upstream Sync    Fetch and rebase upstream changes (jj/git)
    3. Dotfiles Sync    Sync chezmoi dotfiles with remote
    4. Nix-Secrets      Pull nix-secrets and update flake input
    5. Flake Update     Update all flake inputs (if --update)
    6. NixOS Rebuild    Run nh os switch (or nixos-rebuild)
    7. Post Checks      Verify system health (SOPS, systemd)
    8. Commit & Push    Auto-commit successful builds

EXAMPLES:
    # Standard rebuild (no flake update)
    rebuild-smart.sh

    # Full rebuild with flake update
    rebuild-smart.sh --update

    # Quick rebuild (skip network operations)
    rebuild-smart.sh --skip-upstream --skip-dotfiles

    # Offline rebuild
    rebuild-smart.sh --offline

    # Preview what would happen
    rebuild-smart.sh --dry-run

NOTES:
    - Prefers jujutsu (jj) for conflict-free merging
    - Automatically enters offline mode if network is unavailable
    - Offers rollback if NixOS rebuild fails
    - Creates tagged commits on successful builds

EOF
}

# ==============================================================================
# Argument Parsing
# ==============================================================================

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--skip-upstream)
				SKIP_UPSTREAM=true
				shift
				;;
			--skip-dotfiles)
				SKIP_DOTFILES=true
				shift
				;;
			--skip-update)
				SKIP_UPDATE=true
				shift
				;;
			--update)
				SKIP_UPDATE=false
				shift
				;;
			--dry-run)
				DRY_RUN=true
				shift
				;;
			--offline)
				FORCE_OFFLINE=true
				SKIP_UPSTREAM=true
				SKIP_DOTFILES=true
				shift
				;;
			--help|-h)
				show_help
				exit 0
				;;
			*)
				error "Unknown option: $1"
				echo "Use --help for usage information" >&2
				exit 1
				;;
		esac
	done
}

# ==============================================================================
# Signal Handlers
# ==============================================================================

# Cleanup on exit
cleanup_on_exit() {
	local exit_code=$?

	# Only cleanup state if we completed successfully
	if [[ $exit_code -eq 0 ]]; then
		cleanup_state
	fi

	exit $exit_code
}

# Handle Ctrl+C gracefully
handle_interrupt() {
	echo ""
	warn "Interrupted by user"
	echo ""
	echo "The rebuild was interrupted. Your system is in its pre-rebuild state."
	echo "Run 'rebuild-smart.sh' again to continue."
	exit 130
}

trap cleanup_on_exit EXIT
trap handle_interrupt INT TERM

# ==============================================================================
# Banner
# ==============================================================================

print_banner() {
	local hostname
	hostname=$(hostname 2>/dev/null || echo "unknown")

	echo ""
	echo -e "${COLOR_BOLD}${COLOR_CYAN}Smart NixOS Rebuild${COLOR_RESET}"
	echo -e "${COLOR_DIM}Host: $hostname | $(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}"
	echo -e "${COLOR_DIM}$(printf '%.0s=' {1..50})${COLOR_RESET}"
	echo ""

	# Show active flags
	local flags=()
	[[ "$SKIP_UPSTREAM" == "true" ]] && flags+=("skip-upstream")
	[[ "$SKIP_DOTFILES" == "true" ]] && flags+=("skip-dotfiles")
	[[ "$SKIP_UPDATE" == "true" ]] && flags+=("skip-update")
	[[ "$DRY_RUN" == "true" ]] && flags+=("dry-run")
	[[ "$FORCE_OFFLINE" == "true" ]] && flags+=("offline")

	if [[ ${#flags[@]} -gt 0 ]]; then
		echo -e "${COLOR_DIM}Flags: ${flags[*]}${COLOR_RESET}"
		echo ""
	fi
}

# ==============================================================================
# Main Workflow
# ==============================================================================

main() {
	# Parse command-line arguments
	parse_args "$@"

	# Export flags for helper functions
	export SKIP_UPSTREAM
	export SKIP_DOTFILES
	export SKIP_UPDATE
	export DRY_RUN

	# Print banner
	print_banner

	# Track overall success
	local overall_success=true

	# =========================================================================
	# Phase 1: Preparation
	# =========================================================================
	if ! phase "Preparation" rebuild_smart_prepare; then
		error "Preparation failed - cannot continue"
		exit 1
	fi

	# Check for forced offline mode
	if [[ "$FORCE_OFFLINE" == "true" ]]; then
		OFFLINE_MODE=true
		export OFFLINE_MODE
	fi

	# =========================================================================
	# Phase 2: Upstream Sync
	# =========================================================================
	if ! phase "Upstream Sync" rebuild_smart_sync_upstream; then
		warn "Upstream sync failed - continuing with local state"
		# Non-fatal: continue with local state
	fi

	# =========================================================================
	# Phase 3: Dotfiles Sync
	# =========================================================================
	if ! phase "Dotfiles Sync" rebuild_smart_sync_dotfiles; then
		warn "Dotfiles sync failed - continuing without dotfile changes"
		# Non-fatal: continue without dotfile changes
	fi

	# =========================================================================
	# Phase 4: Nix-Secrets Update
	# =========================================================================
	if ! phase "Nix-Secrets Update" rebuild_smart_update_secrets; then
		warn "Nix-secrets update failed - continuing with cached secrets"
		# Non-fatal: continue with cached secrets
	fi

	# =========================================================================
	# Phase 5: Flake Update (optional)
	# =========================================================================
	if ! phase "Flake Update" rebuild_smart_flake_update; then
		warn "Flake update failed - continuing with current lock"
		# Non-fatal: continue with current flake.lock
	fi

	# =========================================================================
	# Phase 6: NixOS Rebuild (critical)
	# =========================================================================
	if ! phase "NixOS Rebuild" rebuild_smart_nixos_rebuild; then
		error "NixOS rebuild failed"
		overall_success=false
		# Rollback is offered within the function
	fi

	# =========================================================================
	# Phase 7: Post-Rebuild Checks
	# =========================================================================
	if [[ "$overall_success" == "true" ]]; then
		if ! phase "Post-Rebuild Checks" rebuild_smart_post_checks; then
			warn "Some post-rebuild checks failed"
			# Non-fatal: system is rebuilt, just has some issues
		fi
	fi

	# =========================================================================
	# Phase 8: Commit & Push
	# =========================================================================
	if [[ "$overall_success" == "true" ]]; then
		if ! phase "Commit & Push" rebuild_smart_commit_push; then
			warn "Commit/push failed - changes are local only"
			# Non-fatal: local changes are fine
		fi
	fi

	# =========================================================================
	# Summary
	# =========================================================================
	print_phase_summary

	if [[ "$overall_success" == "true" ]]; then
		echo ""
		success "Smart rebuild completed successfully!"
		echo ""
		return 0
	else
		echo ""
		error "Smart rebuild encountered errors"
		echo ""
		echo "You can:"
		echo "  - Review the errors above"
		echo "  - Run 'nixos-rebuild switch --rollback' to rollback"
		echo "  - Fix issues and run 'rebuild-smart.sh' again"
		echo ""
		return 1
	fi
}

# ==============================================================================
# Entry Point
# ==============================================================================

main "$@"
