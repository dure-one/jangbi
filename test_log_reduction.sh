#!/usr/bin/env bash
cd $(dirname $0)

echo "=== Log Volume Reduction Test ==="
echo
echo "This test runs the system for 2 minutes and measures log growth."
echo

# Baseline measurement
START_LINE=$(wc -l < output.log 2>/dev/null || echo 0)
START_TIME=$(date +%s)
START_SIZE=$(stat -c%s output.log 2>/dev/null || echo 0)

echo "Starting measurement:"
echo "  Time: $(date)"
echo "  Log lines: $START_LINE"
echo "  Log size: $START_SIZE bytes"
echo

# Run for 2 minutes (minmon runs checks every 30s, so we'll see 4 check cycles)
echo "Running for 2 minutes (4 check cycles)..."
sleep 120

# End measurement
END_LINE=$(wc -l < output.log)
END_TIME=$(date +%s)
END_SIZE=$(stat -c%s output.log)

echo
echo "Ending measurement:"
echo "  Time: $(date)"
echo "  Log lines: $END_LINE"
echo "  Log size: $END_SIZE bytes"
echo

# Calculate growth
LINE_GROWTH=$((END_LINE - START_LINE))
SIZE_GROWTH=$((END_SIZE - START_SIZE))
DURATION=$((END_TIME - START_TIME))

echo "Growth during test:"
echo "  Lines added: $LINE_GROWTH"
echo "  Bytes added: $SIZE_GROWTH"
echo "  Duration: $DURATION seconds"
echo "  Growth rate: $(echo "scale=2; $LINE_GROWTH * 60 / $DURATION" | bc) lines/minute"
echo

# Count check-related lines in the new entries
CHECK_LINES=$(tail -n $LINE_GROWTH output.log | grep -c "Checking\|is running\|Not loading" || echo 0)
echo "Check-related lines: $CHECK_LINES ($(echo "scale=1; $CHECK_LINES * 100 / $LINE_GROWTH" | bc 2>/dev/null || echo 0)% of total)"
echo

# Success criteria (rough estimates for 2 minutes)
# Before: ~80-120 lines (lots of check spam)
# After: ~20-40 lines (only errors and important events)
if [[ $LINE_GROWTH -lt 50 ]]; then
    echo "✓ PASS: Log growth is acceptably low ($LINE_GROWTH lines)"
    exit 0
else
    echo "⚠ WARNING: Log growth is higher than expected ($LINE_GROWTH lines)"
    echo "  Expected: < 50 lines for 2 minutes"
    echo "  This may indicate check functions are still logging routine OK messages"
    exit 1
fi
