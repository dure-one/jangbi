# dnsmasq

anydnsdqy : dqy transport
dnsmasq : dns blacklist

RUN_ANYDNSDQY=1 127.0.0.1:53
RUN_ANYDNSDQY=0 1.1.1.1:53

RUN_DNSMASQ=1 DURE_ROLE=client 127.0.0.2:53 UPSTREAM 127.0.0.1(anydnsdqy enabled)|1.1.1.1(disabled)
RUN_DNSMASQ=1 DURE_ROLE=gateway 192.168.0.1:53 UPSTREAM 127.0.0.1(anydnsdqy enabled)|1.1.1.1(disabled)