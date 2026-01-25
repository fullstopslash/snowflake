---
phase: 07-vikunja-hardening
plan: 02
type: summary
---

# Summary: Hook Validation & jaq Migration

## Tasks Completed

### Task 1: Add binary existence validation after command -v
- Added `|| true` to all `command -v` calls to prevent exit on missing binaries
- Added fail-open validation block in both hooks:
  ```sh
  if [ -z "$VIKUNJA_DIRECT" ] || [ -z "$JAQ" ]; then
    echo "$task_json"  # Output task unchanged
    exit 0             # Fail open - don't block task operations
  fi
  ```
- Hooks now gracefully degrade when binaries are missing

### Task 2: Replace jq with jaq throughout
- Changed variable name: `JQ` -> `JAQ`
- Changed command lookup: `command -v jq` -> `command -v jaq`
- Changed all invocations: `"$JQ"` -> `"$JAQ"`
- Updated service paths to include `pkgs.jaq` instead of `pkgs.jq`
- Services updated:
  - vikunja-sync
  - vikunja-reconcile
  - vikunja-sync-project
  - vikunja-sync-retry
  - vikunja-provision-webhooks

### Task 3: Use jaq --arg for safe value interpolation
- Changed project assignment from direct string interpolation:
  ```sh
  # Before (unsafe)
  "$JAQ" -c '.project = "${cfg.defaultProject}"'

  # After (safe)
  "$JAQ" -c --arg proj "${cfg.defaultProject}" '.project = $proj'
  ```
- Applied to on-add-vikunja hook where default project is set
- Webhook provisioning script also uses `--arg` for URL and secret

## Verification

- [x] `nix-instantiate --parse` succeeds on module
- [x] Generated hooks contain binary validation with fail-open pattern
- [x] All service paths reference `pkgs.jaq`, not `pkgs.jq`
- [x] jaq invocations use `--arg` for Nix-interpolated values

## Files Modified

- `roles/vikunja-sync.nix`
  - Updated on-add-vikunja hook
  - Updated on-modify-vikunja hook
  - Updated on-exit-vikunja hook
  - Updated all service path attributes
- `roles/vikunja-webhook.nix`
  - Updated provisionWebhooksScript to use jaq
  - Updated service path for provisioning
