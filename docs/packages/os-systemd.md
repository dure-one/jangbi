::: plugins/available/os-systemd.plugin.bash
    handler: shell
    options:
      heading_level: 2

# systemd

| Name     | Disable Completely (`RUN_OS_SYSTEMD=0`) | Only journald (`RUN_OS_SYSTEMD=2`) | Full systemd (`RUN_OS_SYSTEMD=1`) |
|----------|-----------------------------------------|------------------------------------|-----------------------------------|
| networkd | ❌ (networking)                          | ❌ (networking)                     | ✅ (systemd-networkd)              |
| resolved | ❌ (none)                                | ❌ (none)                           | ✅                                 |
| logind   | ❌ (getty)                               | ❌ (getty)                          | ✅                                 |
| journald | ❌ (separate log, no syslog)             | ✅ (journald+rsyslog)               | ✅ (journald+rsyslog)              |
| polkitd  | ❌                                       | ❌                                  | ✅                                 |

