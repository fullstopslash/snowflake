---
phase: 07-vikunja-hardening
plan: 03
type: summary
---

# Summary: Webhook Service Resilience

## Tasks Completed

### Task 1: Fix webhook payload loss on processing failure
- Changed from `ExecStartPost` (unconditional deletion) to inline bash with `&&`:
  ```nix
  # Before (loses payload on failure)
  ExecStart = "${vikunjaDirectPkg}/bin/vikunja-direct webhook ${queueDir}/%i";
  ExecStartPost = "${pkgs.coreutils}/bin/rm -f ${queueDir}/%i";

  # After (preserves payload on failure)
  ExecStart = "${pkgs.bash}/bin/bash -c '${vikunjaDirectPkg}/bin/vikunja-direct webhook ${queueDir}/%i && rm -f ${queueDir}/%i'";
  ```
- Payload file preserved on failure for debugging/manual retry
- Only deleted after successful processing

### Task 2: Add service timeouts to prevent hung processes
Added `TimeoutStartSec` to all oneshot services:

| Service | Timeout | Rationale |
|---------|---------|-----------|
| vikunja-webhook-process@ | 60s | Single webhook, should be <5s |
| vikunja-sync | 300s (5min) | Full sync, many tasks |
| vikunja-reconcile | 300s (5min) | Full reconciliation |
| vikunja-sync-project | 120s (2min) | Single project sync |
| vikunja-sync-retry | 120s (2min) | Queue processing |
| vikunja-provision-webhooks | 120s (2min) | API calls to all projects |

### Task 3: Add timeout wrapper to background hook processes
- Wrapped all `setsid` background processes with `timeout 30`:
  ```sh
  timeout 30 sh -c "echo \"\$1\" | \"\$2\" hook" _ "$1" "$2" >> "$5/direct.log" 2>&1
  ```
- Applied to:
  - on-add-vikunja hook (sync call)
  - on-modify-vikunja hook (sync/delete-hook call)
  - TaskChampion sync calls
- Prevents orphaned background processes from accumulating

## Verification

- [x] `nix build --dry-run` succeeds
- [x] vikunja-webhook-process@ service has TimeoutStartSec = 60
- [x] All sync services have appropriate TimeoutStartSec
- [x] Hook background processes wrapped with `timeout 30`
- [x] Webhook payload deletion is conditional on success

## Files Modified

- `roles/vikunja-webhook.nix`
  - Changed vikunja-webhook-process@ ExecStart to conditional deletion
  - Added TimeoutStartSec to vikunja-webhook-process@
  - Added TimeoutStartSec to vikunja-provision-webhooks
- `roles/vikunja-sync.nix`
  - Added TimeoutStartSec to vikunja-sync, vikunja-reconcile, vikunja-sync-project, vikunja-sync-retry
  - Added timeout wrapper to on-add-vikunja setsid block
  - Added timeout wrapper to on-modify-vikunja setsid block
