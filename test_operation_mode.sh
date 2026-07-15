#!/usr/bin/env bash
cd $(dirname $0)

echo "Testing operation mode detection..."
echo

# Test 1: Check mode
echo "Test 1: --check mode"
result=$(bash -c 'source ./init.sh --check net-dnsmasq 2>&1; echo "MODE=$JANGBI_OPERATION_MODE LEVEL=$BASH_IT_LOG_LEVEL"' | grep "MODE=check LEVEL=4")
if [[ -n "$result" ]]; then
    echo "  ✓ PASS: Check mode sets MODE=check LEVEL=4"
else
    echo "  ✗ FAIL: Check mode did not set correct values"
    exit 1
fi

# Test 2: Install mode
echo "Test 2: --install mode"
result=$(bash -c 'source ./init.sh --install net-dnsmasq 2>&1; echo "MODE=$JANGBI_OPERATION_MODE LEVEL=$BASH_IT_LOG_LEVEL"' | grep "MODE=install LEVEL=6")
if [[ -n "$result" ]]; then
    echo "  ✓ PASS: Install mode sets MODE=install LEVEL=6"
else
    echo "  ✗ FAIL: Install mode did not set correct values"
    exit 1
fi

# Test 3: Launch mode
echo "Test 3: --launch mode"
result=$(bash -c 'source ./init.sh --launch net-dnsmasq 2>&1; echo "MODE=$JANGBI_OPERATION_MODE LEVEL=$BASH_IT_LOG_LEVEL"' | grep "MODE=launch LEVEL=5")
if [[ -n "$result" ]]; then
    echo "  ✓ PASS: Launch mode sets MODE=launch LEVEL=5"
else
    echo "  ✗ FAIL: Launch mode did not set correct values"
    exit 1
fi

echo
echo "All operation mode tests passed!"
