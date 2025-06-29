# dnsmasq

anydnsdqy : dqy transport
dnsmasq : dns blacklist

# RUN_NET_ANYDNSDQY=1 127.0.0.1:53
# RUN_NET_ANYDNSDQY=0 1.1.1.1:53

RUN_NET_DNSMASQ=1 JB_ROLE=client 127.0.0.2:53 UPSTREAM 127.0.0.1(anydnsdqy enabled)|1.1.1.1(disabled)
RUN_NET_DNSMASQ=1 JB_ROLE=gateway 192.168.0.1:53 UPSTREAM 127.0.0.1(anydnsdqy enabled)|1.1.1.1(disabled)