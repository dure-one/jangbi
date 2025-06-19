# systemd

|name|disable completely(DISABLE_SYSTEMD=1)|only journald(DISABLE_SYSTEMD=2)|full systemd(DISABLE_SYSTEMD=0)|
|------|---|---|---|
|networkd|X(networking)|X(networking)|O(systemd-networkd)|
|resolved|X(anydnsdqy)|X(anydnsdqy)|O|
|logind  |X(getty)|X(getty)|O|
|journald|X(separate log, no syslog)|O(journald+rsyslog)|O(journald+rsyslog)|
|polkitd|X|X|O|

## 