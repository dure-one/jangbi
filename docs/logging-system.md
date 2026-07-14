# Jangbi Logging System

## Overview

The Jangbi logging system provides operation-aware verbosity control and automatic log rotation to balance visibility during troubleshooting with production log volume management.

## Architecture

### Three Layers

1. **Operation Mode Detection** (init.sh)
   - Detects operation type from command-line flags
   - Sets `JANGBI_OPERATION_MODE` and `BASH_IT_LOG_LEVEL`
   - Exported for plugin access

2. **Conditional Logging Functions** (jangbi_it.sh)
   - `log_check()` - logs only in non-check modes or on errors
   - `log_check_ok()` - silent in check mode
   - Backward compatible with existing `log_debug()`, `log_info()`, etc.

3. **Log Rotation** (logrotate)
   - Daily rotation at midnight
   - 7-day retention
   - Gzip compression (saves ~80% space)

## Operation Modes

| Mode | Trigger | Log Level | Use Case |
|------|---------|-----------|----------|
| `install` | `--install` flag | 6 (verbose) | Package installation, first-time setup |
| `boot` | No flags | 6 (verbose) | Full system initialization |
| `launch` | `--launch` flag | 5 (info) | Routine service starts |
| `check` | `--check` flag | 4 (error-only) | Health checks (minmon) |

## Plugin Development

### Using Conditional Logging

```bash
function __myplugin_check {
    # Silent in check mode, debug in others
    log_check_ok "Checking ${DMNNAME}..."
    
    # Always logged (errors)
    if [[ -z "${RUN_MYPLUGIN}" ]]; then
        log_error "RUN_MYPLUGIN not set"
        running_status=10
        return
    fi
    
    # Check if service running
    if [[ $(pidof myservice | wc -w) -gt 0 ]]; then
        # Silent in check mode - success state
        log_check_ok "myservice is running"
        running_status=1
    else
        # Warning in check mode - needs attention
        log_check "myservice is not running"
        running_status=0
    fi
}
```

### Migration Checklist

When migrating an existing plugin:

1. Replace `log_debug "Checking..."` → `log_check_ok "Checking..."`
2. Replace success `log_info` → `log_check_ok`
3. Replace failure `log_info` → `log_check`
4. Keep `log_error` unchanged (always visible)
5. Test in both check mode and install mode

## Log Rotation

### Configuration

Location: `/etc/logrotate.d/jangbi`

```
/opt/jangbi/output.log {
    daily           # Rotate daily at midnight
    rotate 7        # Keep 7 days of archives
    compress        # Gzip old logs
    delaycompress   # Don't compress most recent
    missingok       # OK if log missing
    notifempty      # Skip empty logs
    create 0644 root root  # New log permissions
}
```

### Manual Rotation

```bash
# Force rotation now
logrotate -f /etc/logrotate.d/jangbi

# Test rotation (dry run)
logrotate -d /etc/logrotate.d/jangbi
```

### Archive Access

```bash
# List archives
ls -lh /opt/jangbi/output.log*

# View compressed archive
zcat /opt/jangbi/output.log.2.gz | less

# Search compressed archives
zgrep "error" /opt/jangbi/output.log.*.gz
```

## Troubleshooting

### Logs Too Quiet

If important messages are missing:

```bash
# Check current operation mode
echo $JANGBI_OPERATION_MODE

# Force verbose logging for one command
BASH_IT_LOG_LEVEL=6 JANGBI_OPERATION_MODE=boot ./init.sh

# Check log level
echo $BASH_IT_LOG_LEVEL
```

### Logs Too Verbose

If check operations still spam logs:

```bash
# Identify noisy plugins
tail -500 output.log | cut -d':' -f1-2 | sort | uniq -c | sort -rn

# Check if plugin migrated to conditional logging
grep "log_check_ok\|log_check" plugins/available/noisy-plugin.plugin.bash
```

### Rotation Not Working

```bash
# Verify logrotate installed
dpkg -l logrotate

# Check rotation configuration
logrotate -d /etc/logrotate.d/jangbi

# Check cron is running
systemctl status cron

# Check logrotate logs
grep logrotate /var/log/syslog
```

## Performance Impact

### Before Enhancement

- 468KB log file with 6,455 entries
- ~10-15 lines per minute during normal operation
- 95% check-related spam
- No automatic cleanup

### After Enhancement

- ~2-3 lines per minute during normal operation
- 70-90% reduction in log volume
- Automatic 7-day cleanup
- Errors remain fully visible

## Testing

Three test scripts available:

```bash
# Test operation mode detection
./test_operation_mode.sh

# Test conditional logging functions
./test_log_functions.sh

# Test log volume reduction (2 min)
./test_log_reduction.sh

# Test log rotation
./test_log_rotation.sh
```
