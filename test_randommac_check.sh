#!/usr/bin/env bash
cd "$(dirname "$0")"
FAILED=0

echo "==================================="
echo "   net-randommac check unit tests"
echo "==================================="

# Framework stubs — avoid sourcing full jangbi_it.sh
export HOME=${HOME:-/root}
cite() { :; }; about-plugin() { :; }; about() { :; }; group() { :; }
runtype() { :; }; deps() { :; }; param() { :; }; example() { :; }; metafor() { :; }
log_debug() { :; }; log_info() { :; }; log_warning() { :; }; log_error() { :; }
_check_config_reload() { return 1; }  # 1=already fresh, skip reload branch
_root_only() { return 0; }
_distname_check() { return 0; }
complete() { :; }

source ./plugins/available/net-randommac.plugin.bash

# Test 1: no WAN IP → running_status=1 (skip, not our problem)
ip() { echo "2: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP>"; }
JB_WANINF="wan1"; RUN_NET_RANDOMMAC=1; RANDOMMAC_AVOIDED_IPS=""
net-randommac check
if [[ $running_status -eq 1 ]]; then
    echo "PASS: no WAN IP → running_status=1 (skip)"
else
    echo "FAIL: no WAN IP → expected running_status=1, got $running_status"; FAILED=1
fi

# Test 2: WAN IP exactly in avoided list → running_status=0 (rotate)
ip() {
    echo "2: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP>"
    echo "    inet 1.2.3.4/24 brd 1.2.3.255 scope global wan1"
}
RANDOMMAC_AVOIDED_IPS="1.2.3.4"
net-randommac check
if [[ $running_status -eq 0 ]]; then
    echo "PASS: avoided IP exact match → running_status=0 (rotate)"
else
    echo "FAIL: avoided IP → expected running_status=0, got $running_status"; FAILED=1
fi

# Test 3: WAN IP not in avoided list → running_status=1 (ok)
RANDOMMAC_AVOIDED_IPS="5.6.7.8"
net-randommac check
if [[ $running_status -eq 1 ]]; then
    echo "PASS: clean IP → running_status=1 (skip)"
else
    echo "FAIL: clean IP → expected running_status=1, got $running_status"; FAILED=1
fi

# Test 4: WAN IP inside CIDR range → running_status=0 (rotate)
ip() {
    echo "2: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP>"
    echo "    inet 10.0.0.42/24 brd 10.0.0.255 scope global wan1"
}
RANDOMMAC_AVOIDED_IPS="10.0.0.0/24"
net-randommac check
if [[ $running_status -eq 0 ]]; then
    echo "PASS: IP in CIDR range → running_status=0 (rotate)"
else
    echo "FAIL: CIDR check → expected running_status=0, got $running_status"; FAILED=1
fi

# Test 5: no curl call in check path (file sentinel — survives subshell)
_CURL_SENTINEL=$(mktemp)
curl() { echo "called" > "$_CURL_SENTINEL"; }
ip() {
    echo "2: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP>"
    echo "    inet 8.8.8.8/24 brd 8.8.8.255 scope global wan1"
}
RANDOMMAC_AVOIDED_IPS=""
net-randommac check 2>/dev/null
if [[ ! -s "$_CURL_SENTINEL" ]]; then
    echo "PASS: no curl call in check path"
else
    echo "FAIL: curl was called during check — must not make external calls"; FAILED=1
fi
rm -f "$_CURL_SENTINEL"

echo ""
echo "Results: $((5 - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
