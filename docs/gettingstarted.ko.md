---
title: 시작하기
---

# Jangbi 시작하기

## 경고

* systemd 플러그인은 네트워크에 중요한 많은 패키지를 제거합니다. 네트워크 연결이 끊어질 수 있으니 원격 연결로 실행하지 마세요.

## 빠른 설치

### 1. 필수 구성 요소 설치

```bash
# 필요한 도구 설치
sudo apt install -y ipcalc-ng git
```

### 2. 저장소 복제

init 시스템이 쉽게 찾을 수 있도록 /opt 폴더에 설치하세요.<br/>
설치 및 설정 파일 편집을 위해 root 계정을 사용하세요.

```bash
# Jangbi 저장소 복제
git clone https://github.com/dure-one/jangbi.git /opt/jangbi
cd /opt/jangbi
```

### 3. 장치 구성

```bash
# 게이트웨이 구성 템플릿 복사
cp .config.default .config

# 네트워크 인터페이스 확인
ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 192.168.79.186/24 brd 192.168.79.255 scope global dynamic enx00e04c680686
       valid_lft 37293sec preferred_lft 37293sec
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff

# 구성 파일 편집
nano .config
# 게이트웨이 모드용 인터페이스 할당 예시:
JB_WANINF=eth0      # WAN 인터페이스 (인터넷 연결)
JB_WAN="dhcp"
JB_LANINF=eth1      # LAN 인터페이스 (로컬 네트워크)
JB_LAN="192.168.79.1/24"
JB_WLANINF=wlan0    # WLAN 인터페이스 (WiFi AP)
JB_WLAN="192.168.89.1/24"
```

### 4. 실행할 플러그인 구성

```bash
# 구성 파일 편집
$ nano .config
# 게이트웨이 앱
RUN_NET_HOSTAPD=1
RUN_NET_DNSMASQ=1
DNSMASQ_BLACKLIST_URLS="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
RUN_NET_DNSCRYPTPROXY=1
RUN_NET_DARKSTAT=1
RUN_OS_REDIS=1
RUN_OS_MINMON=1
RUN_NET_WSTUNNEL=0
RUN_SOCKS5PROXY=0
```

### 5. 설치 실행

```bash
# 시스템 초기화 및 구성
$ ./init.sh
```

## Jangbi-IT 사용하기

### 서비스 관리

플러그인 시스템을 사용하여 개별 서비스를 제어합니다:

```bash
# jangbi-it 로드
$ cd /opt/jangbi
$ source jangbi_it.sh

# 서비스 상태 확인
$ net-iptables check
$ net-dnsmasq check

# 서비스 설치 및 구성
$ net-iptables install
$ net-iptables configgen
$ net-iptables configapply

# 서비스 시작
$ net-iptables run
$ net-dnsmasq run

# 서비스 모니터링
$ net-darkstat run  # 웹 인터페이스: http://device-ip:666
```

### 사용 가능한 플러그인

#### 네트워크 플러그인
- `net-iptables` - 방화벽 관리
- `net-dnsmasq` - DNS/DHCP 서버
- `net-hostapd` - WiFi 액세스 포인트
- `net-sshd` - SSH 데몬 강화
- `net-darkstat` - 네트워크 트래픽 모니터링
- `net-knockd` - 포트 노킹 데몬
- `net-wstunnel` - WebSocket 터널 프록시

#### OS 플러그인
- `os-auditd` - 시스템 감사
- `os-aide` - 파일 무결성 모니터링
- `os-sysctl` - 커널 매개변수 조정
- `os-conf` - 시스템 구성
- `os-minmon` - 최소 모니터링
- `os-vector` - 로그 관리

### 플러그인 사용 패턴

모든 플러그인은 일관된 명령 구조를 따릅니다:

```bash
<플러그인-이름> <명령>

# 일반 명령:
install      # 서비스 설치
uninstall    # 서비스 제거
configgen    # 구성 파일 생성
configapply  # 구성 변경 적용
check        # 서비스 상태 확인
run          # 서비스 시작/재시작
download     # 필요한 패키지 다운로드
```

## 구성 파일 참조
```bash
$ cat .config.default 
--8<-- ".config.default"
```

---

**경고**: 이 소프트웨어는 아직 개발 중입니다. 프로덕션 환경에서는 신중하게 사용하고 항상 랩 환경에서 먼저 테스트하세요.