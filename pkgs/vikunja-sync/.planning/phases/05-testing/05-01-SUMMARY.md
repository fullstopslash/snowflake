# Phase 5: Testing & Validation - Test Plan Documentation

**Status:** Tests documented; to be run after nixos-rebuild deploys the changes

**Purpose:** End-to-end integration testing of all sync scenarios to verify bug fixes and ensure bidirectional sync reliability.

---

## Pre-requisites

Before running these tests:
1. Run `nixos-rebuild switch` to deploy the updated vikunja-sync service
2. Verify the service is running: `systemctl status vikunja-sync.timer`
3. Set environment variables for test commands:
   ```bash
   export VIKUNJA_URL="https://your-vikunja-instance.example.com"
   export TOKEN="$(cat /path/to/vikunja-api-token)"
   ```

---

## Test Checklist

### Task 1: TW -> Vikunja Sync Scenarios

These tests verify that changes made in Taskwarrior propagate correctly to Vikunja.

- [ ] **1.1 Create task with tags**
  - **Command:**
    ```bash
    task add "Test TW->V create" project:SyncTest +alpha +beta
    sleep 3
    ```
  - **Verification:**
    ```bash
    curl -s -H "Authorization: Bearer $TOKEN" "$VIKUNJA_URL/api/v1/tasks?filter=title:Test%20TW" | jq '.[] | {title, labels}'
    ```
  - **Expected outcome:** Task exists in Vikunja with labels "alpha" and "beta"

- [ ] **1.2 Add tag to existing task**
  - **Command:**
    ```bash
    task <id> modify +gamma
    sleep 3
    ```
  - **Verification:** Check Vikunja task via API - should now have label "gamma" in addition to existing labels
  - **Expected outcome:** Label "gamma" added to the Vikunja task

- [ ] **1.3 Remove tag from task** (CRITICAL - this was the broken behavior)
  - **Command:**
    ```bash
    task <id> modify -alpha
    sleep 3
    ```
  - **Verification:**
    ```bash
    curl -s -H "Authorization: Bearer $TOKEN" "$VIKUNJA_URL/api/v1/tasks/<vikunja_task_id>" | jq '.labels'
    ```
  - **Expected outcome:** Label "alpha" REMOVED from Vikunja; only "beta" and "gamma" remain
  - **Note:** This tests the critical bidirectional tag sync fix

- [ ] **1.4 Complete task**
  - **Command:**
    ```bash
    task <id> done
    sleep 3
    ```
  - **Verification:** Check Vikunja task done status via API or UI
  - **Expected outcome:** Task marked as done in Vikunja

- [ ] **1.5 Delete task**
  - **Command:**
    ```bash
    task add "Delete test" project:SyncTest
    sleep 2
    task <id> delete
    sleep 3
    ```
  - **Verification:** Task should no longer exist in Vikunja
  - **Expected outcome:** Task deleted from Vikunja

---

### Task 2: Vikunja -> TW Sync Scenarios

These tests verify that changes made in Vikunja propagate correctly to Taskwarrior. Note: These require either webhook triggers or manual sync invocation.

- [ ] **2.1 Create task with labels in Vikunja**
  - **Command:**
    ```bash
    # Create task via Vikunja API
    curl -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      "$VIKUNJA_URL/api/v1/projects/<project_id>/tasks" \
      -d '{"title": "Test V->TW create"}'

    # Add labels to the task via Vikunja UI or API
    # Trigger label-sync or wait for scheduled sync
    ```
  - **Verification:**
    ```bash
    task project:SyncTest export | jq '.[] | {description, tags}'
    ```
  - **Expected outcome:** Task exists in Taskwarrior with corresponding tags

- [ ] **2.2 Add label in Vikunja**
  - **Command:** Add a new label to an existing Vikunja task via UI or API
  - **Trigger:** Run label-sync manually or wait for scheduled sync
  - **Verification:** `task <uuid> info` - check tags
  - **Expected outcome:** Tag added to Taskwarrior task

- [ ] **2.3 Remove label in Vikunja** (CRITICAL - this was the broken behavior)
  - **Command:** Remove a label from a Vikunja task via UI or API
  - **Trigger:** Run label-sync manually or wait for scheduled sync
  - **Verification:** `task <uuid> info` - check tags
  - **Expected outcome:** Tag REMOVED from Taskwarrior task
  - **Note:** This tests the critical bidirectional tag sync fix

---

### Task 3: Error Handling and Resilience Tests

These tests verify that the sync suite handles errors gracefully without data loss or silent failures.

- [ ] **3.1 API failure handling**
  - **Setup:** Temporarily misconfigure Vikunja URL or take service offline
  - **Test:**
    ```bash
    task add "API failure test" project:SyncTest
    # Observe logs for error handling
    journalctl -u vikunja-sync --since "1 minute ago"
    ```
  - **Verification:** Error should be logged, task queued for retry (not silently dropped)
  - **Expected outcome:** Failure is logged; task syncs successfully after connectivity restored

- [ ] **3.2 Subprocess failure logging**
  - **Test:** Attempt to complete or modify a non-existent task
    ```bash
    # Check logs for error output
    journalctl -u vikunja-sync -f
    ```
  - **Expected outcome:** Subprocess errors are logged (not silently swallowed)

- [ ] **3.3 No credential exposure**
  - **Test:** While sync is running, check for credentials in process list:
    ```bash
    ps aux | grep -E "vikunja|correlate" | grep -v grep
    ```
  - **Expected outcome:** No passwords, tokens, or API keys visible in command line arguments
  - **Note:** Credentials should be read from files, not passed via CLI

- [ ] **3.4 Large batch test** (optional, if time permits)
  - **Command:**
    ```bash
    for i in $(seq 1 50); do task add "Batch test $i" project:BatchTest; done
    # Wait for sync to complete
    sleep 120
    ```
  - **Verification:** All 50 tasks should appear in Vikunja
  - **Expected outcome:** Sync completes without timeout, memory issues, or errors

---

## Test Script Outline

For convenience, here is an outline of a test script that can be run after deployment:

```bash
#!/usr/bin/env bash
# vikunja-sync-integration-tests.sh
# Run after: nixos-rebuild switch

set -e

VIKUNJA_URL="${VIKUNJA_URL:-https://vikunja.example.com}"
TOKEN="${TOKEN:-$(cat ~/.config/vikunja/token)}"
PROJECT="SyncTest"

echo "=== Vikunja-Sync Integration Tests ==="
echo "Note: Tests must be verified manually after running commands"
echo ""

# Test 1.1: Create task with tags
echo "[TEST 1.1] Creating task with tags..."
TASK_UUID=$(task add "Integration Test $(date +%s)" project:$PROJECT +test +alpha +beta 2>&1 | grep -oP 'Created task [0-9a-f-]+' | cut -d' ' -f3)
echo "Created task: $TASK_UUID"
echo "Waiting 5 seconds for sync..."
sleep 5

# Test 1.3: Remove tag
echo "[TEST 1.3] Removing tag..."
task "$TASK_UUID" modify -alpha
sleep 5
echo "Verify in Vikunja: 'alpha' label should be REMOVED"

# Test 3.3: Credential check
echo "[TEST 3.3] Checking for credential exposure..."
if ps aux | grep -E "vikunja|correlate|label-sync" | grep -v grep | grep -qiE "password|token|secret|key"; then
    echo "FAIL: Credentials visible in process list!"
else
    echo "PASS: No credentials visible in process list"
fi

echo ""
echo "=== Manual verification required ==="
echo "- Check Vikunja UI for test tasks"
echo "- Verify labels synced correctly"
echo "- Check journalctl for any sync errors"
```

---

## Summary of Critical Tests

| Test | Description | Verifies Bug Fix |
|------|-------------|------------------|
| 1.3 | Remove tag from TW task | Bidirectional tag sync (was broken) |
| 2.3 | Remove label from Vikunja task | Bidirectional tag sync (was broken) |
| 3.2 | Subprocess failure logging | Silent failure masking (was broken) |
| 3.3 | No credential exposure | Credential exposure via CLI (was broken) |

---

## Next Steps

1. Run `nixos-rebuild switch` to deploy the updated vikunja-sync service
2. Execute the test scenarios documented above
3. Document pass/fail results
4. If all tests pass: Update ROADMAP.md to mark Phase 5 complete
5. Update BRIEF.md to reflect v1.1 as shipped

---

**Tests to be run after nixos-rebuild deploys the changes**
