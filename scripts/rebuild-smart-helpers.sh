#!/usr/bin/env bash
# rebuild-smart-helpers.sh - Helper functions for smart NixOS rebuilds
#
# This script provides modular helper functions for the rebuild-smart workflow.
# It handles upstream sync, dotfiles, nix-secrets updates, rebuilds, and commits.
#
# Dependencies:
#   - vcs-helpers.sh (git/jj abstraction)
#   - jujutsu (jj) for conflict-free merging
#   - chezmoi (optional, for dotfiles sync)
#   - nh (for NixOS rebuilds)
#
# Usage:
#   source scripts/rebuild-smart-helpers.sh
#   phase "Preparation" rebuild_smart_prepare

# ==============================================================================
# Configuration
# ==============================================================================

# State directory for tracking rebuild status
REBUILD_STATE_DIR="${REBUILD_STATE_DIR:-/tmp/rebuild-smart}"

# Chezmoi sync state file
CHEZMOI_STATE_FILE="/var/lib/chezmoi-sync/last-sync-status"

# Default timeouts (in seconds)
NETWORK_TIMEOUT="${NETWORK_TIMEOUT:-5}"
FLAKE_UPDATE_TIMEOUT="${FLAKE_UPDATE_TIMEOUT:-300}"

# Rollback state
ROLLBACK_COMMIT=""
ROLLBACK_GENERATION=""

# ==============================================================================
# ANSI Color Codes
# ==============================================================================

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'

# ==============================================================================
# Output Helpers
# ==============================================================================

# Print a message with timestamp and level
# Usage: log INFO "message" or log WARN "message"
log() {
	local level="${1:-INFO}"
	shift
	local timestamp
	timestamp=$(date '+%H:%M:%S')
	case "$level" in
		INFO)  echo -e "${COLOR_DIM}[${timestamp}]${COLOR_RESET} $*" ;;
		WARN)  echo -e "${COLOR_DIM}[${timestamp}]${COLOR_RESET} ${COLOR_YELLOW}$*${COLOR_RESET}" ;;
		ERROR) echo -e "${COLOR_DIM}[${timestamp}]${COLOR_RESET} ${COLOR_RED}$*${COLOR_RESET}" ;;
		*)     echo -e "${COLOR_DIM}[${timestamp}]${COLOR_RESET} $*" ;;
	esac
}

# Print info message
info() {
	echo -e "${COLOR_BLUE}[*]${COLOR_RESET} $*"
}

# Print success message
success() {
	echo -e "${COLOR_GREEN}[+]${COLOR_RESET} $*"
}

# Print warning message
warn() {
	echo -e "${COLOR_YELLOW}[!]${COLOR_RESET} $*" >&2
}

# Print error message
error() {
	echo -e "${COLOR_RED}[x]${COLOR_RESET} $*" >&2
}

# Print a header
header() {
	local title="$1"
	echo ""
	echo -e "${COLOR_BOLD}${COLOR_CYAN}$title${COLOR_RESET}"
	echo -e "${COLOR_DIM}$(printf '%.0s-' {1..50})${COLOR_RESET}"
}

# ==============================================================================
# Phase Execution Helper
# ==============================================================================

# Track phase timing and status
PHASE_COUNT=0
PHASE_RESULTS=()

# Execute a phase with error handling and timing
# Usage: phase "Phase Name" function_name [args...]
# Returns: 0 on success, 1 on failure
phase() {
	local phase_name="$1"
	local phase_func="$2"
	shift 2
	local phase_args=("$@")

	PHASE_COUNT=$((PHASE_COUNT + 1))
	local phase_num="$PHASE_COUNT"
	local start_time end_time duration

	start_time=$(date +%s)

	# Show phase start
	echo -en "${COLOR_CYAN}[...]${COLOR_RESET} Phase ${phase_num}: ${phase_name}..."

	# Run the phase function, capturing output
	local output_file
	output_file=$(mktemp)
	local exit_code=0

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo " (dry-run)"
		echo -e "  ${COLOR_DIM}Would execute: ${phase_func} ${phase_args[*]}${COLOR_RESET}"
		rm -f "$output_file"
		PHASE_RESULTS+=("${phase_name}:skipped:0")
		return 0
	fi

	# Execute the phase function
	if "$phase_func" "${phase_args[@]}" > "$output_file" 2>&1; then
		exit_code=0
	else
		exit_code=$?
	fi

	end_time=$(date +%s)
	duration=$((end_time - start_time))

	# Clear the "..." line and show result
	echo -en "\r\033[K"

	if [[ $exit_code -eq 0 ]]; then
		echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} Phase ${phase_num}: ${phase_name} ${COLOR_DIM}(${duration}s)${COLOR_RESET}"
		PHASE_RESULTS+=("${phase_name}:success:${duration}")
	elif [[ $exit_code -eq 2 ]]; then
		# Exit code 2 = skipped (not an error)
		echo -e "${COLOR_YELLOW}[>>]${COLOR_RESET} Phase ${phase_num}: ${phase_name} ${COLOR_DIM}(skipped)${COLOR_RESET}"
		PHASE_RESULTS+=("${phase_name}:skipped:${duration}")
		exit_code=0
	else
		echo -e "${COLOR_RED}[!!]${COLOR_RESET} Phase ${phase_num}: ${phase_name} ${COLOR_DIM}(${duration}s)${COLOR_RESET}"
		echo ""
		echo -e "${COLOR_RED}Error output:${COLOR_RESET}"
		sed 's/^/  /' < "$output_file"
		echo ""
		PHASE_RESULTS+=("${phase_name}:failed:${duration}")
	fi

	rm -f "$output_file"
	return $exit_code
}

# Print summary of all phases
print_phase_summary() {
	echo ""
	header "Summary"

	local total_time=0
	local failed=0
	local skipped=0

	for result in "${PHASE_RESULTS[@]}"; do
		local name duration status
		name=$(echo "$result" | cut -d: -f1)
		status=$(echo "$result" | cut -d: -f2)
		duration=$(echo "$result" | cut -d: -f3)
		total_time=$((total_time + duration))

		case "$status" in
			success)
				echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} $name (${duration}s)"
				;;
			skipped)
				echo -e "  ${COLOR_YELLOW}[>>]${COLOR_RESET} $name (skipped)"
				skipped=$((skipped + 1))
				;;
			failed)
				echo -e "  ${COLOR_RED}[!!]${COLOR_RESET} $name (${duration}s)"
				failed=$((failed + 1))
				;;
		esac
	done

	echo ""
	echo -e "${COLOR_DIM}Total time: ${total_time}s${COLOR_RESET}"

	if [[ $failed -gt 0 ]]; then
		echo -e "${COLOR_RED}$failed phase(s) failed${COLOR_RESET}"
		return 1
	elif [[ $skipped -gt 0 ]]; then
		echo -e "${COLOR_YELLOW}$skipped phase(s) skipped${COLOR_RESET}"
	fi

	return 0
}

# ==============================================================================
# Network Helpers
# ==============================================================================

# Check if network is available
# Returns: 0 if online, 1 if offline
check_network() {
	# Try common reliable endpoints
	local endpoints=(
		"github.com"
		"gitlab.com"
		"1.1.1.1"
	)

	for endpoint in "${endpoints[@]}"; do
		if ping -c 1 -W "$NETWORK_TIMEOUT" "$endpoint" &>/dev/null; then
			return 0
		fi
	done

	return 1
}

# Set offline mode flag
OFFLINE_MODE=false

set_offline_mode() {
	OFFLINE_MODE=true
	warn "Network unavailable - entering offline mode"
}

# ==============================================================================
# Phase 1: Preparation
# ==============================================================================

# Check prerequisites and record state for rollback
# Sets: ROLLBACK_COMMIT, ROLLBACK_GENERATION
rebuild_smart_prepare() {
	local errors=0

	# Create state directory
	mkdir -p "$REBUILD_STATE_DIR" || return 1

	# Check if in nix-config directory
	if [[ ! -f "flake.nix" ]]; then
		error "Not in nix-config directory (no flake.nix found)"
		error "Please run from the nix-config root directory"
		return 1
	fi
	info "In nix-config directory"

	# Verify VCS is available (git or jj)
	if command -v jj &>/dev/null && [[ -d ".jj" ]]; then
		info "Using jujutsu (jj) for version control"
		export VCS_TYPE="jj"
	elif command -v git &>/dev/null && [[ -d ".git" ]]; then
		info "Using git for version control"
		export VCS_TYPE="git"
	else
		error "No version control system found (need git or jj)"
		return 1
	fi

	# Record current commit for rollback
	if [[ "$VCS_TYPE" == "jj" ]]; then
		ROLLBACK_COMMIT=$(jj log -r @ --no-graph -T 'commit_id' 2>/dev/null || echo "")
	else
		ROLLBACK_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
	fi
	if [[ -n "$ROLLBACK_COMMIT" ]]; then
		echo "$ROLLBACK_COMMIT" > "$REBUILD_STATE_DIR/rollback-commit"
		info "Recorded commit for rollback: ${ROLLBACK_COMMIT:0:12}"
	fi

	# Record current NixOS generation for rollback
	if [[ -L "/nix/var/nix/profiles/system" ]]; then
		ROLLBACK_GENERATION=$(readlink -f /nix/var/nix/profiles/system)
		echo "$ROLLBACK_GENERATION" > "$REBUILD_STATE_DIR/rollback-generation"
		info "Recorded NixOS generation for rollback"
	fi

	# Check network connectivity
	if check_network; then
		info "Network connectivity: online"
		OFFLINE_MODE=false
	else
		warn "Network connectivity: offline"
		OFFLINE_MODE=true
		echo "offline" > "$REBUILD_STATE_DIR/network-status"
	fi

	# Warn if uncommitted changes exist
	if [[ "$VCS_TYPE" == "jj" ]]; then
		if jj status 2>/dev/null | grep -q "Working copy changes:"; then
			warn "Uncommitted changes detected in working copy"
		fi
	else
		if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
			warn "Uncommitted changes detected in working copy"
		fi
	fi

	return $errors
}

# ==============================================================================
# Phase 2: Upstream Sync (jj-first with automatic merge)
# ==============================================================================

# Helper: Get the main tracking branch name
# Returns: branch name (e.g., "dev" or "main")
jj_get_trunk_branch() {
	# Check common trunk branch names in order of preference
	local branches=("dev" "main" "master")
	for branch in "${branches[@]}"; do
		if jj log -r "${branch}@origin" --no-graph -T 'change_id' 2>/dev/null | grep -q .; then
			echo "$branch"
			return 0
		fi
	done
	# Fallback: try to get from revset
	echo "main"
}

# Helper: Check if we have parallel commits (divergence from upstream)
# Returns: 0 if parallel commits exist, 1 if no divergence
jj_has_parallel_commits() {
	local trunk_branch
	trunk_branch=$(jj_get_trunk_branch)
	local remote_ref="${trunk_branch}@origin"

	# Get the remote commit
	local remote_commit
	remote_commit=$(jj log -r "$remote_ref" --no-graph -T 'commit_id' 2>/dev/null || echo "")

	if [[ -z "$remote_commit" ]]; then
		# No remote tracking - no divergence possible
		return 1
	fi

	# Get the current working copy's parent (the actual committed work)
	local local_parent
	local_parent=$(jj log -r '@-' --no-graph -T 'commit_id' 2>/dev/null || echo "")

	# Check if remote is an ancestor of our work
	if jj log -r "ancestors(@) & $remote_ref" --no-graph -T 'commit_id' 2>/dev/null | grep -q "$remote_commit"; then
		# Remote is already in our history - no divergence
		return 1
	fi

	# Check if our parent is an ancestor of remote (we're behind)
	if jj log -r "ancestors($remote_ref) & @-" --no-graph -T 'commit_id' 2>/dev/null | grep -q "$local_parent"; then
		# We're just behind, simple fast-forward case
		return 1
	fi

	# If neither is ancestor of the other, we have divergence (parallel commits)
	return 0
}

# Helper: Check if current working copy has actual file conflicts
# Returns: 0 if conflicts exist, 1 if no conflicts
jj_has_conflicts() {
	# Check if working copy or any parent has conflict markers
	if jj log -r @ --no-graph 2>/dev/null | grep -q "conflict"; then
		return 0
	fi
	# Double-check with explicit conflicts flag
	local conflict_output
	conflict_output=$(jj log -r @ --no-graph -T 'if(conflict, "CONFLICT")' 2>/dev/null || echo "")
	if [[ "$conflict_output" == "CONFLICT" ]]; then
		return 0
	fi
	return 1
}

# Helper: Show conflict details for user resolution
jj_show_conflicts() {
	info "Conflict details:"
	echo ""
	# Show files with conflicts
	jj diff --summary 2>/dev/null | grep -E "^[CM]" | while read -r line; do
		echo "  $line"
	done
	echo ""
	# Show conflict markers location
	jj resolve --list 2>/dev/null | head -20 | while read -r line; do
		echo "  $line"
	done
}

# Helper: Perform automatic merge of parallel commits
# Returns: 0 on success (no conflicts), 1 on conflicts needing resolution
jj_auto_merge_parallel() {
	local trunk_branch
	trunk_branch=$(jj_get_trunk_branch)
	local remote_ref="${trunk_branch}@origin"

	info "Detected parallel commits - attempting automatic merge..."

	# Get change IDs for the merge
	# We need to merge our current work with the remote
	local local_change
	local_change=$(jj log -r '@-' --no-graph -T 'change_id.short()' 2>/dev/null || echo "")
	local remote_change
	remote_change=$(jj log -r "$remote_ref" --no-graph -T 'change_id.short()' 2>/dev/null || echo "")

	if [[ -z "$local_change" ]] || [[ -z "$remote_change" ]]; then
		warn "Could not determine change IDs for merge"
		return 1
	fi

	info "Merging local ($local_change) with upstream ($remote_change)..."

	# Create a new merge commit with both parents
	# jj new with multiple revisions creates a merge
	if ! jj new "@-" "$remote_ref" -m "merge: auto-merge with upstream" 2>&1; then
		warn "Could not create merge commit"
		return 1
	fi

	# Check if the merge resulted in conflicts
	if jj_has_conflicts; then
		error "Merge has file conflicts that need manual resolution"
		echo ""
		jj_show_conflicts
		echo ""
		echo "To resolve:"
		echo "  1. Edit conflicted files (look for <<<<<<< markers)"
		echo "  2. Run: jj resolve (or manually edit)"
		echo "  3. Run: jj describe -m 'merge: resolved conflicts from upstream'"
		echo "  4. Run: just rebuild"
		echo ""
		return 1
	fi

	# No conflicts - merge succeeded!
	success "Automatic merge successful (no conflicts)"

	# Update the merge commit message
	jj describe -m "merge: auto-merge parallel commits from upstream (no conflicts)" 2>/dev/null || true

	return 0
}

# Fetch and sync upstream changes using jujutsu
# Leverages jj's superior merge capabilities for conflict-free parallel commits
rebuild_smart_sync_upstream() {
	# Skip if offline
	if [[ "$OFFLINE_MODE" == "true" ]]; then
		warn "Skipping upstream sync (offline mode)"
		return 2  # Return 2 to indicate "skipped"
	fi

	# Skip if --skip-upstream flag was set
	if [[ "${SKIP_UPSTREAM:-false}" == "true" ]]; then
		info "Skipping upstream sync (--skip-upstream)"
		return 2
	fi

	# Prefer jujutsu for conflict-free sync
	if [[ "$VCS_TYPE" == "jj" ]] || { command -v jj &>/dev/null && [[ -d ".jj" ]]; }; then
		info "Fetching upstream changes with jj..."

		# Ensure jj is initialized (co-located with git)
		if [[ ! -d ".jj" ]]; then
			info "Initializing jj co-located repo..."
			jj git init --colocate || return 1
		fi

		# Fetch remote changes
		if ! jj git fetch 2>&1; then
			warn "Could not fetch upstream (network issue?)"
			return 2  # Non-fatal, continue with local state
		fi
		info "Fetched upstream changes"

		# Check for parallel commits (divergence)
		if jj_has_parallel_commits; then
			# We have divergence - use jj's automatic merge
			if ! jj_auto_merge_parallel; then
				# Conflicts detected - stop for manual resolution
				return 1
			fi
			# Merge succeeded without conflicts
		else
			# No divergence - simple rebase onto trunk
			info "No divergence detected - rebasing onto trunk..."
			local trunk_branch
			trunk_branch=$(jj_get_trunk_branch)

			if ! jj rebase -d "${trunk_branch}@origin" 2>&1; then
				# Rebase failed - could be conflicts, try the merge approach
				warn "Simple rebase failed, attempting merge approach..."
				if ! jj_auto_merge_parallel; then
					return 1
				fi
			else
				success "Rebased cleanly onto upstream"
			fi
		fi

		# Final conflict check (safety)
		if jj_has_conflicts; then
			error "Unexpected conflicts after sync"
			jj_show_conflicts
			return 1
		fi

		success "Upstream sync complete (jj)"
	else
		# Fallback to git
		info "Fetching upstream changes with git..."

		if ! git fetch origin 2>&1; then
			warn "Could not fetch upstream (network issue?)"
			return 2
		fi

		# Try to pull with rebase
		local current_branch
		current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

		if [[ -n "$current_branch" ]]; then
			if ! git pull --rebase origin "$current_branch" 2>&1; then
				warn "Pull had conflicts - resolve manually or use jj"
				return 1
			fi
		fi

		success "Upstream sync complete (git)"
	fi

	return 0
}

# ==============================================================================
# Phase 3: Dotfiles Sync
# ==============================================================================

# Sync chezmoi dotfiles with remote
# Uses the chezmoi-sync systemd service or direct command
rebuild_smart_sync_dotfiles() {
	# Skip if offline
	if [[ "$OFFLINE_MODE" == "true" ]]; then
		warn "Skipping dotfiles sync (offline mode)"
		return 2
	fi

	# Skip if --skip-dotfiles flag was set
	if [[ "${SKIP_DOTFILES:-false}" == "true" ]]; then
		info "Skipping dotfiles sync (--skip-dotfiles)"
		return 2
	fi

	# Check if chezmoi is available
	if ! command -v chezmoi &>/dev/null; then
		info "Chezmoi not installed - skipping dotfiles sync"
		return 2
	fi

	# Check if chezmoi is initialized
	local chezmoi_dir="$HOME/.local/share/chezmoi"
	if [[ ! -d "$chezmoi_dir" ]]; then
		info "Chezmoi not initialized - skipping dotfiles sync"
		return 2
	fi

	info "Syncing chezmoi dotfiles..."

	# Try systemd service first (preferred for proper permissions)
	if systemctl is-active chezmoi-sync-manual.service &>/dev/null; then
		warn "Chezmoi sync already in progress - skipping"
		return 2
	fi

	if systemctl cat chezmoi-sync-manual.service &>/dev/null; then
		info "Using systemd service for chezmoi sync..."
		sudo systemctl start chezmoi-sync-manual.service || {
			warn "Systemd chezmoi sync failed"
			return 2
		}

		# Wait for completion and check status
		local timeout=60
		local elapsed=0
		while systemctl is-active chezmoi-sync-manual.service &>/dev/null; do
			sleep 1
			elapsed=$((elapsed + 1))
			if [[ $elapsed -ge $timeout ]]; then
				warn "Chezmoi sync timed out"
				return 2
			fi
		done

		# Check status file
		if [[ -f "$CHEZMOI_STATE_FILE" ]]; then
			local status
			status=$(cat "$CHEZMOI_STATE_FILE")
			case "$status" in
				success*)
					success "Chezmoi sync complete: $status"
					;;
				*)
					warn "Chezmoi sync status: $status"
					;;
			esac
		fi
	else
		# Direct chezmoi commands (fallback)
		info "Using direct chezmoi commands..."

		# Re-add local changes
		chezmoi re-add 2>&1 || warn "chezmoi re-add had issues"

		# Push if jj is available in chezmoi dir
		if [[ -d "$chezmoi_dir/.jj" ]]; then
			(
				cd "$chezmoi_dir" || exit 1
				jj git push 2>&1 || warn "Could not push chezmoi changes"
			)
		fi

		success "Chezmoi sync complete (direct)"
	fi

	return 0
}

# ==============================================================================
# Phase 4: Nix-Secrets Update
# ==============================================================================

# Update nix-secrets flake input
# Pulls the nix-secrets repo and updates the flake lock
rebuild_smart_update_secrets() {
	# Skip if offline
	if [[ "$OFFLINE_MODE" == "true" ]]; then
		warn "Skipping nix-secrets update (offline mode)"
		return 2
	fi

	local nix_secrets_dir="../nix-secrets"

	# Check if nix-secrets directory exists
	if [[ ! -d "$nix_secrets_dir" ]]; then
		info "nix-secrets directory not found - skipping"
		return 2
	fi

	info "Updating nix-secrets..."

	# Pull nix-secrets repo
	(
		cd "$nix_secrets_dir" || exit 1

		# Source vcs-helpers for pull
		if [[ -f "../nix-config/scripts/vcs-helpers.sh" ]]; then
			# shellcheck source=./vcs-helpers.sh
			source "../nix-config/scripts/vcs-helpers.sh"
			vcs_pull 2>&1 || warn "Could not pull nix-secrets"
		else
			git pull 2>&1 || warn "Could not pull nix-secrets"
		fi
	) || warn "nix-secrets pull had issues"

	# Update flake input with timeout
	info "Updating nix-secrets flake input..."
	if ! timeout "$NETWORK_TIMEOUT" nix flake update nix-secrets 2>&1; then
		warn "Could not update nix-secrets flake input (timeout or error)"
		return 2
	fi

	success "nix-secrets updated"
	return 0
}

# ==============================================================================
# Phase 5: Flake Update
# ==============================================================================

# Run nix flake update and stage changes
rebuild_smart_flake_update() {
	# Skip if --skip-update flag was set
	if [[ "${SKIP_UPDATE:-false}" == "true" ]]; then
		info "Skipping flake update (--skip-update)"
		return 2
	fi

	# Skip if offline
	if [[ "$OFFLINE_MODE" == "true" ]]; then
		warn "Skipping flake update (offline mode)"
		return 2
	fi

	info "Updating flake inputs..."

	# Run nix flake update with timeout
	if ! timeout "$FLAKE_UPDATE_TIMEOUT" nix flake update 2>&1; then
		error "Flake update failed or timed out"
		return 1
	fi

	# Stage flake.lock changes
	if [[ "$VCS_TYPE" == "jj" ]]; then
		# jj auto-tracks, but describe the change
		jj describe -m "chore: update flake inputs" 2>&1 || true
	else
		git add flake.lock 2>&1 || true
	fi

	success "Flake inputs updated"
	return 0
}

# ==============================================================================
# Phase 6: NixOS Rebuild
# ==============================================================================

# Run NixOS rebuild with nh
# Captures output and offers rollback on failure
rebuild_smart_nixos_rebuild() {
	info "Starting NixOS rebuild..."

	# Add intent-to-add for any new files (allows nh to see them)
	if [[ "$VCS_TYPE" != "jj" ]]; then
		git add --intent-to-add . 2>&1 || true
	fi

	# Export REPO_PATH for flake evaluation
	export REPO_PATH
	REPO_PATH=$(pwd)

	# Prefer nh for better output
	if command -v nh &>/dev/null; then
		info "Using nh for rebuild..."

		# Run nh os switch
		if ! nh os switch . -- --impure --show-trace 2>&1; then
			error "NixOS rebuild failed"
			echo ""
			offer_rollback
			return 1
		fi
	else
		# Fallback to nixos-rebuild
		info "Using nixos-rebuild..."

		local hostname
		hostname=$(hostname)
		if ! sudo nixos-rebuild switch --flake ".#${hostname}" --impure --show-trace 2>&1; then
			error "NixOS rebuild failed"
			echo ""
			offer_rollback
			return 1
		fi
	fi

	success "NixOS rebuild complete"
	return 0
}

# Offer rollback to previous generation
offer_rollback() {
	if [[ -f "$REBUILD_STATE_DIR/rollback-generation" ]]; then
		echo ""
		warn "Rebuild failed. Would you like to rollback to the previous generation?"
		echo -e "  Previous generation: ${COLOR_DIM}$(cat "$REBUILD_STATE_DIR/rollback-generation")${COLOR_RESET}"
		echo ""
		echo -en "${COLOR_YELLOW}[?]${COLOR_RESET} Rollback? [y/N]: "
		read -r response

		if [[ "$response" =~ ^[Yy]$ ]]; then
			info "Rolling back to previous generation..."
			if sudo nixos-rebuild switch --rollback 2>&1; then
				success "Rollback complete"
			else
				error "Rollback failed - manual intervention required"
				error "Try: sudo nixos-rebuild switch --rollback"
			fi
		fi
	fi
}

# ==============================================================================
# Phase 7: Post-Rebuild Checks
# ==============================================================================

# Run post-rebuild health checks
rebuild_smart_post_checks() {
	local errors=0

	info "Running post-rebuild checks..."

	# Check for SOPS issues
	local script_dir
	script_dir="$(dirname "${BASH_SOURCE[0]}")"
	if [[ -x "$script_dir/check-sops.sh" ]]; then
		info "Checking SOPS secrets..."
		if ! "$script_dir/check-sops.sh" 2>&1; then
			warn "SOPS check reported issues"
			errors=$((errors + 1))
		fi
	fi

	# Check for failed systemd units
	info "Checking systemd units..."
	local failed_units
	failed_units=$(systemctl --failed --no-legend 2>/dev/null | wc -l)

	if [[ "$failed_units" -gt 0 ]]; then
		warn "$failed_units systemd unit(s) failed:"
		systemctl --failed --no-legend 2>/dev/null | sed 's/^/  /'
		errors=$((errors + 1))
	else
		success "All systemd units healthy"
	fi

	# Display summary of changes (if git)
	if [[ "$VCS_TYPE" != "jj" ]]; then
		local changed_files
		changed_files=$(git diff --name-only HEAD~1 2>/dev/null | wc -l || echo "0")
		if [[ "$changed_files" -gt 0 ]]; then
			info "Files changed in this rebuild: $changed_files"
		fi
	fi

	if [[ $errors -gt 0 ]]; then
		warn "Post-rebuild checks found $errors issue(s)"
		return 0  # Don't fail the whole rebuild for check issues
	fi

	success "Post-rebuild checks passed"
	return 0
}

# ==============================================================================
# Phase 8: Commit & Push
# ==============================================================================

# Auto-commit and push successful builds
rebuild_smart_commit_push() {
	# Skip if offline
	if [[ "$OFFLINE_MODE" == "true" ]]; then
		warn "Skipping commit/push (offline mode)"
		# Still commit locally
	fi

	info "Committing successful build..."

	local hostname
	hostname=$(hostname)
	local timestamp
	timestamp=$(date -Iseconds)
	local commit_msg="chore($hostname): successful rebuild - $timestamp"

	if [[ "$VCS_TYPE" == "jj" ]]; then
		# jj: describe current change and commit
		jj describe -m "$commit_msg" 2>&1 || true

		# Create new empty change for future work
		jj new 2>&1 || true

		# Push if online
		if [[ "$OFFLINE_MODE" != "true" ]]; then
			info "Pushing changes..."
			if ! jj git push 2>&1; then
				warn "Could not push to remote (will retry next sync)"
			else
				success "Changes pushed to remote"
			fi
		fi
	else
		# git: add and commit
		git add -A 2>&1 || true

		# Check if there are changes to commit
		if git diff --cached --quiet 2>/dev/null; then
			info "No changes to commit"
		else
			git commit -m "$commit_msg" 2>&1 || warn "Commit failed"
		fi

		# Push if online
		if [[ "$OFFLINE_MODE" != "true" ]]; then
			info "Pushing changes..."
			if ! git push 2>&1; then
				warn "Could not push to remote (will retry next sync)"
			else
				success "Changes pushed to remote"
			fi
		fi
	fi

	return 0
}

# ==============================================================================
# Rollback Helper
# ==============================================================================

# Perform full rollback to pre-rebuild state
rollback_full() {
	header "Rolling Back"

	# Rollback NixOS generation
	if [[ -f "$REBUILD_STATE_DIR/rollback-generation" ]]; then
		info "Rolling back NixOS generation..."
		if sudo nixos-rebuild switch --rollback 2>&1; then
			success "NixOS generation rolled back"
		else
			error "NixOS rollback failed"
		fi
	fi

	# Rollback VCS state
	if [[ -f "$REBUILD_STATE_DIR/rollback-commit" ]]; then
		local commit
		commit=$(cat "$REBUILD_STATE_DIR/rollback-commit")
		info "Rolling back to commit: ${commit:0:12}"

		if [[ "$VCS_TYPE" == "jj" ]]; then
			# jj: edit the saved commit
			jj edit "$commit" 2>&1 || warn "Could not restore jj state"
		else
			# git: hard reset
			git reset --hard "$commit" 2>&1 || warn "Could not restore git state"
		fi
	fi

	success "Rollback complete"
}

# ==============================================================================
# Cleanup
# ==============================================================================

# Clean up state directory
cleanup_state() {
	if [[ -d "$REBUILD_STATE_DIR" ]]; then
		rm -rf "$REBUILD_STATE_DIR"
	fi
}
