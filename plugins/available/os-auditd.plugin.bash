# shellcheck shell=bash
cite about-plugin
about-plugin 'auditd install configurations.'

function os-auditd {
    about 'auditd install configurations'
    group 'prenet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-auditd check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-auditd_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-auditd_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-auditd_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-auditd_run "$2"
    else
        __os-auditd_help
    fi
}

function __os-auditd_help {
    echo -e "Usage: os-auditd [COMMAND] [profile]\n"
    echo -e "Helper to auditd install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os auditd"
    echo "   uninstall Uninstall installed auditd"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-auditd_install {
    log_debug "Trying to install os-auditd."
    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official; apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "auditd") -lt 1 ]] && apt install -qy auditd

    # auditd hardening dynamic
    mkdir -p /etc/audit
    cp -rf ./configs/audit/audit.rules  /etc/audit/audit.rules
    # auditctl -R /etc/audit/audit.rules
    # add rules by force
    string_with_newlines=$(cat /etc/audit/audit.rules|grep -v "#"|grep -v -e '^[[:space:]]*$')
    while IFS= read -r line; do
        echo "auditctl ${line}"|sh -i &>/dev/null
    done <<< "$string_with_newlines"
    # check unserted lines
    echo "# generated on $(date +%s)" > /etc/audit/audit.rules.rejected
    while IFS= read -r line; do
        found=$(auditctl -l|grep "\\$line"|wc -l)
        [[ ${found} == 0 ]] && echo "${line}" >> /etc/audit/audit.rules.rejected
    done <<< "$string_with_newlines"
    # backup accepted lines
    echo "# generated on $(date +%s)" > /etc/audit/audit.rules
    auditctl -l >> /etc/audit/audit.rules
    systemctl enable auditd
    mkdir -p /var/log/audit
}

function __os-auditd_uninstall {
    log_debug "Trying to uninstall os-auditd."
    systemctl stop auditd
    systemctl disable auditd
}

function __os-auditd_disable {
    systemctl stop auditd
    systemctl disable auditd
    return 0
}

function __os-auditd_check {  # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-auditd Check"

    # check global variable
    [[ -z ${RUN_OS_AUDITD} ]] && \
        log_error "RUN_OS_AUDITD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_AUDITD} != 1 ]] && \
        log_error "RUN_OS_AUDITD is not enabled." && __os-auditd_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package dnsmasq
    [[ $(dpkg -l|awk '{print $2}'|grep -c "auditd") -lt 1 ]] && \
        log_info "auditd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof auditd) -gt 0 ]] && \
        log_info "auditd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-auditd_run {
    systemctl start auditd
    return 0
}

complete -F __os-auditd_run os-auditd

# https://rninche01.tistory.com/entry/Linux-system-call-table-%EC%A0%95%EB%A6%ACx86-x64
#
# type=SYSCALL msg=audit(1749094648.996:73664): arch=c000003e syscall=41 success=yes exit=188 a0=2 a1=80802 a2=0 a3=0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_socket_created"ARCH=x86_64 SYSCALL=socket AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=PROCTITLE msg=audit(1749094648.996:73664): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094648.996:73665): arch=c000003e syscall=42 success=yes exit=0 a0=bc a1=7f8a65d41d8c a2=10 a3=7f8a65d3e8d4 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_connect_4"ARCH=x86_64 SYSCALL=connect AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=SOCKADDR msg=audit(1749094648.996:73665): saddr=02000035C0A84F01E5E5E5E5E5E5E5E5SADDR={ saddr_fam=inet laddr=192.168.79.1 lport=53 }
# type=PROCTITLE msg=audit(1749094648.996:73665): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094649.032:73666): arch=c000003e syscall=41 success=yes exit=188 a0=2 a1=80002 a2=0 a3=7f8a65d3fdc0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_socket_created"ARCH=x86_64 SYSCALL=socket AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=PROCTITLE msg=audit(1749094649.032:73666): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094649.032:73667): arch=c000003e syscall=42 success=yes exit=0 a0=bc a1=7f8a4fc12a30 a2=10 a3=7f8a65d3fdc0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_connect_4"ARCH=x86_64 SYSCALL=connect AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=SOCKADDR msg=audit(1749094649.032:73667): saddr=02000000681226E90000000000000000SADDR={ saddr_fam=inet laddr=104.18.38.233 lport=0 }
# type=PROCTITLE msg=audit(1749094649.032:73667): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094649.032:73668): arch=c000003e syscall=42 success=yes exit=0 a0=bc a1=7f8a65d40070 a2=10 a3=7f8a65d3fdc0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_connect_4"ARCH=x86_64 SYSCALL=connect AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=SOCKADDR msg=audit(1749094649.032:73668): saddr=00000000000000000000000000000000SADDR=unknown-family(0)
# type=PROCTITLE msg=audit(1749094649.032:73668): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094649.032:73669): arch=c000003e syscall=42 success=yes exit=0 a0=bc a1=7f8a5030d070 a2=10 a3=7f8a65d3fdc0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=444E53205265737E76657220233239 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_connect_4"ARCH=x86_64 SYSCALL=connect AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=SOCKADDR msg=audit(1749094649.032:73669): saddr=02000000AC4095170000000000000000SADDR={ saddr_fam=inet laddr=172.64.149.23 lport=0 }
# type=PROCTITLE msg=audit(1749094649.032:73669): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094649.032:73670): arch=c000003e syscall=41 success=yes exit=188 a0=2 a1=1 a2=0 a3=0 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=536F636B657420546872656164 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_socket_created"ARCH=x86_64 SYSCALL=socket AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=PROCTITLE msg=audit(1749094649.032:73670): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094650.060:73671): arch=c000003e syscall=41 success=yes exit=190 a0=2 a1=1 a2=0 a3=36bebdec9285 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=536F636B657420546872656164 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_socket_created"ARCH=x86_64 SYSCALL=socket AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
# type=PROCTITLE msg=audit(1749094650.060:73671): proctitle="/usr/lib/firefox-esr/firefox-esr"
# type=SYSCALL msg=audit(1749094650.708:73672): arch=c000003e syscall=41 success=yes exit=215 a0=2 a1=1 a2=0 a3=627c24bfe383 items=0 ppid=1238 pid=1831 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=tty1 ses=1 comm=536F636B657420546872656164 exe="/usr/lib/firefox-esr/firefox-esr" subj=unconfined key="network_socket_created"ARCH=x86_64 SYSCALL=socket AUID="wj" UID="wj" GID="wj" EUID="wj" SUID="wj" FSUID="wj" EGID="wj" SGID="wj" FSGID="wj"
