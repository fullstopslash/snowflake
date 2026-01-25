---
phase: 09-vikunja-sync-fixes
plan: 04
type: summary
---

# Summary: Circuit Breaker for API Resilience

**Implemented circuit breaker pattern to fail fast during API outages.**

## Accomplishments

- Added `CircuitBreaker` class with persistent state
- Added `CircuitBreakerOpen` exception
- Integrated circuit breaker into `VikunjaClient`
- Handle circuit breaker in `push_to_vikunja()`
- Added circuit breaker status to `vikunja-direct diagnose`

## Files Modified

- `pkgs/vikunja-sync/vikunja_common.py`
  - Added `CircuitBreakerOpen` exception class
  - Added `CircuitBreaker` class with persistent state
  - Integrated into `VikunjaClient._request()`

- `pkgs/vikunja-sync/vikunja-direct.py`
  - Import `CircuitBreakerOpen` and `CircuitBreaker`
  - Handle `CircuitBreakerOpen` in `push_to_vikunja()`
  - Added circuit breaker status to `cmd_diagnose()`

## Technical Details

### Circuit Breaker States

```
CLOSED (normal) -> OPEN (after 3 failures) -> HALF-OPEN (test) -> CLOSED
```

- **CLOSED**: Normal operation, all requests allowed
- **OPEN**: After 3 consecutive failures, fails immediately (no API call)
- **HALF-OPEN**: After 60s recovery timeout, allows one test request

### Persistent State

State is persisted to `~/.local/state/vikunja-sync/circuit_breaker.json`:

```json
{
  "failures": 0,
  "last_failure_time": 0.0,
  "state": "closed"
}
```

This allows circuit breaker state to survive across process restarts and be shared between webhook handlers.

### Integration Points

1. **VikunjaClient._request()**: Checks circuit breaker before making request, records success/failure
2. **push_to_vikunja()**: Catches `CircuitBreakerOpen`, returns appropriate error
3. **cmd_diagnose()**: Shows circuit breaker status

### Diagnose Output

```
=== Circuit Breaker ===
  State: CLOSED (normal)
  Consecutive failures: 0
```

Or when open:
```
=== Circuit Breaker ===
  State: OPEN (failing fast)
  Failures: 3
  Recovery in: 45s
```

## Verification

- [x] Python syntax valid
- [x] NixOS rebuild successful
- [x] Circuit breaker status in diagnose
- [x] State persists to file
