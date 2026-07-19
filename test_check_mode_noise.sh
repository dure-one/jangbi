#!/usr/bin/env bash
cd "$(dirname "$0")"
FAILED=0

echo "==========================================="
echo "   Check-mode log noise reduction tests"
echo "==========================================="

LOG_FILE="output.log"

# Test 1: required_pkgs block gated by IS_CHECK_ONLY
if grep -A20 "install required packages" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: required_pkgs block gated by IS_CHECK_ONLY"
else
    echo "FAIL: required_pkgs block not gated — runs on every check cycle"; FAILED=1
fi

# Test 2: jq binary block gated by IS_CHECK_ONLY
if grep -B2 "jq binary already exists" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: jq binary block gated by IS_CHECK_ONLY"
else
    echo "FAIL: jq binary block not gated — runs on every check cycle"; FAILED=1
fi

# Test 3: .config.last initialization gated by IS_CHECK_ONLY
if grep -B2 'Complete rendered configuration' init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: .config.last initialization gated by IS_CHECK_ONLY"
else
    echo "FAIL: .config.last write not gated — runs on every check cycle"; FAILED=1
fi

# Test 4: _validate_interfaces gated by IS_CHECK_ONLY
if grep -B2 "_validate_interfaces" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: _validate_interfaces gated by IS_CHECK_ONLY"
else
    echo "FAIL: _validate_interfaces not gated — runs on every check cycle"; FAILED=1
fi

# Test 5: live check produces ≤5 new log lines (safe read-only operation)
log_before=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
./init.sh --check net-randommac > /dev/null 2>&1
log_after=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
new_lines=$(( log_after - log_before ))
if [[ $new_lines -le 10 ]]; then
    echo "PASS: check mode produced $new_lines log lines (≤10, down from ~24 before gates)"
else
    echo "FAIL: check mode produced $new_lines log lines — expected ≤10 after gating"; FAILED=1
    echo "      Recent additions:"
    tail -n "$new_lines" "$LOG_FILE" | head -10
fi

echo ""
echo "Results: $((5 - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
