#!/usr/bin/env bash
# VCS abstraction for git/jujutsu compatibility
# Usage: source this file before VCS operations
#        Set VCS_TYPE=git or VCS_TYPE=jj (default: jj)
#
# IMPORTANT: jj is strongly preferred over git because:
#   - Automatic conflict-free merging of parallel commits
#   - Better handling of divergent branches
#   - No need for manual merge resolution in most cases

# Auto-detect VCS type, preferring jj
vcs_detect() {
	# Prefer jj if available and initialized
	if command -v jj &>/dev/null && [[ -d ".jj" ]]; then
		echo "jj"
	elif command -v git &>/dev/null && [[ -d ".git" ]]; then
		echo "git"
	else
		echo "none"
	fi
}

# Set VCS_TYPE with jj preference
if [[ -z "${VCS_TYPE:-}" ]]; then
	VCS_TYPE=$(vcs_detect)
fi
VCS_TYPE=${VCS_TYPE:-jj}

# Add files to staging (git) or mark for commit (jj)
vcs_add() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		# Jujutsu automatically tracks all changes in working copy
		# No explicit add needed
		:
	else
		git add "$@"
	fi
}

# Commit changes with message
vcs_commit() {
	local message="$1"
	if [[ "$VCS_TYPE" == "jj" ]]; then
		jj commit -m "$message"
		# Move bookmark to new commit if it exists
		if jj bookmark list | grep -q "simple:"; then
			jj bookmark set simple -r @-
		fi
	else
		git commit -m "$message"
	fi
}

# Push to remote
vcs_push() {
	local remote="${1:-origin}"
	local branch="${2:-}"

	if [[ "$VCS_TYPE" == "jj" ]]; then
		# jj git push pushes current change to tracking remote
		jj git push
	else
		if [[ -n "$branch" ]]; then
			git push "$remote" "$branch"
		else
			git push "$remote"
		fi
	fi
}

# Pull from remote (for updates)
# Note: For full merge support with parallel commits, use rebuild_smart_sync_upstream
vcs_pull() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		jj git fetch
	else
		git pull "$@"
	fi
}

# Sync with upstream, handling parallel commits automatically (jj only)
# Returns: 0 on success, 1 on conflicts needing manual resolution
vcs_sync_upstream() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		# Fetch first
		jj git fetch || return 1

		# Try rebase first (works for simple fast-forward cases)
		if jj rebase -d 'trunk()' 2>/dev/null; then
			return 0
		fi

		# Rebase failed - likely parallel commits, use merge approach
		# Get trunk branch
		local trunk_branch="main"
		for branch in "dev" "main" "master"; do
			if jj log -r "${branch}@origin" --no-graph -T 'change_id' 2>/dev/null | grep -q .; then
				trunk_branch="$branch"
				break
			fi
		done

		# Create merge commit
		if ! jj new "@-" "${trunk_branch}@origin" -m "merge: auto-merge with upstream" 2>/dev/null; then
			return 1
		fi

		# Check for conflicts
		if jj log -r @ --no-graph -T 'if(conflict, "CONFLICT")' 2>/dev/null | grep -q "CONFLICT"; then
			echo "Merge has conflicts - manual resolution required" >&2
			return 1
		fi

		return 0
	else
		git pull --rebase "$@"
	fi
}

# Check if repo is clean (no uncommitted changes)
vcs_is_clean() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		# Check if working copy has changes
		jj status | grep -q "Working copy changes:" && return 1 || return 0
	else
		[[ -z "$(git status --porcelain)" ]]
	fi
}

# Check if there are conflicts in the working copy (jj only)
vcs_has_conflicts() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		local conflict_output
		conflict_output=$(jj log -r @ --no-graph -T 'if(conflict, "CONFLICT")' 2>/dev/null || echo "")
		[[ "$conflict_output" == "CONFLICT" ]]
	else
		# Git: check for conflict markers in index
		git diff --check 2>/dev/null | grep -q "conflict" && return 0 || return 1
	fi
}

# Get current branch/change ID
vcs_current_ref() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		jj log -r @ --no-graph -T 'change_id'
	else
		git rev-parse --abbrev-ref HEAD
	fi
}

# Get current commit ID (full hash)
vcs_current_commit() {
	if [[ "$VCS_TYPE" == "jj" ]]; then
		jj log -r @ --no-graph -T 'commit_id'
	else
		git rev-parse HEAD
	fi
}
