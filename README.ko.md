- **개발 진행 중**
- 이 스크립트를 실행하면 시스템이 손상될 수 있습니다.
- 순수 bash로 작성되었으며, **bookworm** 배포판에서만 동작합니다.

## JANGBI(장비)

장비는 Firewalla 저렴한 대안으로 설계된 포괄적인 보안 중심의 네트워크 어플라이언스 프레임워크입니다. Armbian/DietPi/Debian 위에서 iptables, dnsmasq 및 다양한 보안 도구를 결합하여 강력한 네트워크 보안 장치를 만듭니다. 이 프레임워크는 Dure 생태계의 일부이며 가정 및 소규모 비즈니스 네트워크를 위한 엔터프라이즈급 보안 기능을 제공합니다.<br/>
유사한 프로젝트: [pi-hole](https://pi-hole.net/), [technitium](https://technitium.com/dns/), [adguardhome](https://github.com/AdguardTeam/AdGuardHome), [blocky](https://github.com/0xERR0R/blocky), [portmaster](https://github.com/safing/portmaster?tab=readme-ov-file)

<details markdown>

<summary>기능</summary>

## 기능

### 핵심 보안 기능
- **OS 강화**: 커널 모듈 비활성화, sysctl 강화, 위험한 바이너리 비활성화
- **네트워크 보안**: 사전 구성된 iptables 규칙, 포트 포워딩, MAC 화이트리스트
- **침입 탐지**: AIDE (파일 무결성), auditd (시스템 감사)
- **DNS 보안**: 블랙리스트를 통한 DNS 차단, DNSCrypt-proxy 지원
- **트래픽 분석**: darkstat를 통한 네트워크 모니터링, Vector를 통한 로그 분석
- **접근 제어**: knockd를 통한 포트 노킹, SSH 강화

### 지원 서비스
- **방화벽**: 고급 규칙이 포함된 iptables/nftables
- **DNS/DHCP**: 광고 차단 기능이 포함된 dnsmasq
- **WiFi 액세스 포인트**: 무선 네트워킹을 위한 hostapd
- **VPN/프록시**: 보안 원격 접속을 위한 hysteria, v2ray, omnip, shoes
- **모니터링**: darkstat, auditd, AIDE, Vector, Redis
- **원격 접속**: 보안 강화된 OpenSSH

## 장치 운영 모드

### 1. 게이트웨이 모드 (전통적인 라우터)
WAN-LAN 분리가 있는 전통적인 NAT 라우터로 작동:
- dnsmasq를 통한 DNS/DHCP/DNS 차단
- ipset과 iptables를 통한 IP 차단
- DNS 블랙리스트 필터링
- LAN 클라이언트를 위한 NAT 마스커레이딩

### 2. TunnelOnly 모드 (프록시 전용)
NAT 라우팅 없는 보안 프록시 모드:
- 클라이언트는 tunnel(hysteria, omnip, shoes, v2ray) 프록시를 통해서만 연결
- 직접 인터넷 라우팅 없음
- 프록시 필터링을 통한 향상된 보안
- 마스커레이딩 없는 DNS/DHCP

### 3. 클라이언트 모드
엔드포인트 보호를 위한 단일 인터페이스 모드:
- 호스트 기반 방화벽 규칙
- 로컬 보안 강화
- 모니터링 및 침입 탐지

## 사전 요구사항

Jangbi-IT를 설치하기 전에 시스템이 다음 요구사항을 만족하는지 확인하세요:

- **운영 체제**: Armbian, Debian Bookworm, 또는 DietPi
- **하드웨어**: 최소 1GB RAM, 8GB 저장공간
- **네트워크**: 최소 하나의 네트워크 인터페이스
- **도구**: `ipcalc-ng` 패키지 설치됨
- **접근 권한**: root 또는 sudo 권한

#### 게이트웨이 모드(블랙리스트 모드)
iptables(nft)를 사용한 전통적인 nat 게이트웨이입니다.

* dns/dhcp/dnsblock : dnsmasq
* ip 차단 : ipset -> iptables, darkstat -> cutcdn/cdncheck -> iptables, vector(sysdig) -> iptables
* dns 차단 : steven blacklist -> dnsmasq/dnscrypt-proxy
* (할 일) 원격 게이트웨이 관리 앱 : buha 앱

#### TunnelOnly 모드(화이트리스트 모드)
nat 라우팅 없이, 클라이언트는 오직 tunnel app을 통해서만 외부에 연결됩니다. 라우트 없음. 오직 tunnel앱을 통해서만.

* dns/dhcp : dnsmasq(마스커레이드 없음)
* ip 차단 : iptables
* dns 차단 : dnsmasq
* (할 일) 원격 게이트웨이 관리 앱 : buha 앱

</details>

## 사전 요구사항
- **bookworm** 배포판과 호환되는 armbian/debian/dietpi/raspian 호스트
- ipcalc-ng 설치됨

## 설치
- 모든 **bookworm** 배포판에서

```bash
# ipcalc-ng 설치
$ apt install ipcalc-ng git patch

# 저장소 복제
$ git clone https://github.com/dure-one/jangbi.git

# .config.gateway.sample을 .config 파일로 복사
$ cp .config.gateway .config

# 인터페이스 이름 확인
# WAN, LAN, WLAN용 인터페이스가 무엇인지 고려
$ ip a

# 설정 편집, WAN, LAN, WLAN에 인터페이스 이름 추가
$ nano .config

# 구성자 실행
$ ./init.sh
```