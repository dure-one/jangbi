#!/usr/bin/env bash
cd "$(dirname "$0")"
FAILED=0

echo "==================================="
echo "   pkglist subcommand tests"
echo "==================================="

declare -A EXPECTED
EXPECTED["net-ifupdown"]="ifupdown iproute2 macchanger"
EXPECTED["net-dnsmasq"]="dnsmasq-base"
EXPECTED["net-netplan"]="netplan.io iproute2 macchanger"
EXPECTED["net-knockd"]="knockd"
EXPECTED["net-randommac"]="macchanger"
EXPECTED["net-darkstat"]="darkstat"
EXPECTED["net-sshd"]="openssh-server"
EXPECTED["net-iptables"]="nftables iptables arptables net-tools ipset iprange"
EXPECTED["net-suricata"]="suricata"
EXPECTED["net-xtables"]="xtables-addons-common"
EXPECTED["os-conf"]="cron"
EXPECTED["os-aide"]="aide"
EXPECTED["os-systemd"]="rsyslog netplan.io iproute2 wpasupplicant macchanger"
EXPECTED["os-auditd"]="auditd"
EXPECTED["os-redis"]="redis-server"
EXPECTED["net-hostapd"]="isc-dhcp-client ifupdown iproute2 wpasupplicant macchanger"

for plugin in "${!EXPECTED[@]}"; do
    result=$(
        cite() { :; }; about-plugin() { :; }; about() { :; }; group() { :; }
        runtype() { :; }; deps() { :; }; param() { :; }; example() { :; }; metafor() { :; }
        log_debug() { :; }; log_info() { :; }; log_warning() { :; }; log_error() { :; }
        _check_config_reload() { return 1; }; _root_only() { return 0; }
        _distname_check() { return 0; }; complete() { :; }
        ip() { :; }; ifdown() { :; }; ifup() { :; }; change_mac() { :; }
        source "./plugins/available/${plugin}.plugin.bash" 2>/dev/null
        ${plugin} pkglist 2>/dev/null
    )
    expected="${EXPECTED[$plugin]}"
    all_found=1
    for pkg in $expected; do
        [[ "$result" == *"$pkg"* ]] || { all_found=0; break; }
    done
    if [[ $all_found -eq 1 ]] && [[ -n "$result" ]] && [[ "$result" != *"Usage:"* ]]; then
        echo "PASS: $plugin pkglist → '$result'"
    else
        echo "FAIL: $plugin pkglist → '$(echo "$result" | head -1)...' (expected to contain '$expected' without help text)"
        FAILED=1
    fi
done

# Test: init.sh contains batch pre-pass
if grep -q "Batch installing packages" init.sh; then
    echo "PASS: init.sh contains batch pre-pass"
else
    echo "FAIL: init.sh missing batch pre-pass"; FAILED=1
fi

# Test: batch pre-pass gated by IS_CHECK_ONLY (check the pre-pass comment block)
if grep -A2 "Batch APT pre-pass" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: batch pre-pass gated by IS_CHECK_ONLY"
else
    echo "FAIL: batch pre-pass not gated by IS_CHECK_ONLY"; FAILED=1
fi

echo ""
total=$((${#EXPECTED[@]} + 2))
echo "Results: $((total - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
