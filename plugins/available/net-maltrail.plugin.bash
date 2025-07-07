# shellcheck shell=bash
cite about-plugin
about-plugin 'maltrail install configurations.'

function net-maltrail {
    about 'maltrail install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-maltrail check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __net-maltrail_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __net-maltrail_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __net-maltrail_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __net-maltrail_run "$2"
    else
        __net-maltrail_help
    fi
}

function __net-maltrail_help {
    echo -e "Usage: net-maltrail [COMMAND] [profile]\n"
    echo -e "Helper to maltrail install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install maltrail"
    echo "   uninstall Uninstall installed  maltrail"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __net-maltrail_install {
    local inf

    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-maltrail."
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
    [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "maltrail") -lt 1 ]] && \
        apt install -qy git python3 python3-dev python3-pip python-is-python3 libpcap-dev build-essential procps schedtool

    [[ ! -d "/opt/maltrail" ]] && \
        git clone --depth 1 https://github.com/stamparm/maltrail.git /opt/maltrail
    if [[ -d "/opt/maltrail"]]; then
        pushd /opt/maltrail
        git pull 2>&1 1>/dev/null
        python3 -m venv .
        source bin/activate
        pip install -r requirements.txt
        deactivate
        popd
    fi

    # generate configs
    mkdir -p /etc/maltrail
    cp ./configs/maltrail.conf /etc/maltrail/maltrail.conf
    inf="127.0.0.1"
    [[ -n ${JB_LANINF} ]] && inf="${JB_LANINF}"
    sed -i "s|HTTP_ADDRESS\ .*|HTTP_ADDRESS\ ${inf}|g" /etc/maltrail/maltrail.conf
}

function __net-maltrail_disable { 
    ps ax|grep "python3\ sensor.py"|awk '{print $1}' | xargs kill -9 2>/dev/null
    ps ax|grep "python3\ server.py"|awk '{print $1}' | xargs kill -9 2>/dev/null
    return 0
}

function __net-maltrail_uninstall { 
    log_debug "Trying to uninstall net-maltrail."
    ps ax|grep "python3\ sensor.py"|awk '{print $1}' | xargs kill -9 2>/dev/null
    ps ax|grep "python3\ server.py"|awk '{print $1}' | xargs kill -9 2>/dev/null
}

function __net-maltrail_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-maltrail Check"

    # check global variable
    [[ -z ${RUN_NET_MALTRAIL} ]] && \
        log_error "RUN_NET_MALTRAIL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_NET_MALTRAIL} != 1 ]] && \
        log_error "RUN_NET_MALTRAIL is not enabled." && __net-maltrail_disable && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(find /opt/maltrail 2>/dev/null|grep -c "maltrail") -lt 1 ]] && \
        log_info "maltrail is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(ps ax|grep "python3\ server.py"|awk '{print $1}') -gt 0 ]] && \
        log_info "maltrail is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-maltrail_run {
    log_debug "Running maltrail..."

    ps ax|grep "python3\ server.py"|awk '{print $1}'|xargs kill &>/dev/null
    ps ax|grep "python3\ sensor.py"|awk '{print $1}'|xargs kill &>/dev/null

    if [[ -d "/opt/maltrail"]]; then
        pushd /opt/maltrail
        source bin/activate
        python3 sensor.py -c /etc/maltrail/maltrail.conf &
        python3 server.py -c /etc/maltrail/maltrail.conf &
        deactivate
        popd
    fi
    
    ps ax|grep "python3\ server.py"|awk '{print $1}' && return 0 || return 1
}

complete -F __net-maltrail_run net-maltrail
