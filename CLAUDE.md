# CLAUDE.md — Jangbi Project

## What this project is

Jangbi is a security-focused network appliance framework for ARM SBCs (NanoPi, OrangePi, Raspberry Pi) running Armbian/Debian Bookworm. It turns a cheap SBC into a gateway router with iptables, dnsmasq, DNS encryption, IDS/IPS (Suricata), port knocking, and monitoring — a self-hosted Firewalla alternative. Everything is written in pure Bash.

**This is not a set-and-forget app.** It is a bootstrapper: `init.sh` runs at boot via `rc.local`, detects what's installed and running, and installs/starts what's missing.

---

## Repository layout

```
/opt/jangbi/
├── init.sh                 # Main entry point — runs on boot, all CLI ops
├── jangbi_it.sh            # Shell framework (bash-it adapter + config/log system)
├── .config                 # Active device config (gitignored, user-created)
├── .config.default         # Base defaults, every .config includes this via PARENT_CONFIG
├── .config.gateway.sample  # Template for gateway mode
├── .config.client.sample   # Template for client/endpoint mode
├── .config.last            # Auto-generated: rendered vars written after each run
├── enabled/                # Symlinks to active plugins (rebuilt on every init.sh run)
├── plugins/available/      # All plugin definitions
├── configs/                # Static config files deployed by plugins (dnsmasq, iptables, etc.)
├── pkgs/                   # Downloaded binary packages (.pkgs files)
├── imgs/                   # Downloaded disk images
├── vendor/
│   ├── bash-it/            # Shell framework (logging, helpers, component loader)
│   └── slib/               # slib.sh — run_ok(), spinner, network helpers
└── output.log              # Append-only runtime log (written by all processes)
```

---

## How init.sh works

`init.sh` is both the CLI tool and the boot bootstrapper. When called with no arguments, it runs the full install/start sequence.

### Boot sequence

1. **Environment setup** — exports `PATH` and `HOME` (critical: `HOME` must be set before sourcing `jangbi_it.sh` because the bash-it cache uses `${HOME?}`)
2. **Source `jangbi_it.sh`** — loads framework, auto-loads all plugins in `enabled/`, sets up logging
3. **Config reload check** — `_check_config_reload()` loads `.config` (via `.config.default` chain) if env vars are stale
4. **Package/jq bootstrap** — ensures `curl wget unzip ipcalc-ng git ipset iproute2` are installed; installs `jq` binary to `/usr/sbin/jq`
5. **Rebuild `enabled/`** — `rm ./enabled/*`, then re-symlinks plugins based on `RUN_*=1` in config
6. **Write `.config.last`** — dumps all matched JB_VARS to file for audit
7. **Validate interfaces** — checks `JB_WANINF`, `JB_LANINF`, etc. exist on the system
8. **Block IP forwarding** — `echo 0 > /proc/sys/net/ipv4/ip_forward` before any network changes
9. **Run prenet plugins** — `os-systemd`, then any `group:prenet` plugins
10. **Set IPv6** — enable/disable per `DISABLE_IPV6`
11. **Run postnet plugins** — `net-ifupdown`/`net-netplan`, `net-iptables`, then all `group:postnet` plugins
12. **Check network** — if internet reachable, sync time with `DNS_UPSTREAM`
13. **Enable/disable forwarding** — based on `JB_ROLE=gateway`

### CLI flags

```bash
./init.sh --check enabled       # check status of all enabled plugins
./init.sh --check net-dnsmasq   # check a single plugin
./init.sh --launch enabled      # run all enabled plugins
./init.sh --launch net-dnsmasq  # run a single plugin
./init.sh --install enabled     # install all enabled plugins
./init.sh --download enabled    # download packages for all enabled plugins
./init.sh --sync                # write .config.last and exit (no install/run)
./init.sh --doctor              # diagnose network issues
```

`--check`/`--launch`/`--install`/`--download` with a single plugin name (containing a hyphen) also causes early exit after processing that plugin.

---

## Plugin system

Each plugin is a single `.bash` file in `plugins/available/`. A plugin defines:
- A main dispatcher function named after the plugin (e.g., `net-dnsmasq`)
- Private helpers prefixed `__pluginname_` (e.g., `__net-dnsmasq_check`)
- Metadata via composure: `group`, `runtype`, `deps`

### Plugin groups (execution order)

| Group | When | Examples |
|-------|------|---------|
| `prenet` | Before network interfaces come up | `os-systemd`, `os-aide`, `os-sysctl`, `os-conf`, `os-minmon` |
| `net` | Network interface setup (predefined, not in JB_VARS loop) | `net-ifupdown`, `net-iptables`, `net-netplan` |
| `postnet` | After network is up | `net-dnsmasq`, `net-suricata`, `net-wactws`, `os-redis` |
| `postos` | Manual/one-time OS changes | `os-disablebins`, `os-kparams`, `os-firmware` |

### Plugin runtypes

- `minmon` — managed by the `minmon` process-monitor (checks every 30s, restarts on failure)
- `systemd` — managed by systemd unit files
- `cron` — managed via crontab entries
- `none` / `manual` — one-time install, no persistent runner

### Plugin subcommands (all plugins implement these)

```bash
plugin-name check       # returns running_status code, no side effects
plugin-name install     # install packages and config
plugin-name run         # start the service
plugin-name download    # fetch packages to ./pkgs/
plugin-name uninstall   # remove the service
plugin-name configgen   # generate config to /tmp/pluginname/ (no apply)
plugin-name configapply # diff and apply generated config
plugin-name disable     # stop and disable
plugin-name help        # show help
```

### `running_status` codes (returned by `check` subcommand)

| Code | Meaning | Action taken by `process_each_step` |
|------|---------|--------------------------------------|
| 0 | Installed but not running | `run` |
| 1 | Running — nothing to do | skip |
| 5 | Can install (packages present or downloadable) | `install` then `run` |
| 10 | Cannot install — missing required variable | fatal exit |
| 15 | Package file not downloaded yet | `download`, then `install`, then `run` |
| 20 | Disabled/skipped in config | skip |

`FORCE_INSTALL=1` in `.config` overrides any `check` result to `running_status=5` (always reinstall/run).

---

## Configuration system

### Config file chain

`.config` declares `PARENT_CONFIG=".config.default"`. `_load_config()` sources parent configs first, then the active `.config`, so child values override defaults.

### Key config variables

```bash
# Identity
DIST_DEVICE="nr5s"               # device model (informational)
DIST_NAME="debian_trixie_aarch64" # must match uname output
JB_DEPLOY_PATH="/opt/jangbi"     # deployment path

# Network interfaces
JB_WANINF=wan1                   # WAN interface name
JB_LANINF=lan1                   # LAN interface name
JB_WLANINF=                      # WLAN interface (empty = no WiFi AP)
JB_WAN="dhcp"                    # WAN IP: "dhcp" or CIDR like "192.168.1.2/24"
JB_LAN="192.168.79.1/24"         # LAN subnet (gateway becomes first IP)

# Device role
JB_ROLE="gateway"                # gateway | client | tunnelonly

# Systemd integration
RUN_OS_SYSTEMD=0                 # 0=disable+ifupdown, 1=full systemd+netplan, 2=journald-only+ifupdown
ADDTO_RCLOCAL=1                  # add init.sh to /etc/rc.local on first run

# Behaviour
FORCE_INSTALL=1                  # force reinstall on every boot (set 0 after stable)

# Plugin toggles — 1=enable, 0=disable
RUN_NET_IPTABLES=1
RUN_NET_DNSMASQ=1
RUN_NET_DNSCRYPTPROXY=1
RUN_NET_SURICATA=1
RUN_OS_MINMON=1
RUN_OS_REDIS=1
RUN_NET_WACTWS=1
```

### Log settings (from `.config.default`)

```bash
BASH_IT_LOG_FILE="output.log"  # relative — resolves to /opt/jangbi/output.log when CWD is correct
BASH_IT_LOG_LEVEL=6            # 0=none 1=fatal 3=error 4=warning 5=debug(file) 6=info 7=trace
```

---

## Logging

All log output goes to `/opt/jangbi/output.log` (appended, never truncated by the framework).

Log functions (defined in `jangbi_it.sh`, overriding bash-it defaults):

```bash
log_debug "msg"   # always writes to file; prints to stdout only if LOG_LEVEL >= 6
log_info "msg"    # prints cyan + writes to file if LOG_LEVEL >= 6
log_warning "msg" # prints yellow + writes to file if LOG_LEVEL >= 4
log_error "msg"   # prints red + writes to file if LOG_LEVEL >= 3
log_fatal "msg"   # always prints + always writes to file (no level check)
```

`run_ok "command" "message"` — runs a command, redirects its output to `output.log` via `RUN_LOG` (relative path), shows a spinner in interactive mode. Used by `process_each_step` for all install/run operations.

**Pitfall:** `BASH_IT_LOG_FILE` is set to a relative `"output.log"` by `.config.default`. If any plugin changes the working directory, subsequent `tee -a output.log` calls will write to the wrong file. The solution is that init.sh always starts with `cd $(dirname $0)` and plugins should use `pushd`/`popd` around any directory changes.

---

## Monitoring (minmon)

`os-minmon` installs the `minmon` binary and configures `/etc/minmon/minmon.toml`. For every plugin with `runtype=minmon`, minmon runs:
- `init.sh --check <plugin>` every 30 seconds
- `init.sh --launch <plugin>` when the check detects the process is down (after 2 cycles)

This is how dnsmasq, suricata, wactws, etc. recover from crashes without systemd.

---

## Known gotchas and bugs fixed

### HOME must be set before sourcing jangbi_it.sh

**Commit `init.sh` line 3:** `export HOME=${HOME:-/root}`

`rc-local.service` runs with `SetLoginEnvironment=no` — systemd does not inject `HOME`. The bash-it cache path uses `${HOME?}` (fatal if unset), which silently kills the process before a single log line is written. The fix ensures `HOME` is always available.

### `_check_config_reload` returns 1 for "up to date"

This is intentional but counterintuitive. In the `if _check_config_reload; then` pattern:
- Returns **0** = config was (re)loaded — continue with normal startup
- Returns **1** = config already fresh — triggers the `else` branch with a fatal message

Plugin functions that call `_check_config_reload` return early but do **not** exit — they handle both cases internally.

### `running_status` is a global, not local

`__plugin_check` functions set `running_status` directly as a global. `process_each_step` reads it after calling `run_ok "plugin check"`. Do not declare it `local` in check functions.

### `apt update` fails at boot due to clock skew

The system RTC may be 1+ hours behind real time at first boot (before NTP sync). APT signatures have a "not before" timestamp. The `os-systemd` and `os-conf` plugins run `apt update` during install; they log a warning and continue — they do not abort on APT signature failure.

### Multiple concurrent init.sh instances

`minmon` calls `init.sh --check <plugin>` every 30 seconds for each enabled plugin. These run concurrently with each other and with any manual invocations. All share the same `output.log`. The JB_VARS config-reload logic uses timestamps to avoid redundant reloads across instances.

---

## Current device

This instance runs on a **NanoPi R5S** (`DIST_DEVICE=nr5s`) with Debian Trixie arm64:
- `wan1` — WAN (DHCP from ISP)
- `lan1` — LAN (192.168.79.1/24)
- `lan2` — unused
- Role: gateway
- Networking: ifupdown (RUN_OS_SYSTEMD=0)
- Active plugins: net-iptables, net-dnsmasq, net-dnscryptproxy, net-suricata, net-wactws, os-minmon, os-redis, os-disablebins

---

## Logging system

Jangbi uses operation-aware logging to reduce log volume while maintaining visibility during install/troubleshooting:

### Operation modes

- **install** (`--install`): Verbose logging (level 6) - all debug + info messages
- **boot** (no flags): Verbose logging (level 6) - full visibility during first boot
- **launch** (`--launch`): Info logging (level 5) - info to stdout, debug to file
- **check** (`--check`): Error-only logging (level 4) - silent when OK, loud on errors

### Log location

All logs append to `/opt/jangbi/output.log` with automatic rotation:
- Daily rotation via logrotate
- 7-day retention
- Compressed archives (gzip)

### Plugin logging

Plugins use conditional logging functions:
- `log_check_ok("message")` - silent in check mode, debug in other modes
- `log_check("message")` - warning in check mode, debug in other modes
- `log_error("message")` - always logged regardless of mode

### Viewing logs

```bash
# Recent logs
tail -100 /opt/jangbi/output.log

# Follow logs live
tail -f /opt/jangbi/output.log

# Search for errors
grep -i error /opt/jangbi/output.log

# Check archived logs
zcat /opt/jangbi/output.log.1.gz | grep "pattern"
```

### Troubleshooting

If logs seem too quiet:
```bash
# Force verbose logging for one run
BASH_IT_LOG_LEVEL=6 ./init.sh
```

If logs grow too fast despite rotation:
```bash
# Check which plugins are logging heavily
tail -500 output.log | cut -d' ' -f4 | sort | uniq -c | sort -rn
```

---

## Common tasks

### Check what's running after boot
```bash
cd /opt/jangbi
./init.sh --check enabled
tail -100 output.log
```

### Force reinstall everything
```bash
FORCE_INSTALL=1 ./init.sh
```

### Test a single plugin
```bash
./init.sh --check net-dnsmasq
./init.sh --launch net-dnsmasq
```

### Add a new plugin to the system

1. Create `plugins/available/yourplugin.plugin.bash` with the standard function structure
2. Add `RUN_YOUR_PLUGIN=1` to `.config`
3. Run `./init.sh --install yourplugin` to test

### Rebuild interfaces config without full restart
```bash
./init.sh --launch net-ifupdown
```

### Re-apply iptables rules
```bash
./init.sh --launch net-iptables
```
