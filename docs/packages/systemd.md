# systemd

|name|disable completely(RUN_OS_SYSTEMD=0)|only journald(RUN_OS_SYSTEMD=2)|full systemd(RUN_OS_SYSTEMD=1)|
|------|---|---|---|
|networkd|X(networking)|X(networking)|O(systemd-networkd)|
|resolved|X(anydnsdqy)|X(anydnsdqy)|O|
|logind  |X(getty)|X(getty)|O|
|journald|X(separate log, no syslog)|O(journald+rsyslog)|O(journald+rsyslog)|
|polkitd|X|X|O|

## 