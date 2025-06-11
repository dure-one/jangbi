# systemd

|name|disable completely|only journald|full systemd|
|------|---|---|---|
|networkd|X(isc-dhclient)|X(isc-dhclient)|O|
|resolved|X(anydnsdqy)|X(anydnsdqy)|O|
|logind  |X(getty)|X(getty)|O|
|journald|X(separate log, no syslog)|O(min journald+rsyslog)|O(journald+rsyslog)|
|polkitd|X|X|O|

