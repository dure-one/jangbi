---
title: Jangbi 시작하기
hide:
- toc
---

# Jangbi 시작하기

## 경고

* systemd 플러그인은 네트워크 관련 중요한 패키지들을 제거할 수 있습니다. 네트워크 연결이 끊어질 수 있으니 원격 연결로는 실행하지 마세요.

## 빠른 설치

### 1. 사전 요구사항 설치

```bash
# 시스템 패키지 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 도구 설치
sudo apt install -y ipcalc-ng git
```

### 2. 저장소 복제

```bash
# Jangbi 저장소 복제
git clone https://github.com/dure-one/jangbi.git
cd jangbi
```

### 3. 장치 설정

```bash
# 게이트웨이 설정 템플릿 복사
cp .config.default .config

# 네트워크 인터페이스 확인
ip a

# 설정 파일 편집
nano .config
```

### 4. 네트워크 인터페이스 설정

네트워크 인터페이스를 식별하고 설정을 업데이트하세요:

```bash
# 사용 가능한 인터페이스 목록
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff

$ nano .config
# 게이트웨이 모드를 위한 인터페이스 할당 예시:
JB_WANINF=eth0      # WAN 인터페이스 (인터넷 연결)
JB_WAN="dhcp"
JB_LANINF=eth1      # LAN 인터페이스 (로컬 네트워크)
JB_LAN="192.168.79.1/24"
JB_WLANINF=wlan0    # WLAN 인터페이스 (WiFi AP)
JB_WLAN="192.168.89.1/24"
```

### 5. 설치 실행

```bash
# 시스템 초기화 및 설정
sudo ./init.sh
```

## 설정 파일 참조

### 기본 설정

```bash
# 장치 식별
DIST_DEVICE="orangepi5-plus"
DIST_NAME="armbian_bookworm_aarch64"

# 시스템 설정
CONF_TIMEZONE="Asia/Seoul"
JB_USERID=admin
JB_SSHPUBKEY="여기에-ssh-공개키-입력"
```

### 네트워크 설정

```bash
# WAN 인터페이스 (인터넷)
JB_WANINF=eth0
JB_WAN="dhcp"  # 또는 "192.168.1.100/24"와 같은 고정 IP

# LAN 인터페이스 (로컬 네트워크)
JB_LANINF=eth1
JB_LAN="192.168.79.1/24"

# WiFi 인터페이스 (액세스 포인트)
JB_WLANINF=wlan0
JB_WLAN="192.168.100.1/24"
JB_WLAN_APMODE=1
```

### 서비스 활성화

```bash
# 특정 서비스 활성화 (1=활성화, 0=비활성화)
RUN_NET_IPTABLES=1      # 방화벽
RUN_NET_DNSMASQ=1       # DNS/DHCP
RUN_NET_HOSTAPD=1       # WiFi AP
RUN_NET_DARKSTAT=1      # 네트워크 모니터링
RUN_OS_AUDITD=1         # 시스템 감사
RUN_OS_AIDE=1           # 파일 무결성
```

## Jangbi-IT 사용법

### 서비스 관리

플러그인 시스템을 사용하여 개별 서비스를 제어하세요:

```bash
# 서비스 상태 확인
./jangbi_it.sh net-iptables check
./jangbi_it.sh net-dnsmasq check

# 서비스 설치 및 설정
./jangbi_it.sh net-iptables install
./jangbi_it.sh net-iptables configgen
./jangbi_it.sh net-iptables configapply

# 서비스 시작
./jangbi_it.sh net-iptables run
./jangbi_it.sh net-dnsmasq run

# 서비스 모니터링
./jangbi_it.sh net-darkstat run  # 웹 인터페이스: http://device-ip:666
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
- `os-conf` - 시스템 설정
- `os-minmon` - 최소 모니터링
- `os-vector` - 로그 관리

### 플러그인 사용 패턴

모든 플러그인은 일관된 명령 구조를 따릅니다:

```bash
./jangbi_it.sh <플러그인-이름> <명령>

# 공통 명령:
install      # 서비스 설치
uninstall    # 서비스 제거
configgen    # 설정 파일 생성
configapply  # 설정 변경 적용
check        # 서비스 상태 확인
run          # 서비스 시작/재시작
download     # 필요한 패키지 다운로드
```

---

**경고**: 이 소프트웨어는 아직 개발 중입니다. 프로덕션 환경에서는 주의해서 사용하고 항상 랩 환경에서 먼저 테스트하세요.