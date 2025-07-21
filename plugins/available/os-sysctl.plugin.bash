## \brief sysctl install configurations.
## \desc This tool helps install and manage sysctl (kernel runtime parameters) configurations
## for system optimization and security hardening. It provides automated configuration management
## for kernel parameters, allowing fine-tuning of system behavior including network settings,
## memory management, and security parameters.

## \example Install and configure sysctl parameters:
## \example-code bash
##   os-sysctl install
##   os-sysctl run
## \example-description
## In this example, we install custom sysctl configurations
## and apply them to optimize system performance and security.

## \example Check sysctl status:
## \example-code bash
##   os-sysctl check
## \example-description
## In this example, we verify the current sysctl configuration status
## and ensure the parameters are properly applied.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'sysctl install configurations.'

function os-sysctl {
    about 'sysctl install configurations'
    group 'prenet'
    runtype 'none'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ os-sysctl subcommand'
    local PKGNAME="sysctl"
    local DMNNAME="os-sysctl"
    BASH_IT_LOG_PREFIX="os-sysctl: "
    # SYSCTL_PORTS="${SYSCTL_PORTS:-""}"
    if _check_config_reload; then
        _root_only || exit 1
        _distname_check || exit 1
    fi

    if [[ $# -eq 1 ]] && [[ "$1" = "help" ]]; then
        __os-sysctl_help "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
        __os-sysctl_install "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
        __os-sysctl_uninstall "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "download" ]]; then
        __os-sysctl_download "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "disable" ]]; then
        __os-sysctl_disable "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configgen" ]]; then
        __os-sysctl_configgen "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "configapply" ]]; then
        __os-sysctl_configapply "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
        __os-sysctl_check "$2"
    elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
        __os-sysctl_run "$2"
    else
        __os-sysctl_help
    fi
}


## \usage os-sysctl help|install|uninstall|download|disable|configgen|configapply|check|run
function __os-sysctl_help {
    echo -e "Usage: os-sysctl [COMMAND]\n"
    echo -e "Helper to sysctl install configurations.\n"
    echo -e "Commands:\n"
    echo "   help      Show this help message"
    echo "   install   Install sysctl configurations"
    echo "   uninstall Uninstall installed configurations"
    echo "   download  Download required packages"
    echo "   disable   Disable sysctl"
    echo "   configgen Generate configuration"
    echo "   configapply Apply configuration"
    echo "   check     Check vars available"
    echo "   run       Run tasks"
}

function __os-sysctl_install {
    log_debug "Installing ${DMNNAME}..."
    # backup original sysctl on first run
    [[ ! -f "/etc/sysctl.orig" ]] && sysctl -a > /etc/sysctl.orig
    chmod 400 /etc/sysctl.orig
}

function __os-sysctl_uninstall { 
    log_debug "Uninstalling ${DMNNAME}..."
    sysctl -e -p /etc/sysctl.orig &>/dev/null
}

function __os-sysctl_download {
    log_debug "Downloading ${DMNNAME}..."
    # No packages to download for sysctl
    return 0
}

function __os-sysctl_disable {
    log_debug "Disabling ${DMNNAME}..."
    # Restore original sysctl
    [[ -f "/etc/sysctl.orig" ]] && sysctl -e -p /etc/sysctl.orig &>/dev/null
    return 0
}

function __os-sysctl_configgen {
    log_debug "Generating config for ${DMNNAME}..."
    # No separate config generation needed for sysctl
    return 0
}

function __os-sysctl_configapply {
    log_debug "Applying config ${DMNNAME}..."
    # No separate config apply needed for sysctl
    return 0
}

function __os-sysctl_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Checking ${DMNNAME}..."
    [[ -z ${RUN_OS_SYSCTL} ]] && \
        log_error "RUN_OS_SYSCTL variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_SYSCTL} != 1 ]] && \
        log_error "RUN_OS_SYSCTL is not enabled." && [[ $running_status -lt 20 ]] && running_status=20

    return 0
}

function __os-sysctl_run {
    log_debug "Running ${DMNNAME}..."
    # core dump limit
    if [[ $(grep -c "hard\ core\ 0" < "/etc/security/limits.conf") -lt 1 ]]; then
        echo "* hard core 0" >> /etc/security/limits.conf
        echo "* soft core 0" >> /etc/security/limits.conf
    fi

    if [[ $(sysctl kernel.printk|wc -l) -gt 0 ]]; then
        # sysctl hardening
        sysctl -e -p ./configs/sysctl/98-mikehoen-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/98-imthenachoman-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/98-2dure-sysctl.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/99-disable-coredump.conf &>/dev/null
        sysctl -e -p ./configs/sysctl/99-disable-maxusernamespaces.conf &>/dev/null
    fi

    [[ $(sysctl kernel.panic|awk '{print $3}') == '10' ]]

    return 0
}

complete -F _blank os-sysctl