# Design: Batch APT, Log Deduplication, WAN1 IP Stability

**Date:** 2026-07-19  
**Status:** Approved  
**Scope:** Three independent but related improvements to init.sh and net-randommac

---

## Problem 1: Batch APT Installs

### Context

`init.sh` iterates over enabled plugins and calls each plugin's `install` subcommand, which internally calls `apt install -qy <packages>`. With 16 plugins that call apt, this causes multiple redundant `apt update` calls and serialized package installs that could be parallelized or batched.

### Design

Add a `pkglist` subcommand to each plugin that prints only the apt package names needed (one per line or space-separated). `init.sh` runs a pre-pass before the main `process_each_step` loop, collects all packages, deduplicates, and does a single `apt update` + `apt install`.

**Pre-pass in init.sh (boot and install modes only):**

```bash
# Phase 1: Collect packages from all enabled plugins
all_pkgs=()
for plugin in "${prenet[@]}" "${postnet[@]}"; do
    if declare -f "${plugin}" > /dev/null 2>&1; then
        pkgs=$(${plugin} pkglist 2>/dev/null)
        [[ -n "$pkgs" ]] && all_pkgs+=($pkgs)
    fi
done

# Phase 2: Deduplicate and filter already-installed
missing_pkgs=()
for pkg in $(echo "${all_pkgs[@]}" | tr ' ' '\n' | sort -u); do
    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" || missing_pkgs+=("$pkg")
done

# Phase 3: Single batch install + verification
if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    log_info "Batch installing packages: ${missing_pkgs[*]}"
    # suricata requires debian_official extrepo (removed at line 240 for security)
    if printf '%s\n' "${missing_pkgs[@]}" | grep -q "^suricata$"; then
        [[ $(find /etc/apt/sources.list.d | grep -c "extrepo_debian_official") -lt 1 ]] && \
            extrepo enable debian_official
    fi
    apt update -qy
    apt install -qy "${missing_pkgs[@]}"
    # Remove extrepo_debian_official again (security policy — same as line 240)
    rm -rf /etc/apt/sources.list.d/extrepo_debian_official.sources
    # Verify each package
    for pkg in "${missing_pkgs[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            log_error "Package failed to install: ${pkg}"
        fi
    done
fi
```

**`pkglist` subcommand per plugin** — each plugin adds a dispatcher case and a `__pluginname_pkglist` function:

```bash
elif [[ "$1" = "pkglist" ]]; then
    __net-dnsmasq_pkglist
```

```bash
function __net-dnsmasq_pkglist {
    echo "dnsmasq-base"
}
```

**Plugins requiring `pkglist` (16 total):**

| Plugin | Packages |
|---|---|
| net-ifupdown | ifupdown iproute2 macchanger |
| net-hostapd | isc-dhcp-client ifupdown iproute2 wpasupplicant macchanger |
| net-dnsmasq | dnsmasq-base |
| net-netplan | netplan.io iproute2 macchanger |
| net-knockd | knockd |
| net-randommac | macchanger |
| net-darkstat | darkstat |
| net-sshd | openssh-server |
| net-iptables | nftables iptables arptables net-tools ipset iprange |
| net-suricata | suricata *(requires extrepo_debian_official enabled before install)* |
| net-xtables | xtables-addons-common |
| os-conf | cron |
| os-aide | aide |
| os-systemd | rsyslog netplan.io iproute2 wpasupplicant macchanger |
| os-auditd | auditd |
| os-redis | redis-server |

**Individual plugin `install` functions are unchanged.** After the pre-pass, their `apt install` calls are near-instant (packages already installed, dpkg detects them). Their internal `apt update` calls are skipped because the apt lists are fresh from the pre-pass.

### Constraints

- Pre-pass only runs in `boot` and `install` modes (`IS_CHECK_ONLY=0`)
- Plugins with offline/deb-file installs (package not in apt) return empty from `pkglist`
- suricata uses a custom repo — its `pkglist` returns empty; installation stays in its `install` function

---

## Problem 2: Log Deduplication in Check Mode

### Context

minmon calls `init.sh --check <plugin>` every 30 seconds per enabled plugin. Each invocation runs the full init.sh prologue, producing 500+ repeated log lines in 10,000-line samples:

| Message | Count | Source |
|---|---|---|
| "Config is up to date. No need to reload." | 588 | `_check_config_reload` in every plugin |
| "LOGFILE: LOG_PATH: RUN_LOG:" | 544 | log setup in `_load_config` |
| "Config file(.config) is loading..." | 544 | `_load_config` |
| "jq binary already exists at /usr/sbin/jq" | 534 | jq bootstrap block |
| "All required packages are already installed." | 534 | required_pkgs check |
| Interface validated messages | 517 | `_validate_interfaces` |
| "Configuration saved to .config.last" | 345+ | `.config.last` write |

### Design

Gate all prologue-only work behind `IS_CHECK_ONLY=0`. Check mode runs lean: config load → source plugin → call check → exit.

**Blocks to wrap with `[[ ${IS_CHECK_ONLY} -eq 0 ]]` in init.sh:**

1. jq binary check/download block
2. required_pkgs check block
3. `rm ./enabled/*` + symlink rebuild loop (entire JB_VARS loop for non-check mode)
4. `.config.last` write block
5. `rc.local` modification block
6. `_validate_interfaces` call
7. `ip_forward` block/unblock
8. Pre-pass batch APT block (from Problem 1)

**Check mode path becomes:**
```
init.sh --check net-randommac
  → _check_config_reload (load config once)
  → source plugin file (already in enabled/)
  → net-randommac check
  → exit $running_status
```

**Config-reload duplication in plugins:** The `_check_config_reload` call inside each plugin function runs even in check mode and logs "Config is up to date" when config is fresh. This log is at DEBUG level — already suppressed in check mode (log level 4 = warning+error only). No code change needed; the messages are suppressed by the existing log level, but they still execute. This is acceptable — the real cost is the prologue, not the reload check itself.

### Constraints

- The `enabled/` symlink directory must already be populated for check mode to source plugins — this is satisfied because the symlinks are created during the boot/install run and persist
- The `.config.last` write and `_validate_interfaces` must still run in `launch` and `install` modes

---

## Problem 3: WAN1 IP Stability (randommac death loop)

### Context

**Root cause confirmed in logs:** `__net-randommac_check` calls `curl icanhazip.com` to get the external IP. When the curl fails (empty result), it sets `running_status=0` and logs "Internet not reachable — will trigger MAC rotation." minmon then calls `net-randommac run`, which does:

```
ifdown wan1 → killall dhclient → change_mac → ifup wan1 (sleep 5) → curl icanhazip.com again
```

Bringing down wan1 makes internet unavailable → next check fails → triggers run again. This loops every ~30–60 seconds and explains wan1 losing its IP after reboot (DHCP not yet assigned when first check fires).

The log shows 59 consecutive "will trigger MAC rotation" messages from 09:46–09:49 (one every ~30s).

### Design

Replace the external HTTP check with a local WAN IP inspection. The plugin's purpose is to rotate MAC when the ISP-assigned IP is in a blocklist — not to monitor internet reachability.

**New `__net-randommac_check` logic:**

```bash
function __net-randommac_check {
    running_status=1  # default: OK, nothing to do

    # Guard: config and interface checks (unchanged)
    [[ -z ${RUN_NET_RANDOMMAC} ]] && running_status=10 && return 0
    [[ ${RUN_NET_RANDOMMAC} != 1 ]] && running_status=20 && return 0
    [[ -z ${JB_WANINF} ]] && log_error "JB_WANINF not set" && running_status=10 && return 0

    # Get local WAN IP (no external call)
    local wan_ip
    wan_ip=$(ip -4 addr show "${JB_WANINF}" 2>/dev/null | grep -oP 'inet \K[0-9.]+')

    if [[ -z "$wan_ip" ]]; then
        log_debug "WAN interface ${JB_WANINF} has no IP assigned yet — skipping check"
        running_status=1  # Not our problem; DHCP/ifupdown handles this
        return 0
    fi

    log_info "WAN IP: ${wan_ip}"

    # Check against avoided list
    if [[ -n "${RANDOMMAC_AVOIDED_IPS}" ]]; then
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

**Changes to `__net-randommac_run`:**

- Remove the `curl icanhazip.com` call after MAC change (no longer verifying external IP)
- After `ifup wan1` + sleep, verify wan1 has acquired a new local IP using `ip -4 addr show`
- If no local IP after retry, log error (DHCP failed), do not try another MAC rotation
- Remove the lockfile (`/var/run/net-randommac.lastcheck`) entirely — check is now cheap (local `ip` call), no rate-limiting needed

**Also fix in `__net-ifupdown_run`:** The `killall dhclient` call (line 238 in randommac run) kills dhclient for all interfaces including LAN. Should use `kill $(cat /var/run/dhclient.${JB_WANINF}.pid)` or `dhclient -r ${JB_WANINF}` to scope it to WAN only.

### Constraints

- `RANDOMMAC_AVOIDED_IPS` remains the only trigger for rotation; empty list means the plugin always returns `running_status=1`
- `__net-randommac_run` still uses `ifdown/ifup` (no change to that flow, just post-change verification)
- No external dependencies in the check path

---

## Implementation Order

1. **Problem 3 first** — active bug causing network instability; highest risk if left
2. **Problem 2 second** — reduces log noise, makes ongoing debugging easier
3. **Problem 1 last** — optimization; lowest risk, touches many files

---

## Testing

- **Problem 3:** Simulate wan1 no-IP state; verify `running_status=1`. Set avoided IP = current WAN IP; verify `running_status=0`. Confirm no external calls in check path.
- **Problem 2:** Run `init.sh --check net-randommac`; count log lines produced; should be ≤5 vs previous ~20+.
- **Problem 1:** Enable all plugins; verify only one `apt install` call in boot log; verify all packages installed correctly post-batch.
