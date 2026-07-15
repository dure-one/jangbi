#!/usr/bin/env bash
cd $(dirname $0)

# Source the framework
source ./jangbi_it.sh

# Create temporary log file
TEST_LOG="/tmp/jangbi_log_test_$$.log"
export BASH_IT_LOG_FILE="$TEST_LOG"
> "$TEST_LOG"

echo "Testing conditional log functions..."
echo

# Test 1: log_check_ok in check mode (should be silent)
echo "Test 1: log_check_ok in check mode"
export JANGBI_OPERATION_MODE="check"
export BASH_IT_LOG_LEVEL=4
log_check_ok "This should NOT appear"
if ! grep -q "This should NOT appear" "$TEST_LOG"; then
    echo "  ✓ PASS: log_check_ok is silent in check mode"
else
    echo "  ✗ FAIL: log_check_ok logged in check mode"
    rm "$TEST_LOG"
    exit 1
fi

# Test 2: log_check in check mode (should log as warning)
echo "Test 2: log_check in check mode"
log_check "This SHOULD appear"
if grep -q "This SHOULD appear" "$TEST_LOG"; then
    echo "  ✓ PASS: log_check logs in check mode"
else
    echo "  ✗ FAIL: log_check did not log in check mode"
    rm "$TEST_LOG"
    exit 1
fi

# Test 3: log_check_ok in install mode (should log as debug)
echo "Test 3: log_check_ok in install mode"
> "$TEST_LOG"  # Clear log
export JANGBI_OPERATION_MODE="install"
export BASH_IT_LOG_LEVEL=6
log_check_ok "This should appear as debug"
if grep -q "This should appear as debug" "$TEST_LOG"; then
    echo "  ✓ PASS: log_check_ok logs in install mode"
else
    echo "  ✗ FAIL: log_check_ok did not log in install mode"
    rm "$TEST_LOG"
    exit 1
fi

# Test 4: log_check in install mode (should log as debug)
echo "Test 4: log_check in install mode"
> "$TEST_LOG"  # Clear log
log_check "This should appear as debug"
if grep -q "This should appear as debug" "$TEST_LOG"; then
    echo "  ✓ PASS: log_check logs in install mode"
else
    echo "  ✗ FAIL: log_check did not log in install mode"
    rm "$TEST_LOG"
    exit 1
fi

rm "$TEST_LOG"
echo
echo "All log function tests passed!"
