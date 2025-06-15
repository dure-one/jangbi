# shellcheck shell=bash
cite about-plugin
about-plugin 'sysdig install configurations.'
# VARS :

function os-sysdig {
    about 'sysdig install configurations'
    group 'os'
    param '1: command'
    param '2: params'
    example '$ os-sysdig check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-sysdig_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-sysdig_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-sysdig_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-sysdig_run "$2"
    else
        __os-sysdig_help
    fi
}

function __os-sysdig_help {
    echo -e "Usage: os-sysdig [COMMAND] [profile]\n"
    echo -e "Helper to sysdig install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os sysdig"
    echo "   uninstall Uninstall installed sysdig"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-sysdig_install {
    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install os-sysdig."
    apt install -qy ./pkgs/sysdig*.deb

    sysdig_FRONTEND=noninteractive sysdig_DRIVER_CHOICE=ebpf sysdigCTL_ENABLED=no apt install ./pkgs/sysdig-0.41.1-x86_64.deb
    # sysdig hardening dynamic
    systemctl enable sysdig
    auditctl -l
    # do on everyboot
    systemctl start sysdig
    auditctl -R /etc/audit/audit.rules
}

function __os-sysdig_uninstall {
    log_debug "Trying to uninstall os-sysdig."
    apt purge -qy sysdig
#	systemctl stop sysdig
#	systemctl disable sysdig
}

function __os-sysdig_check {  # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-sysdig Check"
    [[ ${#RUN_SYSDIG[@]} -lt 1 ]] && \
        log_info "RUN_SYSDIG variable is not set." && [[ $running_status -lt 10 ]] && running_status=10

    [[ $(dpkg -l|awk '{print $2}'|grep sysdig|wc -l) -lt 1 ]] && \
        log_info "sysdig is not installed." && [[ $running_status -lt 5 ]] && running_status=5

    return 0
}

function __os-sysdig_run {
    :
    return 0
}

complete -F __os-sysdig_run os-sysdig
# https://github.com/annulen/sysdig-wiki/blob/master/sysdig-User-Guide.md
# https://rninche01.tistory.com/entry/Linux-system-call-table-%EC%A0%95%EB%A6%ACx86-x64
# sysdig –L
# https://github.com/draios/sysdig/wiki/sysdig-Examples

#
# $ sysdig "evt.type=accept or evt.type=connect"\
#
# 294128881 03:42:41.721363021 2 Socket Thread (1831.1842) < connect res=-115(EINPROGRESS) tuple=192.168.79.185:45666->151.101.65.140:443 fd=220(<4t>192.168.79.185:45666->151.101.65.140:443)
# 294230124 03:42:41.884660619 0 Socket Thread (1831.1842) > connect fd=202(<4>) addr=151.101.65.140:443
# 294230171 03:42:41.884691517 0 Socket Thread (1831.1842) < connect res=-115(EINPROGRESS) tuple=192.168.79.185:45672->151.101.65.140:443 fd=202(<4t>192.168.79.185:45672->151.101.65.140:443)
# 294852860 03:42:42.912573877 7 Socket Thread (1831.1842) > connect fd=112(<4>) addr=20.200.245.247:443
# 294852888 03:42:42.912625483 7 Socket Thread (1831.1842) < connect res=-115(EINPROGRESS) tuple=192.168.79.185:35700->20.200.245.247:443 fd=112(<4t>192.168.79.185:35700->20.200.245.247:443)
# 294870257 03:42:42.941035123 5 Socket Thread (1831.69373) > connect fd=114(<4>) addr=192.168.79.1:53
# 294870305 03:42:42.941062955 5 Socket Thread (1831.69373) < connect res=0 tuple=192.168.79.185:55184->192.168.79.1:53 fd=114(<4u>192.168.79.185:55184->192.168.79.1:53)
# 295089763 03:42:43.187013705 5 Socket Thread (1831.69373) > connect fd=114(<4>) addr=104.18.38.233:0
# 295089785 03:42:43.187117519 5 Socket Thread (1831.69373) < connect res=0 tuple=192.168.79.185:37028->104.18.38.233:0 fd=114(<4u>192.168.79.185:37028->104.18.38.233:0)
# 295089795 03:42:43.187135312 5 Socket Thread (1831.69373) > connect fd=114(<4u>192.168.79.185:37028->104.18.38.233:0) addr=NULL
# 295089812 03:42:43.187205734 5 Socket Thread (1831.69373) < connect res=0 tuple=0.0.0.0:0->0.0.0.0:0 fd=114(<4u>0.0.0.0:0->104.18.38.233:0)
# 295089816 03:42:43.187210553 5 Socket Thread (1831.69373) > connect fd=114(<4u>0.0.0.0:0->104.18.38.233:0) addr=172.64.149.23:0
# 295089833 03:42:43.187289490 5 Socket Thread (1831.69373) < connect res=0 tuple=192.168.79.185:54086->172.64.149.23:0 fd=114(<4u>192.168.79.185:54086->172.64.149.23:0)
# 295090259 03:42:43.188322978 5 Socket Thread (1831.1842) > connect fd=114(<4>) addr=172.64.149.23:80
# 295090332 03:42:43.188504246 5 Socket Thread (1831.1842) < connect res=-115(EINPROGRESS) tuple=192.168.79.185:54806->172.64.149.23:80 fd=114(<4t>192.168.79.185:54806->172.64.149.23:80)
# 295642363 03:42:44.380847996 8 Socket Thread (1831.1842) > connect fd=281(<4>) addr=185.199.111.133:443
# 295642395 03:42:44.380945388 8 Socket Thread (1831.1842) < connect res=-115(EINPROGRESS) tuple=192.168.79.185:42806->185.199.111.133:443 fd=281(<4t>192.168.79.185:42806->185.199.111.133:443)
