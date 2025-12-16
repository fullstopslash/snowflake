#!/usr/bin/env bash
# VCS abstraction for git/jujutsu compatibility
# Usage: source this file before VCS operations
#        Set VCS_TYPE=git or VCS_TYPE=jj (default: jj)

VCS_TYPE=${VCS_TYPE:-jj}

# Add files to staging (git) or mark for commit (jj)
vcs_add() {
	if [ "$VCS_TYPE" = "jj" ]; then
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
	if [ "$VCS_TYPE" = "jj" ]; then
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

	if [ "$VCS_TYPE" = "jj" ]; then
		# jj git push pushes current change to tracking remote
		jj git push
	else
		if [ -n "$branch" ]; then
			git push "$remote" "$branch"
		else
			git push "$remote"
		fi
	fi
}

# Pull from remote (for updates)
vcs_pull() {
	if [ "$VCS_TYPE" = "jj" ]; then
		jj git fetch
	else
		git pull "$@"
	fi
}

# Check if repo is clean (no uncommitted changes)
vcs_is_clean() {
	if [ "$VCS_TYPE" = "jj" ]; then
		# Check if working copy has changes
		jj status | grep -q "Working copy changes:" && return 1 || return 0
	else
		[ -z "$(git status --porcelain)" ]
	fi
}

# Get current branch/change ID
vcs_current_ref() {
	if [ "$VCS_TYPE" = "jj" ]; then
		jj log -r @ --no-graph -T 'change_id'
	else
		git rev-parse --abbrev-ref HEAD
	fi
}
