#!/usr/bin/env bash
cd $(dirname $0)

echo "=== Log Rotation Test ==="
echo

# Test 1: Manual rotation works
echo "Test 1: Manual rotation"
echo "  Creating test log entries..."
for i in {1..10}; do
    echo "[$(date)] Test log entry $i" >> output.log
done

echo "  Triggering rotation..."
logrotate -f /etc/logrotate.d/jangbi

if [[ -f output.log.1 ]]; then
    echo "  ✓ PASS: Rotated log created (output.log.1)"
else
    echo "  ✗ FAIL: Rotated log not found"
    exit 1
fi

if [[ -f output.log ]]; then
    echo "  ✓ PASS: New log file created (output.log)"
else
    echo "  ✗ FAIL: New log file not created"
    exit 1
fi
echo

# Test 2: Log continues after rotation
echo "Test 2: Logging continues after rotation"
echo "[$(date)] Post-rotation test entry" >> output.log
if grep -q "Post-rotation test entry" output.log; then
    echo "  ✓ PASS: Can write to new log file"
else
    echo "  ✗ FAIL: Cannot write to new log file"
    exit 1
fi
echo

# Test 3: Permissions are correct
echo "Test 3: File permissions"
PERMS=$(stat -c "%a" output.log)
OWNER=$(stat -c "%U:%G" output.log)
if [[ "$PERMS" == "644" && "$OWNER" == "root:root" ]]; then
    echo "  ✓ PASS: Permissions are correct (644 root:root)"
else
    echo "  ✗ FAIL: Permissions are incorrect ($PERMS $OWNER)"
    exit 1
fi
echo

# Test 4: 7-day retention
echo "Test 4: 7-day retention policy"
echo "  Removing existing archives..."
rm -f output.log.*.gz output.log.[0-9]* 2>/dev/null

echo "  Creating mock old logs..."
for i in {2..10}; do
    touch -d "$i days ago" output.log.$i.gz
done

echo "  Running rotation..."
logrotate -f /etc/logrotate.d/jangbi

REMAINING=$(ls output.log.*.gz 2>/dev/null | wc -l)
if [[ $REMAINING -le 7 ]]; then
    echo "  ✓ PASS: Retention policy enforced ($REMAINING archives kept)"
else
    echo "  ✗ FAIL: Too many archives kept ($REMAINING > 7)"
    exit 1
fi
echo

# Cleanup mock logs
rm -f output.log.*.gz output.log.[0-9]* 2>/dev/null

echo "All log rotation tests passed!"
