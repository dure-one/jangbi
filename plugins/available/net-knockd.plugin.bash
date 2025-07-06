# shellcheck shell=bash
cite about-plugin
about-plugin 'knockd install configurations.'

function net-knockd {
    about 'knockd install configurations'
    group 'postnet'
    runtype 'systemd'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-knockd check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-knockd_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-knockd_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-knockd_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-knockd_run "$2"
    else
        __net-knockd_help
    fi
}

function __net-knockd_help {
    echo -e "Usage: net-knockd [COMMAND] [profile]\n"
    echo -e "Helper to knockd install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install knockd"
    echo "   uninstall Uninstall installed knockd"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-knockd_install {
    log_debug "Trying to install net-knockd."

    export DEBIAN_FRONTEND=noninteractive
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official; apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "knockd") -lt 1 ]] && apt install -qy knockd
    systemctl enable knockd
    
    mv /etc/knockd.conf /etc/knockd.old.conf 2>/dev/null
    cp ./configs/knockd/knockd.conf.default /etc/knockd.conf
    sed -i "s|7000,8000,9000|${KNOCKD_STATIC_SSH}|g" "/etc/knockd.conf"
    chmod 600 /etc/knockd.conf

    # > step crypto otp generate --issuer dure.jangbi --account router_hostname --period=300 --length=10 --alg=SHA512 --qr dure.png > dure.totp
    # KNOCKD_WITH_STEPTOTP=1
    # KNOCKD_TOTPKEY="CIF3R2GPV6TLK4PJ3JZFLBMOCBYXSBP3"
    # apt install -qy ./pkgs/step-cli*.deb
    # https://smallstep.com/docs/step-cli/reference/
    # generate totp key
    # step crypto otp generate --issuer test.com --account test@test.com --period=600 --length=16 --alg=sha512 > smallstep.totp
    # show numbers
    # cat smallstep.totp  | xargs oathtool --totp --base32
    # verify totp
    # step crypto otp verify --secret smallstep.totp

    # cp knock_otp_regen.sh /sbin/knock_otp_regen.sh
    # chmod 600 /sbin/knock_otp_regen.sh
    # crontab -l > /tmp/mycron
    # echo "*/10 * * * * /sbin/knock_otp_regen.sh # KNOCKD" >> /tmp/mycron
    # crontab /tmp/mycron
    # rm /tmp/mycron
}

function __net-knockd_uninstall { 
    log_debug "Trying to uninstall net-knockd."
    # rm /sbin/knock_otp_regen.sh 2>/dev/null
    systemctl stop knockd
    systemctl disable knockd
}

function __net-knockd_disable { 
    systemctl stop knockd
    systemctl disable knockd
    return 0
}

function __net-knockd_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-knockd Check"
    
    # check global variable
    [[ -z ${RUN_NET_KNOCKD} ]] && \
        log_info "RUN_NET_KNOCKD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ -z ${KNOCKD_STATIC_SSH} ]] && \
        log_info "KNOCKD_STATIC_SSH variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_KNOCKD} != 1 ]] && \
        log_info "RUN_NET_KNOCKD is not enabled." && __net-knockd_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package knockd
    [[ $(dpkg -l|awk '{print $2}'|grep -c "knockd") -lt 1 ]] && \
        log_info "knockd is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(systemctl status knockd 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
        log_info "knockd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-knockd_run {
    systemctl start knockd
    systemctl status knockd && return 0 || return 1
}

complete -F __net-knockd_run net-knockd