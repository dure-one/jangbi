# Lock Mechanism for Base Operations

## Problem

Previously, when `minmon` ran `./init.sh --check <plugin>` every 30 seconds, these check operations would execute even while base operations (full init, install, launch) were running. This created several issues:

1. Check operations don't provide meaningful information while the system is being reconfigured
2. Concurrent execution could cause race conditions
3. Unnecessary resource consumption during critical operations

## Solution

Implemented a file-based lock mechanism that:

1. **Blocks check operations** when base operations are running
2. **Prevents concurrent base operations** from interfering with each other
3. **Handles stale locks** from processes that died without cleanup

## Implementation

### Lock Files

- `/tmp/jangbi_base_operation.lock` - Lock file indicating a base operation is running
- `/tmp/jangbi_base_operation.pid` - Contains the PID of the process holding the lock

### Lock Functions

**`_acquire_lock()`**
- Called by base operations (install, launch, full init, download, sync)
- For check operations: returns 1 immediately if lock exists (skip)
- For base operations: waits briefly, then fails if lock is held
- Detects and removes stale locks from dead processes
- Creates lock files with current PID

**`_release_lock()`**
- Removes both lock files
- Called automatically via `trap` on EXIT, INT, TERM

### Operation Types

**Base Operations** (acquire lock):
- Full init (no arguments)
- `--launch`
- `--install`
- `--download`
- `--sync`

**Check Operations** (skip if locked):
- `--check enabled`
- `--check <plugin-name>`

## Behavior

### When check runs during base operation:

```bash
$ ./init.sh --check net-dnsmasq
DEBUG: core: main: Base operation in progress (PID: 12345), skipping check
```

Exit code: 0 (success, but skipped)

### When base operation encounters another base operation:

```bash
$ ./init.sh --install enabled
ERROR: core: main: Failed to acquire lock. Another operation is in progress.
```

Exit code: 1 (failure)

### When stale lock is detected:

```bash
WARNING: core: main: Removing stale lock from dead process 12345
```

The operation continues after cleanup.

## minmon Integration

When `minmon` runs checks every 30 seconds:

1. If a base operation is running → check exits immediately with log message
2. If no base operation → check runs normally
3. Stale locks are automatically cleaned up

This ensures `minmon` never interferes with system reconfiguration while still monitoring services when the system is idle.

## Testing

```bash
# Test 1: Check works normally
./init.sh --check net-dnsmasq

# Test 2: Start base operation in background, check is blocked
./init.sh --sync &
sleep 1
./init.sh --check net-dnsmasq  # Should skip

# Test 3: After base operation completes, check works
wait
./init.sh --check net-dnsmasq  # Should work
```

## Code Changes

Modified `/opt/jangbi/init.sh`:

1. Added lock file path definitions at top
2. Added `_acquire_lock()` and `_release_lock()` functions
3. Added lock detection after argument parsing
4. Added `trap` to ensure lock cleanup on exit
5. Check operations now exit early if lock is detected

## Commit Date

2026-06-22
