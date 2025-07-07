# shellcheck shell=bash
cite about-plugin
about-plugin 'minmon install configurations.'

function os-minmon {
    about 'minmon install configurations'
    group 'prenet'
    runtype 'cron'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-minmon check/install/uninstall/run'

    if [[ -z ${JB_VARS} ]]; then
        _load_config
        _root_only
        _distname_check
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-minmon_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-minmon_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-minmon_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-minmon_run "$2"
    else
        __os-minmon_help
    fi
}

function __os-minmon_help {
    echo -e "Usage: os-minmon [COMMAND] [profile]\n"
    echo -e "Helper to minmon install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install os firmware"
    echo "   uninstall Uninstall installed firmware"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-minmon_install {
    mkdir -p /tmp/minmon
    tar -zxvf ./pkgs/minmon-linux-*.tar.gz -C /tmp/minmon
    mv /tmp/minmon/minmon /usr/sbin/minmon
    chmod 700 /usr/sbin/minmon
    rm -rf /tmp/minmon

    __os-minmon_generate_config
}

function __os-minmon_generate_config {
    log_debug "Generating os-minmon configs..."
    mkdir -p /etc/minmon
    # backup old configs
    mv /etc/minmon/minmon.toml /etc/minmon/minmon.toml_$(date +%Y%m%d_%H%M%S).bak 2>/dev/null

    # generate new config
    cp ./configs/minmon/minmon.toml /etc/minmon/minmon.toml
    mkdir -p /tmp/minmon
    enabled_plugins=$(_jangbi-it-describe "plugins" "a" "plugin" "Plugin"|grep \[x\]|awk '{print $1}')
    IFS=$'\n' read -d "" -ra lvars <<< "${enabled_plugins}" # split
    for((j=0;j<${#lvars[@]};j++)){
        log_debug "${lvars[j]}"
        runtype=$(typeset -f -- "${lvars[j]}"|metafor runtype)
        log_debug "runtype: ${runtype}"
        if [[ ${runtype} == "minmon" ]]; then
            cp ./configs/minmon/template.toml /tmp/minmon/template.toml
            sed -i "s|__PLUGINNAME__|${lvars[j]}|g" "/tmp/minmon/template.toml"
            cat /tmp/minmon/template.toml >> /etc/minmon/minmon.toml
        fi
    }
    rm -rf /tmp/minmon
}

function __os-minmon_uninstall { 
    pidof minmon | xargs kill -9 2>/dev/null
    rm /usr/sbin/minmon
}

function __os-minmon_disabled { 
    pidof minmon | xargs kill -9 2>/dev/null
    return 0
}

function __os-minmon_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting os-minmon Check"

    # check global variable
    [[ -z ${RUN_OS_MINMON} ]] && \
        log_error "RUN_OS_MINMON variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_MINMON} != 1 ]] && \
        log_error "RUN_OS_MINMON is not enabled." && __os-minmon_disabled && [[ $running_status -lt 20 ]] && running_status=20
    # check package installed
    [[ $(which minmon|grep -c "minmon") -lt 1 ]] && \
        log_info "minmon is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if running
    [[ $(pidof minmon) -gt 0 ]] && \
        log_info "minmon is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __os-minmon_run {
    pidof minmon | xargs kill -9 2>/dev/null
    minmon /etc/minmon/minmon.toml 2>&1 1>/var/log/minmon.log &
    pidof minmon && return 0 || return 1
}

complete -F __os-minmon_run os-minmon