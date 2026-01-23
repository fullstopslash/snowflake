#!/usr/bin/env bash
# vikunja-sync: Bidirectional multi-project sync between Taskwarrior and Vikunja
set -euo pipefail

# Configuration (can be overridden via environment)
VIKUNJA_URL="${VIKUNJA_URL:-https://vikunja.chimera-micro.ts.net}"
VIKUNJA_USER="${VIKUNJA_USER:-rain}"
CALDAV_URL="${VIKUNJA_URL}/dav"

# Paths to secrets (set by NixOS module)
VIKUNJA_API_TOKEN_FILE="${VIKUNJA_API_TOKEN_FILE:-}"
VIKUNJA_CALDAV_PASS_FILE="${VIKUNJA_CALDAV_PASS_FILE:-}"

# Lock file base path
LOCK_DIR="/tmp/vikunja-sync"
mkdir -p "$LOCK_DIR"

# Sync options
RESOLUTION_STRATEGY="${RESOLUTION_STRATEGY:-MostRecentRS}"
VERBOSE="${VERBOSE:-}"

log() {
    echo "[$(date -Iseconds)] $*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

# Get API token
get_api_token() {
    if [[ -n "$VIKUNJA_API_TOKEN_FILE" && -r "$VIKUNJA_API_TOKEN_FILE" ]]; then
        cat "$VIKUNJA_API_TOKEN_FILE"
    else
        # Fallback to sops
        sops -d ~/nix-secrets/sops/shared.yaml | yq '.caldav."vikunja-api"'
    fi
}

# Get CalDAV password
get_caldav_pass() {
    if [[ -n "$VIKUNJA_CALDAV_PASS_FILE" && -r "$VIKUNJA_CALDAV_PASS_FILE" ]]; then
        cat "$VIKUNJA_CALDAV_PASS_FILE"
    else
        # Fallback to sops
        sops -d ~/nix-secrets/sops/shared.yaml | yq '.caldav.vikunja'
    fi
}

# Get all Vikunja projects via API
get_vikunja_projects() {
    local token
    token=$(get_api_token)
    curl -sf -H "Authorization: Bearer $token" "$VIKUNJA_URL/api/v1/projects" | jq -r '.[].title'
}

# Get all Taskwarrior projects
get_taskwarrior_projects() {
    task _unique project 2>/dev/null | grep -v '^$' || true
}

# Create a Vikunja project via API if it doesn't exist
create_vikunja_project() {
    local project_name="$1"
    local token
    token=$(get_api_token)

    # Check if exists
    local exists
    exists=$(curl -sf -H "Authorization: Bearer $token" "$VIKUNJA_URL/api/v1/projects" | jq -r --arg name "$project_name" '.[] | select(.title == $name) | .id')

    if [[ -z "$exists" ]]; then
        log "Creating Vikunja project: $project_name"
        curl -sf -X PUT \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg title "$project_name" '{title: $title}')" \
            "$VIKUNJA_URL/api/v1/projects" > /dev/null
    fi
}

# Repair correlations between Taskwarrior and CalDAV
# This ensures items that exist in both systems are properly tracked
# ONLY runs if syncall has already established its cache (correlation file exists)
repair_correlations() {
    local project="$1"
    local correlation_file="$HOME/.config/syncall/${project}____${project}__.yaml"

    # Skip on fresh setup - syncall needs to establish cache first
    if [[ ! -f "$correlation_file" ]]; then
        log "Skipping correlation repair for $project (first sync)"
        return 0
    fi

    local caldav_pass
    caldav_pass=$(get_caldav_pass)

    # Run correlation repair script (failures are non-fatal)
    vikunja-sync-correlate "$project" "$CALDAV_URL" "$VIKUNJA_USER" "$caldav_pass" 2>&1 || true
}

# Sync a single project
sync_project() {
    local project="$1"
    local lock_file
    lock_file="$LOCK_DIR/$(echo "$project" | tr '/' '_').lock"

    # Skip if locked (another sync in progress for this project)
    if [[ -f "$lock_file" ]]; then
        local lock_age
        lock_age=$(($(date +%s) - $(stat -c %Y "$lock_file")))
        if [[ $lock_age -lt 30 ]]; then
            log "Skipping $project (sync in progress)"
            return 0
        fi
    fi

    touch "$lock_file"

    log "Syncing project: $project"

    # Ensure project exists in Vikunja
    create_vikunja_project "$project"

    # Repair correlations before sync (ensures items in both systems are tracked)
    repair_correlations "$project"

    local verbose_flag=""
    [[ -n "$VERBOSE" ]] && verbose_flag="-v"

    # Determine password command based on available sources
    local passwd_cmd
    if [[ -n "$VIKUNJA_CALDAV_PASS_FILE" && -r "$VIKUNJA_CALDAV_PASS_FILE" ]]; then
        passwd_cmd="cat '$VIKUNJA_CALDAV_PASS_FILE'"
    else
        # Fallback to sops
        passwd_cmd="sops -d ~/nix-secrets/sops/shared.yaml | yq '.caldav.vikunja'"
    fi

    # Run syncall for this project (set VIKUNJA_SYNC_RUNNING to prevent hook loops)
    VIKUNJA_SYNC_RUNNING=1 tw_caldav_sync \
        --caldav-url "$CALDAV_URL" \
        --caldav-user "$VIKUNJA_USER" \
        --caldav-passwd-cmd "$passwd_cmd" \
        --caldav-calendar "$project" \
        --tw-project "$project" \
        --resolution-strategy "$RESOLUTION_STRATEGY" \
        $verbose_flag \
        2>&1 || log "Warning: sync for $project had errors"

    # Clean up lock
    rm -f "$lock_file"
}

# Sync labels from Vikunja to Taskwarrior tags
# This handles what syncall doesn't support natively
sync_labels() {
    local project="${1:-}"
    log "Syncing labels/tags..."

    # Run label sync script (failures are non-fatal)
    if [[ -n "$project" ]]; then
        vikunja-sync-labels "$project" 2>&1 || log "Warning: label sync had errors"
    else
        vikunja-sync-labels 2>&1 || log "Warning: label sync had errors"
    fi
}

# Sync all projects (union of both sides)
sync_all() {
    log "Starting full bidirectional sync"

    # Get projects from both sides
    local vikunja_projects taskwarrior_projects all_projects
    vikunja_projects=$(get_vikunja_projects)
    taskwarrior_projects=$(get_taskwarrior_projects)

    # Union of both project lists (unique, sorted)
    all_projects=$(echo -e "$vikunja_projects\n$taskwarrior_projects" | grep -v '^$' | sort -u)

    if [[ -z "$all_projects" ]]; then
        log "No projects found"
        return 0
    fi

    local count=0
    local total
    total=$(echo "$all_projects" | wc -l)

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue
        count=$((count + 1))
        log "[$count/$total] $project"
        sync_project "$project"
    done <<< "$all_projects"

    # Sync labels after all projects are done
    sync_labels

    log "Full sync complete"
}

# Main
case "${1:-all}" in
    all)
        sync_all
        ;;
    project)
        [[ -z "${2:-}" ]] && die "Usage: $0 project <project-name>"
        sync_project "$2"
        sync_labels "$2"
        ;;
    list)
        echo "=== Vikunja Projects ==="
        get_vikunja_projects
        echo ""
        echo "=== Taskwarrior Projects ==="
        get_taskwarrior_projects
        ;;
    *)
        echo "Usage: $0 [all|project <name>|list]"
        exit 1
        ;;
esac
