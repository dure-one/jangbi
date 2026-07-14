# Logging System Enhancement Design

**Date:** 2026-07-14  
**Author:** Claude Sonnet 4.5  
**Status:** Approved for Implementation

---

## Problem Statement

The current logging system writes all operations to a single `output.log` file without rotation or verbosity control. This results in:

1. **Excessive log growth**: 468KB with 6,455 entries in current deployment
2. **Noisy check operations**: minmon runs `--check` every 30 seconds for each plugin, logging routine "OK" status
3. **No log retention policy**: logs accumulate indefinitely
4. **Poor signal-to-noise ratio**: debug messages from routine operations obscure important errors

**Target:** Reduce log volume by 70-90% during normal operation while maintaining full visibility during install/troubleshooting.

---

## Requirements

1. **Log retention**: Keep logs for 7 days, then automatically rotate/compress
2. **Verbosity reduction**: 
   - `--check` operations: error-only logging (silent when status is OK)
   - Install/first-boot: full verbose logging (debug + info)
   - Routine launches: info-level logging (reduced debug)
3. **Operation-aware logging**: automatically adjust verbosity based on operation type
4. **Backwards compatibility**: existing plugins continue working without changes
5. **Zero data loss**: log rotation must not disrupt active logging

---

## Architecture Overview

### Three-Layer Approach

#### Layer 1: Operation Mode Detection
Detect operation type at `init.sh` startup and set appropriate log level:

| Operation Mode | Trigger | Log Level | Behavior |
|----------------|---------|-----------|----------|
| `install` | `--install` flag | 6 (info+debug) | Verbose logging to file and stdout |
| `boot` | No flags (full init) | 6 (info+debug) | Verbose logging for first boot |
| `launch` | `--launch` flag | 5 (debug file-only) | Info to stdout, debug to file |
| `check` | `--check` flag | 4 (warning+error) | Error-only logging |

#### Layer 2: Conditional Check Logging
Introduce smart logging functions that suppress routine "OK" messages:

- `log_check()`: logs only in non-check modes or when there's an error
- `log_check_ok()`: silent in check mode, debug-level in other modes

#### Layer 3: Log Rotation
Standard logrotate configuration:
- Daily rotation
- Keep 7 days
- Compress with gzip
- Safe for concurrent writes

---

## Implementation Details

### 1. Operation Mode Detection (init.sh)

Add after argument parsing (around line 150):

```bash
# Detect operation mode and set log level accordingly
if [[ -n "${IN_OPTION}" ]]; then
    JANGBI_OPERATION_MODE="install"
    BASH_IT_LOG_LEVEL=6  # Verbose: info + debug
elif [[ -n "${CH_OPTION}" ]]; then
    JANGBI_OPERATION_MODE="check"
    BASH_IT_LOG_LEVEL=4  # Quiet: warning + error only
elif [[ -n "${RN_OPTION}" ]]; then
    JANGBI_OPERATION_MODE="launch"
    BASH_IT_LOG_LEVEL=5  # Medium: debug to file, info to stdout
elif [[ -z "${IN_OPTION}" && -z "${CH_OPTION}" && -z "${RN_OPTION}" ]]; then
    JANGBI_OPERATION_MODE="boot"
    BASH_IT_LOG_LEVEL=6  # Verbose: first boot needs full logs
else
    JANGBI_OPERATION_MODE="default"
    BASH_IT_LOG_LEVEL=5
fi
export JANGBI_OPERATION_MODE
```

**Why:** Centralizes operation mode detection. Export allows plugins to check mode if needed.

**How to apply:** This sets the foundation for all subsequent logging decisions. Plugins automatically inherit the correct log level through the existing `BASH_IT_LOG_LEVEL` mechanism.

### 2. New Logging Functions (jangbi_it.sh)

Add after existing log functions (around line 52):

```bash
# Conditional logging for check operations - only logs on errors or status changes
log_check() {
    if [[ "${JANGBI_OPERATION_MODE}" == "check" ]]; then
        # In check mode, only log if there's an error context
        # Plugins should call this with error messages only
        [[ "${BASH_IT_LOG_LEVEL:-0}" -ge "${BASH_IT_LOG_LEVEL_ERROR?}" ]] && log_warning "$@"
    else
        # In other modes, treat as debug
        log_debug "$@"
    fi
}

# Success messages for checks - only shown in verbose modes
log_check_ok() {
    if [[ "${JANGBI_OPERATION_MODE}" != "check" ]]; then
        log_debug "$@"
    fi
    # Silent in check mode when everything is OK
}
```

**Why:** Provides plugins with semantic logging functions that automatically adjust to operation mode. `log_check()` ensures errors are always visible while `log_check_ok()` suppresses noise.

**How to apply:** Plugins call `log_check_ok("service is running")` for success states and `log_check("service failed")` for errors. The functions handle mode detection internally.

### 3. Plugin Check Function Pattern

Example migration for `__net-dnsmasq_check()`:

**Before:**
```bash
function __net-dnsmasq_check {
    log_debug "Checking ${DMNNAME}..."
    
    if [[ -z "${RUN_NET_DNSMASQ}" ]]; then
        log_error "RUN_NET_DNSMASQ variable is not set."
        running_status=10
        return
    fi
    
    if [[ $(pidof dnsmasq 2>/dev/null | wc -w) -gt 0 ]]; then
        log_info "dnsmasq is running."
        running_status=1
    else
        log_info "dnsmasq is not running."
        running_status=0
    fi
}
```

**After:**
```bash
function __net-dnsmasq_check {
    log_check_ok "Checking ${DMNNAME}..."  # Silent in check mode
    
    if [[ -z "${RUN_NET_DNSMASQ}" ]]; then
        log_error "RUN_NET_DNSMASQ variable is not set."  # Always logged
        running_status=10
        return
    fi
    
    if [[ $(pidof dnsmasq 2>/dev/null | wc -w) -gt 0 ]]; then
        log_check_ok "dnsmasq is running."  # Silent in check mode
        running_status=1
    else
        log_check "dnsmasq is not running."  # Logged as warning in check mode
        running_status=0
    fi
}
```

**Migration strategy:** Update plugins incrementally. Priority order:
1. High-frequency checks (dnsmasq, suricata, wactws)
2. Medium-frequency checks (redis, minmon)
3. Low-frequency or manual plugins

### 4. Logrotate Configuration

Create `/etc/logrotate.d/jangbi`:

```
/opt/jangbi/output.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        # No service restart needed - append-only log
    endscript
}
```

**Configuration details:**
- `daily`: rotate at midnight
- `rotate 7`: keep 7 daily archives
- `compress`: gzip old logs (saves ~80% space)
- `delaycompress`: don't compress most recent rotation (easier to read)
- `missingok`: don't error if log file missing
- `notifempty`: skip rotation if log is empty
- `create 0644 root root`: recreate log with correct permissions

**Installation:** Add logrotate config installation to `os-conf` plugin or create a new `os-logrotate` plugin.

---

## Error Handling and Edge Cases

### Backwards Compatibility
- Existing plugins without `log_check()` updates continue working
- They use existing `log_debug()`/`log_info()` which respect `BASH_IT_LOG_LEVEL`
- No breaking changes to plugin API

### Log Rotation Safety
- Logrotate uses `create` method (atomic rename + new file creation)
- Processes keep writing to old inode until they reopen (append-only logs handle this gracefully)
- No data loss during rotation
- If logrotate fails, logs continue appending

### Operation Mode Priority
Multiple flags scenario (e.g., `--check enabled --install enabled`):
- Priority: `install` > `launch` > `check`
- First matched flag sets the mode
- Rare in practice (scripts typically use one flag)

### Check Function State
- `running_status` remains global (existing pattern)
- Error states (10, 15, 20) always log via `log_error()` or `log_check()`
- Success states (1) silent in check mode via `log_check_ok()`
- Install-required states (5, 15) logged as warnings

### Concurrent Execution
- Multiple `init.sh --check` instances run concurrently (via minmon)
- Each uses same log file
- `tee -a` provides atomic append (safe for concurrent writes)
- Lock mechanism prevents concurrent install/launch operations
- No state file needed (stateless design)

### Missing Dependencies
- Add `logrotate` to required packages in `os-conf` plugin
- Graceful degradation: if logrotate missing, logs still work (just grow unbounded)

---

## Testing Strategy

### Unit Tests

**Test operation mode detection:**
```bash
# Test 1: Install mode
./init.sh --install net-dnsmasq
# Verify: JANGBI_OPERATION_MODE=install, BASH_IT_LOG_LEVEL=6

# Test 2: Check mode
./init.sh --check net-dnsmasq
# Verify: JANGBI_OPERATION_MODE=check, BASH_IT_LOG_LEVEL=4

# Test 3: Launch mode
./init.sh --launch net-dnsmasq
# Verify: JANGBI_OPERATION_MODE=launch, BASH_IT_LOG_LEVEL=5

# Test 4: Boot mode
./init.sh
# Verify: JANGBI_OPERATION_MODE=boot, BASH_IT_LOG_LEVEL=6
```

**Test log functions:**
```bash
# In check mode, verify silence
export JANGBI_OPERATION_MODE=check
export BASH_IT_LOG_LEVEL=4
log_check_ok "This should not appear"  # Silent
log_check "This should appear as warning"  # Logged

# In install mode, verify verbosity
export JANGBI_OPERATION_MODE=install
export BASH_IT_LOG_LEVEL=6
log_check_ok "This should appear as debug"  # Logged
log_check "This should appear as debug"  # Logged
```

### Integration Tests

**Test 1: Normal operation log reduction**
```bash
# Baseline: measure current log growth
wc -l output.log  # Record starting line count
sleep 300  # 5 minutes
wc -l output.log  # Record ending line count
# Calculate lines per minute

# After implementation: measure new log growth
wc -l output.log  # Record starting line count
sleep 300  # 5 minutes (minmon runs checks every 30s)
wc -l output.log  # Record ending line count
# Expected: 70-90% reduction in growth rate
```

**Test 2: Error detection and logging**
```bash
# Kill a monitored service
systemctl stop dnsmasq  # or pkill dnsmasq

# Wait for minmon to detect (60 seconds worst case)
sleep 70

# Verify error is logged
tail -20 output.log | grep "dnsmasq is not running"
# Expected: error message appears
```

**Test 3: Service recovery logging**
```bash
# Start service
./init.sh --launch net-dnsmasq

# Verify recovery is logged once
tail -20 output.log | grep "dnsmasq"
# Expected: startup messages visible

# Wait for multiple check cycles
sleep 120

# Verify no repeated "running" messages
tail -50 output.log | grep -c "dnsmasq is running"
# Expected: 0 or 1 (not 4-6)
```

### Log Rotation Tests

**Test 1: Manual rotation**
```bash
# Trigger rotation manually
logrotate -f /etc/logrotate.d/jangbi

# Verify old log compressed
ls -lh output.log*
# Expected: output.log (new), output.log.1 (uncompressed), output.log.2.gz (compressed)

# Verify new log created with correct permissions
stat -c "%a %U:%G" output.log
# Expected: 644 root:root
```

**Test 2: Continuous logging during rotation**
```bash
# Start background logging process
while true; do echo "Test log entry" >> output.log; sleep 1; done &
BG_PID=$!

# Trigger rotation
logrotate -f /etc/logrotate.d/jangbi

# Wait and check
sleep 5
kill $BG_PID

# Verify no log entries lost
# Expected: all entries present across output.log and output.log.1
```

**Test 3: 7-day retention**
```bash
# Create mock old logs
for i in {1..10}; do
    touch -d "$i days ago" output.log.$i.gz
done

# Run rotation
logrotate -f /etc/logrotate.d/jangbi

# Verify only 7 kept
ls output.log.*.gz | wc -l
# Expected: 7 or fewer
```

### Before/After Comparison

**Baseline measurement (current system):**
1. Fresh boot
2. Run for 1 hour
3. Measure:
   - Total log lines: `wc -l output.log`
   - Log file size: `du -h output.log`
   - Check-related lines: `grep -c "Checking\|is running\|Not loading" output.log`

**After implementation:**
1. Fresh boot with new logging system
2. Run for 1 hour
3. Measure same metrics
4. Expected results:
   - 70-90% reduction in total log lines
   - 60-80% reduction in file size
   - ~95% reduction in check-related lines

---

## Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Add operation mode detection to `init.sh` (after argument parsing)
- [ ] Add `log_check()` and `log_check_ok()` functions to `jangbi_it.sh`
- [ ] Test operation mode detection with unit tests
- [ ] Test new log functions with unit tests

### Phase 2: Plugin Migration
- [ ] Update `net-dnsmasq` plugin check function
- [ ] Update `net-suricata` plugin check function
- [ ] Update `net-wactws` plugin check function
- [ ] Update `net-dnscryptproxy` plugin check function
- [ ] Update `os-minmon` plugin check function
- [ ] Update `os-redis` plugin check function
- [ ] Update remaining plugins as needed

### Phase 3: Log Rotation
- [ ] Create `/etc/logrotate.d/jangbi` configuration
- [ ] Add logrotate to required packages (in `os-conf` plugin)
- [ ] Test manual rotation with `logrotate -f`
- [ ] Verify rotation during active logging

### Phase 4: Integration Testing
- [ ] Run full system for 1 hour, measure log reduction
- [ ] Test error detection and logging
- [ ] Test service recovery scenarios
- [ ] Verify 7-day retention works correctly

### Phase 5: Documentation
- [ ] Update CLAUDE.md with new logging behavior
- [ ] Document operation modes for plugin developers
- [ ] Add troubleshooting guide for log rotation issues

---

## Rollback Plan

If the enhanced logging system causes issues:

1. **Immediate rollback:**
   ```bash
   # Revert init.sh changes (operation mode detection)
   git revert <commit-hash>
   
   # Revert jangbi_it.sh changes (log functions)
   git revert <commit-hash>
   
   # Remove logrotate config
   rm /etc/logrotate.d/jangbi
   ```

2. **Temporary override:**
   ```bash
   # Force verbose logging for all operations
   export BASH_IT_LOG_LEVEL=6
   export JANGBI_OPERATION_MODE=boot
   ./init.sh
   ```

3. **Plugin-level rollback:**
   - Plugins without migration continue working (backwards compatible)
   - Revert individual plugin commits to restore old behavior

---

## Success Metrics

1. **Log volume reduction**: 70-90% fewer lines during normal operation
2. **Signal preservation**: All errors still logged (0% data loss)
3. **Zero service disruption**: Log rotation doesn't affect running services
4. **Backwards compatibility**: Existing plugins work without changes
5. **Developer satisfaction**: Easier to find relevant information in logs

---

## Future Enhancements

Potential improvements beyond this design:

1. **Structured logging**: JSON format for machine parsing
2. **Log levels per plugin**: Override global level for specific plugins
3. **Remote logging**: Ship logs to central syslog/Loki server
4. **Log analysis**: Automatic error pattern detection
5. **Metrics extraction**: Parse logs to generate Prometheus metrics

These are out of scope for the current design but could be considered in future iterations.
