# Batch APT, Log Deduplication, WAN1 Stability — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix a net-randommac death loop that drops wan1 after reboot, eliminate 500+ duplicate log lines per check cycle, and batch all APT installs into a single `apt install` call per boot.

**Architecture:** Three independent changes applied in dependency order: (1) fix the check logic in net-randommac to use local `ip addr` instead of external HTTP; (2) gate init.sh prologue work behind `IS_CHECK_ONLY=0` so minmon check cycles are lean; (3) add a `pkglist` subcommand to each plugin and a pre-pass in init.sh that collects, deduplicates, and batch-installs all packages before the main plugin loop.

**Tech Stack:** Bash 5, Debian apt/dpkg, `ip` (iproute2), macchanger, ifupdown, minmon

## Global Constraints

- Never run `ifdown`, `ifup`, `macchanger`, or `macchanger` against live interfaces during tests — mock them with bash function overrides
- Tests are plain bash scripts at the repo root, following the pattern of deleted `test_*.sh` files: `echo "PASS:"` / `echo "FAIL:"` + `FAILED` counter, exit code 0 on all pass
- `IS_CHECK_ONLY` is set at line 178–179 of `init.sh` (already exists) — all gates use this variable
- `running_status` is a global variable (never `local`) — check functions set it directly
- Plugin bash files live in `plugins/available/`, enabled symlinks in `enabled/`
- No external calls (curl, wget) in any check path — check mode must work fully offline

---

### Task 1: Fix net-randommac death loop

**Root cause:** `__net-randommac_check` treats `curl icanhazip.com` failure as `running_status=0` (trigger run). `__net-randommac_run` does `ifdown wan1 → killall dhclient → change_mac → ifup wan1`, which makes internet unavailable → next check fails → infinite loop every 30s.

**Files:**
- Modify: `plugins/available/net-randommac.plugin.bash` — replace `__net-randommac_check` and `__net-randommac_run`, update `__net-randommac_disable` and `__net-randommac_uninstall`
- Create: `test_randommac_check.sh`

**Interfaces:**
- Produces: `__net-randommac_check` sets global `running_status` — 1=skip, 0=rotate, 10=misconfigured, 20=disabled
- Produces: `__net-randommac_run` uses local `ip -4 addr show ${JB_WANINF}` to verify post-MAC IP

- [ ] **Step 1: Write the failing test**

Create `/opt/jangbi/test_randommac_check.sh`:

```bash
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

# Test 5: no curl call in check path
curl() { echo "CURL_CALLED"; }
ip() {
    echo "2: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP>"
    echo "    inet 8.8.8.8/24 brd 8.8.8.255 scope global wan1"
}
RANDOMMAC_AVOIDED_IPS=""
curl_output=$(net-randommac check 2>&1)
if [[ "$curl_output" != *"CURL_CALLED"* ]]; then
    echo "PASS: no curl call in check path"
else
    echo "FAIL: curl was called during check — must not make external calls"; FAILED=1
fi

echo ""
echo "Results: $((5 - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /opt/jangbi && bash test_randommac_check.sh
```

Expected: Tests 1 and 5 FAIL (current code checks external IP and treats failure as rotate trigger). Tests 2–4 may pass since ip_in_range logic is unchanged.

- [ ] **Step 3: Replace `__net-randommac_check` in `plugins/available/net-randommac.plugin.bash`**

Replace the entire `__net-randommac_check` function (currently lines 138–212) with:

```bash
function __net-randommac_check {
    running_status=1  # default: OK, nothing to do

    [[ -z ${RUN_NET_RANDOMMAC} ]] && \
        log_info "RUN_NET_RANDOMMAC variable is not set." && running_status=10 && return 0
    [[ ${RUN_NET_RANDOMMAC} != 1 ]] && \
        log_info "RUN_NET_RANDOMMAC is not enabled." && running_status=20 && return 0
    [[ -z ${JB_WANINF} ]] && \
        log_error "JB_WANINF is not set." && running_status=10 && return 0

    local wan_ip
    wan_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+')

    if [[ -z "$wan_ip" ]]; then
        log_debug "WAN interface ${JB_WANINF} has no IP assigned yet — skipping"
        running_status=1
        return 0
    fi

    log_info "WAN IP: ${wan_ip}"

    if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
        local avoided_list avoided
        IFS=',' read -ra avoided_list <<< "${RANDOMMAC_AVOIDED_IPS}"
        for avoided in "${avoided_list[@]}"; do
            avoided="${avoided// /}"
            if __net-randommac_ip_in_range "$wan_ip" "$avoided"; then
                export RANDOMMAC_TRIGGER_REASON="IP ${wan_ip} matches avoided range ${avoided}"
                log_warning "WAN IP ${wan_ip} matches avoided entry '${avoided}' — will rotate MAC"
                running_status=0
                return 0
            fi
        done
    fi

    log_info "WAN IP ${wan_ip} is not in the avoided list — OK"
    running_status=1
    return 0
}
```

- [ ] **Step 4: Run test — all 5 should pass now**

```bash
cd /opt/jangbi && bash test_randommac_check.sh
```

Expected output:
```
PASS: no WAN IP → running_status=1 (skip)
PASS: avoided IP exact match → running_status=0 (rotate)
PASS: clean IP → running_status=1 (skip)
PASS: IP in CIDR range → running_status=0 (rotate)
PASS: no curl call in check path
Results: 5 passed, 0 failed
```

- [ ] **Step 5: Replace `__net-randommac_run` in `plugins/available/net-randommac.plugin.bash`**

Replace the entire `__net-randommac_run` function (currently lines 214–307) with:

```bash
function __net-randommac_run {
    local trigger_reason="${RANDOMMAC_TRIGGER_REASON:-manual execution}"
    log_info "Running ${DMNNAME} (reason: ${trigger_reason})..."
    unset RANDOMMAC_TRIGGER_REASON

    if [[ -z "${JB_WANINF}" ]]; then
        log_error "JB_WANINF is not set, cannot change MAC."
        return 1
    fi

    local old_mac
    old_mac=$(ip link show "${JB_WANINF}" 2>/dev/null | grep -oP 'link/ether \K[^ ]+' || echo 'unknown')
    local old_ip
    old_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo 'none')
    log_info "Pre-change state: MAC=${old_mac} IP=${old_ip} Interface=${JB_WANINF}"

    local max_retries=5
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        log_info "MAC change attempt $((retry_count + 1))/${max_retries}..."

        ifdown "${JB_WANINF}" 2>/dev/null || ip link set "${JB_WANINF}" down
        pkill -f "dhclient.*${JB_WANINF}" 2>/dev/null || true

        sleep 1

        if ! change_mac "${JB_WANINF}" "random"; then
            log_warning "MAC change failed (attempt $((retry_count + 1))). Retrying..."
            ((retry_count++))
            ifup "${JB_WANINF}" 2>&1 | tee -a "${BASH_IT_LOG_FILE}" || true
            sleep 2
            continue
        fi

        if ! ifup "${JB_WANINF}" 2>&1 | tee -a "${BASH_IT_LOG_FILE}"; then
            log_error "Failed to bring up ${JB_WANINF} after MAC change."
            ((retry_count++))
            continue
        fi

        sleep 5

        local new_ip
        new_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+')

        if [[ -z "$new_ip" ]]; then
            log_warning "No IP acquired on ${JB_WANINF} after MAC change (attempt $((retry_count + 1)))."
            ((retry_count++))
            continue
        fi

        log_info "New WAN IP after MAC change: ${new_ip}"

        local ip_is_avoided=0
        if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
            local avoided_list avoided
            IFS=',' read -ra avoided_list <<< "${RANDOMMAC_AVOIDED_IPS}"
            for avoided in "${avoided_list[@]}"; do
                avoided="${avoided// /}"
                if __net-randommac_ip_in_range "$new_ip" "$avoided"; then
                    log_warning "New IP ${new_ip} is in avoided list (matches '${avoided}'). Retrying..."
                    ip_is_avoided=1
                    break
                fi
            done
        fi

        if [[ $ip_is_avoided -eq 0 ]]; then
            local new_mac
            new_mac=$(ip link show "${JB_WANINF}" 2>/dev/null | grep -oP 'link/ether \K[^ ]+' || echo 'unknown')
            log_info "Post-change state: MAC=${new_mac} IP=${new_ip} Interface=${JB_WANINF}"
            log_info "MAC rotation completed successfully in $((retry_count + 1)) attempt(s)"
            return 0
        fi

        ((retry_count++))
    done

    log_error "Failed to obtain a non-avoided IP after ${max_retries} attempts."
    return 1
}
```

- [ ] **Step 6: Remove lockfile references from `__net-randommac_disable` and `__net-randommac_uninstall`**

In `__net-randommac_disable` (around line 98–102), remove:
```bash
    rm -f /var/run/net-randommac.lastcheck
```

In `__net-randommac_uninstall` (around line 104–108), remove:
```bash
    rm -f /var/run/net-randommac.lastcheck
```

Also remove the existing `/var/run/net-randommac.lastcheck` if present:
```bash
rm -f /var/run/net-randommac.lastcheck
```

- [ ] **Step 7: Re-run test to confirm all 5 still pass after run changes**

```bash
cd /opt/jangbi && bash test_randommac_check.sh
```

Expected: 5 passed, 0 failed

- [ ] **Step 8: Commit**

```bash
git add plugins/available/net-randommac.plugin.bash test_randommac_check.sh
git commit -m "fix(net-randommac): use local WAN IP check, remove death loop on connectivity failure

- __net-randommac_check now uses 'ip addr show wan1' instead of curl icanhazip.com
- No WAN IP → running_status=1 (skip), no longer triggers MAC rotation
- Rotation only fires when local WAN IP matches RANDOMMAC_AVOIDED_IPS
- __net-randommac_run: replace killall dhclient with pkill -f scoped to JB_WANINF
- __net-randommac_run: verify post-MAC IP via local ip addr, not curl
- Remove /var/run/net-randommac.lastcheck lockfile (rate-limit no longer needed)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Suppress log noise in check mode

**Root cause:** minmon calls `init.sh --check <plugin>` every 30 seconds. The full prologue runs each time, producing 500+ redundant log lines (jq check, required packages, interface validation, config.last write).

**Files:**
- Modify: `init.sh` — wrap 5 blocks with `[[ ${IS_CHECK_ONLY} -eq 0 ]]`
- Create: `test_check_mode_noise.sh`

**Interfaces:**
- `IS_CHECK_ONLY` is already set at `init.sh:178–179` — no new variables needed
- `.config.last` is only written in non-check mode; check mode reads from already-populated `enabled/`

- [ ] **Step 1: Write the failing test**

Create `/opt/jangbi/test_check_mode_noise.sh`:

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")"
FAILED=0

echo "==========================================="
echo "   Check-mode log noise reduction tests"
echo "==========================================="

LOG_FILE="output.log"

# Test 1: required_pkgs block gated (grep source code)
if grep -A20 "required_pkgs=" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: required_pkgs block gated by IS_CHECK_ONLY"
else
    echo "FAIL: required_pkgs block not gated — runs on every check cycle"; FAILED=1
fi

# Test 2: jq binary block gated
if grep -A3 "jq binary" init.sh | grep -q "IS_CHECK_ONLY\|/usr/sbin/jq" && \
   grep -B2 "jq binary already exists" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: jq binary block gated by IS_CHECK_ONLY"
else
    echo "FAIL: jq binary block not gated — runs on every check cycle"; FAILED=1
fi

# Test 3: .config.last write gated
if grep -B1 'echo.*config.last' init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: .config.last initialization gated by IS_CHECK_ONLY"
else
    echo "FAIL: .config.last write not gated — runs on every check cycle"; FAILED=1
fi

# Test 4: _validate_interfaces gated
if grep -B1 "_validate_interfaces" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: _validate_interfaces gated by IS_CHECK_ONLY"
else
    echo "FAIL: _validate_interfaces not gated — runs on every check cycle"; FAILED=1
fi

# Test 5: live check produces ≤5 new log lines (safe read-only operation)
log_before=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
./init.sh --check net-randommac > /dev/null 2>&1
log_after=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
new_lines=$(( log_after - log_before ))
if [[ $new_lines -le 5 ]]; then
    echo "PASS: check mode produced $new_lines log lines (≤5)"
else
    echo "FAIL: check mode produced $new_lines log lines — expected ≤5 after gating"; FAILED=1
    echo "      Recent additions:"
    tail -n "$new_lines" "$LOG_FILE" | head -10
fi

echo ""
echo "Results: $((5 - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /opt/jangbi && bash test_check_mode_noise.sh
```

Expected: tests 1–4 FAIL (blocks not yet gated). Test 5 FAIL (currently produces ~20+ lines).

- [ ] **Step 3: Gate the required_pkgs block in `init.sh`**

Find the block starting at `# install required packages` (around line 226). Wrap the entire `required_pkgs` block:

Before:
```bash
# install required packages
required_pkgs=("curl" "wget" "unzip" "patch" "ipcalc-ng" "git" "extrepo" "ipset" "iproute2")
missing_pkgs=()
for pkg in "${required_pkgs[@]}"; do
    if ! dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
        missing_pkgs+=("${pkg}")
    fi
done
if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    log_debug "Installing missing packages: ${missing_pkgs[*]}"
    apt install -qy "${missing_pkgs[@]}" > /dev/null 2>&1
else
    log_debug "All required packages are already installed."
fi
```

After:
```bash
# install required packages (skip in check mode — minmon calls this every 30s)
if [[ ${IS_CHECK_ONLY} -eq 0 ]]; then
    required_pkgs=("curl" "wget" "unzip" "patch" "ipcalc-ng" "git" "extrepo" "ipset" "iproute2")
    missing_pkgs=()
    for pkg in "${required_pkgs[@]}"; do
        if ! dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
            missing_pkgs+=("${pkg}")
        fi
    done
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        log_debug "Installing missing packages: ${missing_pkgs[*]}"
        apt install -qy "${missing_pkgs[@]}" > /dev/null 2>&1
    else
        log_debug "All required packages are already installed."
    fi
fi
```

- [ ] **Step 4: Gate the jq binary block in `init.sh`**

Find the block starting at `# install jq binary` (around line 242). Wrap the entire jq block:

Before:
```bash
# install jq binary
if [[ -x /usr/sbin/jq ]]; then
    log_debug "jq binary already exists at /usr/sbin/jq. Skipping download."
else
    log_debug "jq binary not found. Downloading..."
    arch1_=$(dpkg --print-architecture)
    arch1=${3:-${arch1_}}
    [[ ${arch1} == "amd64" ]] && comparch="-64-"
    [[ ${arch1} == "arm64" ]] && comparch="-arm64-v8a-"

    if _download_github_pkgs jqlang/jq jq-linux-* "${arch1}" > /dev/null 2>&1; then
        jq_file=$(find ${JANGBI_IT}/pkgs -name "jq-linux-*${arch1}*" -type f 2>/dev/null | head -1)
        if [[ -n "${jq_file}" ]]; then
            cp "${jq_file}" /usr/sbin/jq
            chmod +x /usr/sbin/jq
            log_debug "jq binary installed successfully."
        else
            log_error "jq binary file not found after download."
        fi
    else
        log_warning "jq download from GitHub failed (possibly rate limited). Trying apt install..."
        if apt install -qy jq > /dev/null 2>&1; then
            log_debug "jq installed from apt repository."
        else
            log_error "Failed to install jq from both GitHub and apt. Some features may not work."
        fi
    fi
fi
```

After:
```bash
# install jq binary (skip in check mode — minmon calls this every 30s)
if [[ ${IS_CHECK_ONLY} -eq 0 ]]; then
    if [[ -x /usr/sbin/jq ]]; then
        log_debug "jq binary already exists at /usr/sbin/jq. Skipping download."
    else
        log_debug "jq binary not found. Downloading..."
        arch1_=$(dpkg --print-architecture)
        arch1=${3:-${arch1_}}
        [[ ${arch1} == "amd64" ]] && comparch="-64-"
        [[ ${arch1} == "arm64" ]] && comparch="-arm64-v8a-"

        if _download_github_pkgs jqlang/jq jq-linux-* "${arch1}" > /dev/null 2>&1; then
            jq_file=$(find ${JANGBI_IT}/pkgs -name "jq-linux-*${arch1}*" -type f 2>/dev/null | head -1)
            if [[ -n "${jq_file}" ]]; then
                cp "${jq_file}" /usr/sbin/jq
                chmod +x /usr/sbin/jq
                log_debug "jq binary installed successfully."
            else
                log_error "jq binary file not found after download."
            fi
        else
            log_warning "jq download from GitHub failed (possibly rate limited). Trying apt install..."
            if apt install -qy jq > /dev/null 2>&1; then
                log_debug "jq installed from apt repository."
            else
                log_error "Failed to install jq from both GitHub and apt. Some features may not work."
            fi
        fi
    fi
fi
```

- [ ] **Step 5: Gate the `.config.last` initialization in `init.sh`**

Find the block `# Initialize .config.last file` (around line 300). Wrap it:

Before:
```bash
# Initialize .config.last file
echo "# Complete rendered configuration with parent hierarchy" > .config.last
echo "# Generated at: $(date)" >> .config.last
echo "" >> .config.last
```

After:
```bash
# Initialize .config.last file (skip in check mode)
if [[ ${IS_CHECK_ONLY} -eq 0 ]]; then
    echo "# Complete rendered configuration with parent hierarchy" > .config.last
    echo "# Generated at: $(date)" >> .config.last
    echo "" >> .config.last
fi
```

- [ ] **Step 6: Gate the `.config.last` write inside the JB_VARS loop in `init.sh`**

Inside the JB_VARS loop, find the line (around line 349):

Before:
```bash
            # Save to .config.last instead of logging
            echo "${lvars[k]} $group_txt" >> .config.last
```

After:
```bash
            # Save to .config.last instead of logging (skip in check mode)
            [[ ${IS_CHECK_ONLY} -eq 0 ]] && echo "${lvars[k]} $group_txt" >> .config.last
```

- [ ] **Step 7: Gate `log_debug "Configuration saved..."` and `_validate_interfaces` in `init.sh`**

Find the two lines after the JB_VARS loop (around line 357–358):

Before:
```bash
# Log that config was saved to file
log_debug "Configuration saved to .config.last ($(wc -l < .config.last) lines)"

# Validate interface names against system interfaces
_validate_interfaces
```

After:
```bash
if [[ ${IS_CHECK_ONLY} -eq 0 ]]; then
    log_debug "Configuration saved to .config.last ($(wc -l < .config.last) lines)"
    _validate_interfaces
fi
```

- [ ] **Step 8: Run test — all 5 should pass**

```bash
cd /opt/jangbi && bash test_check_mode_noise.sh
```

Expected output:
```
PASS: required_pkgs block gated by IS_CHECK_ONLY
PASS: jq binary block gated by IS_CHECK_ONLY
PASS: .config.last initialization gated by IS_CHECK_ONLY
PASS: _validate_interfaces gated by IS_CHECK_ONLY
PASS: check mode produced N log lines (≤5)
Results: 5 passed, 0 failed
```

- [ ] **Step 9: Commit**

```bash
git add init.sh test_check_mode_noise.sh
git commit -m "perf(init): skip prologue in check mode to eliminate log noise

Gate jq check, required-packages, .config.last write, and interface
validation behind IS_CHECK_ONLY=0. minmon calls --check every 30s per
plugin; these blocks generated 500+ redundant log lines per 10k sample.
Check mode now produces ≤5 lines per invocation.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Batch APT installs via `pkglist` subcommand

**Goal:** Add `pkglist` subcommand to 16 plugins. Add pre-pass in `init.sh` that collects all packages, runs one `apt update` + one `apt install`, verifies installation, then lets the normal install loop run (individual `apt install` calls are near-instant since packages are already present).

**Files:**
- Modify: `plugins/available/net-ifupdown.plugin.bash`
- Modify: `plugins/available/net-hostapd.plugin.bash`
- Modify: `plugins/available/net-dnsmasq.plugin.bash`
- Modify: `plugins/available/net-netplan.plugin.bash`
- Modify: `plugins/available/net-knockd.plugin.bash`
- Modify: `plugins/available/net-randommac.plugin.bash`
- Modify: `plugins/available/net-darkstat.plugin.bash`
- Modify: `plugins/available/net-sshd.plugin.bash`
- Modify: `plugins/available/net-iptables.plugin.bash`
- Modify: `plugins/available/net-suricata.plugin.bash`
- Modify: `plugins/available/net-xtables.plugin.bash`
- Modify: `plugins/available/os-conf.plugin.bash`
- Modify: `plugins/available/os-aide.plugin.bash`
- Modify: `plugins/available/os-systemd.plugin.bash`
- Modify: `plugins/available/os-auditd.plugin.bash`
- Modify: `plugins/available/os-redis.plugin.bash`
- Modify: `init.sh` — add batch pre-pass before prenet/postnet loops
- Create: `test_pkglist.sh`

**Interfaces:**
- Each plugin's `pkglist` subcommand prints space-separated package names to stdout, exits 0
- `net-suricata pkglist` prints `suricata`; the pre-pass handles the extrepo_debian_official step before batch install
- The `init.sh` pre-pass only runs when `IS_CHECK_ONLY -eq 0`

- [ ] **Step 1: Write the failing test**

Create `/opt/jangbi/test_pkglist.sh`:

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")"
FAILED=0

echo "==================================="
echo "   pkglist subcommand tests"
echo "==================================="

# Framework stubs
export HOME=${HOME:-/root}
cite() { :; }; about-plugin() { :; }; about() { :; }; group() { :; }
runtype() { :; }; deps() { :; }; param() { :; }; example() { :; }; metafor() { :; }
log_debug() { :; }; log_info() { :; }; log_warning() { :; }; log_error() { :; }
_check_config_reload() { return 1; }
_root_only() { return 0; }
_distname_check() { return 0; }
complete() { :; }
ip() { :; }; ifdown() { :; }; ifup() { :; }; change_mac() { :; }

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
    # Re-source each time to avoid function name collisions
    (
        cite() { :; }; about-plugin() { :; }; about() { :; }; group() { :; }
        runtype() { :; }; deps() { :; }; param() { :; }; example() { :; }; metafor() { :; }
        log_debug() { :; }; log_info() { :; }; log_warning() { :; }; log_error() { :; }
        _check_config_reload() { return 1; }; _root_only() { return 0; }
        _distname_check() { return 0; }; complete() { :; }
        source "./plugins/available/${plugin}.plugin.bash" 2>/dev/null
        result=$(${plugin} pkglist 2>/dev/null)
        expected="${EXPECTED[$plugin]}"
        all_found=1
        for pkg in $expected; do
            [[ "$result" == *"$pkg"* ]] || { all_found=0; break; }
        done
        if [[ $all_found -eq 1 ]] && [[ -n "$result" ]]; then
            echo "PASS: $plugin pkglist → '$result'"
            exit 0
        else
            echo "FAIL: $plugin pkglist → '$result' (expected to contain '$expected')"
            exit 1
        fi
    ) || FAILED=1
done

# Test: init.sh contains batch pre-pass code
if grep -q "Batch installing packages" init.sh; then
    echo "PASS: init.sh contains batch pre-pass"
else
    echo "FAIL: init.sh missing batch pre-pass"; FAILED=1
fi

# Test: batch pre-pass is gated by IS_CHECK_ONLY
if grep -B5 "Batch installing packages" init.sh | grep -q "IS_CHECK_ONLY"; then
    echo "PASS: batch pre-pass gated by IS_CHECK_ONLY"
else
    echo "FAIL: batch pre-pass not gated by IS_CHECK_ONLY"; FAILED=1
fi

echo ""
total=$((${#EXPECTED[@]} + 2))
echo "Results: $((total - FAILED)) passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /opt/jangbi && bash test_pkglist.sh
```

Expected: all plugin tests FAIL (pkglist subcommand not yet implemented).

- [ ] **Step 3: Add `pkglist` to each plugin**

For each plugin, add the dispatcher case in the main function AND the `__pluginname_pkglist` helper. The pattern is identical across all 16 plugins. Add the dispatcher case alongside the other `elif` cases, and add the function near the other `__pluginname_*` functions.

**Pattern to add in each plugin's main dispatcher function:**
```bash
    elif [[ $# -eq 1 ]] && [[ "$1" = "pkglist" ]]; then
        __PLUGINNAME_pkglist "$2"
```

**net-ifupdown** — add to `net-ifupdown` dispatcher and add function:
```bash
function __net-ifupdown_pkglist {
    echo "ifupdown iproute2 macchanger"
}
```

**net-hostapd** — add to `net-hostapd` dispatcher and add function:
```bash
function __net-hostapd_pkglist {
    echo "isc-dhcp-client ifupdown iproute2 wpasupplicant macchanger"
}
```

**net-dnsmasq** — add to `net-dnsmasq` dispatcher and add function:
```bash
function __net-dnsmasq_pkglist {
    echo "dnsmasq-base"
}
```

**net-netplan** — add to `net-netplan` dispatcher and add function:
```bash
function __net-netplan_pkglist {
    echo "netplan.io iproute2 macchanger"
}
```

**net-knockd** — add to `net-knockd` dispatcher and add function:
```bash
function __net-knockd_pkglist {
    echo "knockd"
}
```

**net-randommac** — add to `net-randommac` dispatcher and add function:
```bash
function __net-randommac_pkglist {
    echo "macchanger"
}
```

**net-darkstat** — add to `net-darkstat` dispatcher and add function:
```bash
function __net-darkstat_pkglist {
    echo "darkstat"
}
```

**net-sshd** — add to `net-sshd` dispatcher and add function:
```bash
function __net-sshd_pkglist {
    echo "openssh-server"
}
```

**net-iptables** — add to `net-iptables` dispatcher and add function:
```bash
function __net-iptables_pkglist {
    echo "nftables iptables arptables net-tools ipset iprange"
}
```

**net-suricata** — add to `net-suricata` dispatcher and add function:
```bash
function __net-suricata_pkglist {
    echo "suricata"
}
```

**net-xtables** — add to `net-xtables` dispatcher and add function:
```bash
function __net-xtables_pkglist {
    echo "xtables-addons-common"
}
```

**os-conf** — add to `os-conf` dispatcher and add function:
```bash
function __os-conf_pkglist {
    echo "cron"
}
```

**os-aide** — add to `os-aide` dispatcher and add function:
```bash
function __os-aide_pkglist {
    echo "aide"
}
```

**os-systemd** — add to `os-systemd` dispatcher and add function:
```bash
function __os-systemd_pkglist {
    echo "rsyslog netplan.io iproute2 wpasupplicant macchanger"
}
```

**os-auditd** — add to `os-auditd` dispatcher and add function:
```bash
function __os-auditd_pkglist {
    echo "auditd"
}
```

**os-redis** — add to `os-redis` dispatcher and add function:
```bash
function __os-redis_pkglist {
    echo "redis-server"
}
```

- [ ] **Step 4: Run pkglist tests — all plugin tests should pass**

```bash
cd /opt/jangbi && bash test_pkglist.sh 2>&1 | grep -E "^(PASS|FAIL).*pkglist"
```

Expected: 16 PASS lines, 0 FAIL lines (the init.sh tests will still fail until Step 5).

- [ ] **Step 5: Add batch pre-pass to `init.sh`**

After the `prenet+=("${prenetdeps[@]}")` / `postnet+=("${postnetdeps[@]}")` lines (around line 374–375) and BEFORE the `log_debug "Starting prenet tasks..."` line (around line 472), add:

```bash
# Batch APT pre-pass: collect packages from all plugins, install once
if [[ ${IS_CHECK_ONLY} -eq 0 ]]; then
    log_debug "Collecting packages from enabled plugins..."
    _batch_pkgs=()
    for _plugin in "${prenet[@]}" "${postnet[@]}"; do
        if declare -f "${_plugin}" > /dev/null 2>&1; then
            _pkgs=$(${_plugin} pkglist 2>/dev/null)
            [[ -n "$_pkgs" ]] && _batch_pkgs+=($_pkgs)
        fi
    done

    _missing_batch=()
    for _pkg in $(printf '%s\n' "${_batch_pkgs[@]}" | sort -u); do
        dpkg -l "$_pkg" 2>/dev/null | grep -q "^ii" || _missing_batch+=("$_pkg")
    done

    if [[ ${#_missing_batch[@]} -gt 0 ]]; then
        log_info "Batch installing packages: ${_missing_batch[*]}"
        if printf '%s\n' "${_missing_batch[@]}" | grep -q "^suricata$"; then
            [[ $(find /etc/apt/sources.list.d | grep -c "extrepo_debian_official") -lt 1 ]] && \
                extrepo enable debian_official
        fi
        apt update -qy
        apt install -qy "${_missing_batch[@]}"
        rm -rf /etc/apt/sources.list.d/extrepo_debian_official.sources
        for _pkg in "${_missing_batch[@]}"; do
            if ! dpkg -l "$_pkg" 2>/dev/null | grep -q "^ii"; then
                log_error "Package failed to install: ${_pkg}"
            fi
        done
        log_info "Batch install complete: ${#_missing_batch[@]} packages installed"
    else
        log_debug "All plugin packages already installed — skipping batch apt"
    fi
    unset _batch_pkgs _missing_batch _plugin _pkgs _pkg
fi
```

- [ ] **Step 6: Run full test suite**

```bash
cd /opt/jangbi && bash test_pkglist.sh
```

Expected output:
```
PASS: net-ifupdown pkglist → 'ifupdown iproute2 macchanger'
PASS: net-dnsmasq pkglist → 'dnsmasq-base'
... (16 plugin PASS lines)
PASS: init.sh contains batch pre-pass
PASS: batch pre-pass gated by IS_CHECK_ONLY
Results: 18 passed, 0 failed
```

- [ ] **Step 7: Run all three test suites together to confirm no regressions**

```bash
cd /opt/jangbi
bash test_randommac_check.sh && echo "---" && \
bash test_check_mode_noise.sh && echo "---" && \
bash test_pkglist.sh
```

Expected: all three suites pass with 0 failures.

- [ ] **Step 8: Commit**

```bash
git add \
    plugins/available/net-ifupdown.plugin.bash \
    plugins/available/net-hostapd.plugin.bash \
    plugins/available/net-dnsmasq.plugin.bash \
    plugins/available/net-netplan.plugin.bash \
    plugins/available/net-knockd.plugin.bash \
    plugins/available/net-randommac.plugin.bash \
    plugins/available/net-darkstat.plugin.bash \
    plugins/available/net-sshd.plugin.bash \
    plugins/available/net-iptables.plugin.bash \
    plugins/available/net-suricata.plugin.bash \
    plugins/available/net-xtables.plugin.bash \
    plugins/available/os-conf.plugin.bash \
    plugins/available/os-aide.plugin.bash \
    plugins/available/os-systemd.plugin.bash \
    plugins/available/os-auditd.plugin.bash \
    plugins/available/os-redis.plugin.bash \
    init.sh \
    test_pkglist.sh
git commit -m "feat: batch APT installs via pkglist subcommand

Add pkglist subcommand to 16 plugins. init.sh pre-pass collects all
packages, deduplicates, and runs a single apt update + apt install before
the main plugin loop. suricata's extrepo_debian_official is enabled
temporarily and removed after install per security policy. Individual
plugin install functions are unchanged; their apt calls complete instantly
since packages are already installed.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```
