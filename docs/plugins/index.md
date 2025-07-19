# Plugins

jangbi-it plugins is a set of configure, install, check status of certain app for jangbi.

## Tunnel plugins comparison

| Feature | omnip | shoes | v2ray | hysteria |
|---------|-------|-------|-------|----------|
| **Language** | Rust | Rust | Go | Go |
| **Primary Focus** | All-in-one QUIC proxy | Multi-protocol proxy server | Full-featured proxy platform | High-performance QUIC proxy |
| **HTTP Proxy** | ✅ | ✅ | ✅ | ✅ |
| **SOCKS5** | ✅ | ✅ | ✅ | ✅ |
| **SOCKS4/4a** | ✅ | ❌ | ❌ | ❌ |
| **VMess** | ❌ | ✅ | ✅ | ❌ |
| **VLess** | ❌ | ✅ | ✅ | ❌ |
| **Shadowsocks** | ❌ | ✅ | ✅ | ❌ |
| **Trojan** | ❌ | ✅ | ✅ | ❌ |
| **QUIC Support** | ✅ (Core feature) | ✅ | ❌ | ✅ (Core feature) |
| **HTTP/3 Masquerading** | ❌ | ❌ | ❌ | ✅ |
| **TLS Support** | ✅ | ✅ | ✅ | ✅ |
| **WebSocket** | ❌ | ✅ | ✅ | ❌ |
| **TCP Forwarding** | ✅ | ❌ | ✅ | ✅ |
| **UDP Forwarding** | ✅ | ❌ | ✅ | ✅ |
| **Proxy Chaining** | ✅ | ✅ | ✅ | ❌ |
| **Smart Routing/Rules** | ✅ | ✅ | ✅ | ❌ |
| **DNS over TLS** | ✅ | ❌ | ❌ | ❌ |
| **Web UI** | ✅ | ❌ | ❌ | ❌ |
| **TUN Mode** | ❌ | ❌ | ❌ | ✅ |
| **Linux TProxy** | ❌ | ❌ | ❌ | ✅ |
| **Performance Focus** | Medium | Medium | Medium | High |
| **Censorship Resistance** | Medium | High | High | Very High |
| **Configuration Format** | CLI args | YAML | JSON | YAML |
| **Use Case** | QUIC tunneling, Smart proxy | Multi-protocol server | Comprehensive platform | High-speed, censorship-resistant |

## Default Behavior

### install

install application and generate configuratiosn at /etc/{plugin_name}.

### uninstall

uninstall application and remove configurations.

### configgen

generate pre-configured configuration at /tmp/{plugin_name} and make diff compare to current configurations at /etc/{plugin_name}.

### configapply

apply diff patch generated from last operation at /tmp/{plugin_name}.diff to /etc/{plugin_name}

### check

check plugin vars in .configs exists, application installed, application is running.

### download

download necessary package files to install to ./pkgs directory.


