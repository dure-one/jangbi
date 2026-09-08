# Plugins

jangbi-it plugins is a set of configure, install, check status of certain app for jangbi.

## Tunnel plugins comparison

| Feature | shoes | v2ray | hysteria |
|---------|-------|-------|----------|
| **Language** | Rust | Go | Go |
| **Primary Focus** | Multi-protocol proxy server | Full-featured proxy platform | High-performance QUIC proxy |
| **HTTP Proxy** | ✅ | ✅ | ✅ |
| **SOCKS5** | ✅ | ✅ | ✅ |
| **VMess** | ✅ | ✅ | ❌ |
| **VLess** | ✅ | ✅ | ❌ |
| **Shadowsocks** | ✅ | ✅ | ❌ |
| **Trojan** | ✅ | ✅ | ❌ |
| **QUIC Support** | ✅ | ❌ | ✅ (Core feature) |
| **HTTP/3 Masquerading** | ❌ | ❌ | ✅ |
| **TLS Support** | ✅ | ✅ | ✅ |
| **WebSocket** | ✅ | ✅ | ❌ |
| **TCP Forwarding** | ❌ | ✅ | ✅ |
| **UDP Forwarding** | ❌ | ✅ | ✅ |
| **Proxy Chaining** | ✅ | ✅ | ❌ |
| **Smart Routing/Rules** | ✅ | ✅ | ❌ |
| **TUN Mode** | ❌ | ❌ | ✅ |
| **Linux TProxy** | ❌ | ❌ | ✅ |
| **Performance Focus** | Medium | Medium | High |
| **Censorship Resistance** | High | High | Very High |
| **Configuration Format** | YAML | JSON | YAML |
| **Use Case** | Multi-protocol server | Comprehensive platform | High-speed, censorship-resistant |

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


