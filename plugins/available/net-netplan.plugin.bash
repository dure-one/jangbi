# shellcheck shell=bash
cite about-plugin
about-plugin 'netplan install configurations.'

function net-netplan {
  about 'netplan install configurations'
  group 'net'
  runtype 'systemd'
  deps  'os-systemd'
  param '1: command'
  param '2: params'
  example '$ net-netplan check/install/uninstall/run'

  if [[ -z ${JB_VARS} ]]; then
      _load_config
      _root_only
      _distname_check
  fi

  if [[ $# -eq 1 ]] && [[ "$1" = "install" ]]; then
    __net-netplan_install "$2"
  elif [[ $# -eq 1 ]] && [[ "$1" = "uninstall" ]]; then
    __net-netplan_uninstall "$2"
  elif [[ $# -eq 1 ]] && [[ "$1" = "check" ]]; then
    __net-netplan_check "$2"
  elif [[ $# -eq 1 ]] && [[ "$1" = "run" ]]; then
    __net-netplan_run "$2"
  else
    __net-netplan_help
  fi
}

function __net-netplan_help {
  echo -e "Usage: net-netplan [COMMAND] [profile]\n"
  echo -e "Helper to netplan install configurations.\n"
  echo -e "Commands:\n"
  echo "   help                       Show this help message"
  echo "   install 1 nft_rules        Install os netplan ex) install $ipv6enabled $nft_rules"
  echo "   uninstall                  Uninstall installed netplan"
  echo "   check                      Check vars available"
  echo "   run                        do task at bootup"
}

function __net-netplan_install {
    local nftables_override="$1" # $NFTABLES_OVERRIDE
    local disable_ipv6="$2"

    export DEBIAN_FRONTEND=noninteractive
    log_debug "Trying to install net-netplan."
    [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official; apt update -qy
    [[ $(dpkg -l|awk '{print $2}'|grep -c "netplan.io") -lt 1 ]] && apt install -qy netplan.io
    mkdir -p /etc/netplan
    __net-netplan_build
}

function __net-netplan_build { 
    # backup exsisting netplan configs
    for f in /etc/netplan/*.yaml; do chmod 600 "$f" && mv "$f" $(echo $f|sed 's/.yaml/.yaml.old/g'); done

    if [[ -n ${JB_NETPLAN} ]];then # custom netplan exists
      echo "${JB_NETPLAN}" > /etc/netplan/dure_network.yaml
      chmod 600 /etc/netplan/dure_network.yaml 2>&1 1>/dev/null
    else # custom netplan not exists
      tee /etc/netplan/dure_network.yaml > /dev/null <<EOT
network:
  version: 2
  renderer: networkd
  ethernets:
EOT
      local waninf=${JB_WANINF} laninf=${JB_LANINF} wlaninf=${JB_WLANINF}
      # generate netplan when waninf, laninf, wlaninf is all empty
      if [[ -z ${waninf} && -z ${laninf} && -z ${wlaninf} ]]; then
        local dure_infs=$(cat /proc/net/dev|awk '{ print $1 };'|grep :|grep -v lo:)
        IFS=$'\n' read -rd '' -a dure_infs <<< "${dure_infs//:}"

        # match interface name
        for((j=0;j<${#dure_infs[@]};j++)){
            if [[ ${dure_infs[j]:0:1} != 'w' && ! ${waninf} ]]; then
            [[ ! ${waninf} && ${dure_infs[j]} != "${laninf}" && ${dure_infs[j]} != "${wlaninf}" ]] && waninf=${dure_infs[j]} && continue
            fi
            if [[ ${dure_infs[j]:0:1} != 'w' && ! ${laninf} ]]; then
            [[ ! ${laninf} && ${dure_infs[j]} != "${waninf}" && ${dure_infs[j]} != "${wlaninf}" ]] && laninf=${dure_infs[j]} && continue
            fi
            if [[ ${dure_infs[j]:0:1} = 'w' && ! ${wlaninf} ]]; then
            [[ ! ${wlaninf} && ${dure_infs[j]} != "${laninf}" && ${dure_infs[j]} != "${waninf}" ]] && wlaninf=${dure_infs[j]} && continue
            fi
        }
        sed -i "s|JB_WANINF=.*|JB_WANINF=${waninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WAN} ]] && sed -i "s|JB_WAN=.*|JB_WAN=\"dhcp\"|g" "${JB_DEPLOY_PATH}/.config"
        sed -i "s|JB_LANINF=.*|JB_LANINF=${laninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_LAN} ]] && sed -i "s|JB_LAN=.*|JB_LAN=\"192.168.1.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
        sed -i "s|JB_WLANINF=.*|JB_WLANINF=${wlaninf}|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"192.168.100.1/24\"|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN_SSID} ]] && sed -i "s|JB_WLAN_SSID=.*|JB_WLAN_SSID=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
        [[ -z ${JB_WLAN_PASS} ]] && sed -i "s|JB_WLAN=.*|JB_WLAN=\"durejangbi\"|g" "${JB_DEPLOY_PATH}/.config"
      fi

      for((j=0;j<${#dure_infs[@]};j++)){
        if [[ ${dure_infs[j]} = "${waninf}" ]]; then # match JB_WANINF
          if [[ ${JB_WAN,,} = "dhcp" || ${JB_WAN} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${waninf}:
      dhcp4: true
EOT
          else
            if [[ ! ${JB_WANGW} ]]; then
              WANGW=$(ipcalc-ng "${JB_WAN}"|grep HostMin:|cut -f2)
            else
              WANGW=${JB_WANGW}
            fi
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${waninf}:
      dhcp4: false
      addresses: [${JB_WAN}]
      routes:
        - to: 0.0.0.0/0
          via: ${WANGW}
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${laninf}" ]]; then # match JB_LANINF
          if [[ ${JB_LAN,,} = "dhcp" || ${JB_LAN} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: true
EOT
          else
            if [[ ! ${JB_LANGW} ]]; then
              LANGW=$(ipcalc-ng "${JB_LAN}"|grep HostMin:|cut -f2)
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: false
      addresses: [${JB_LAN}]
EOT
            else
              LANGW=${JB_LANGW}
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: false
      addresses: [${JB_LAN}]
      routes:
        - to: 0.0.0.0/0
          via: ${LANGW}
EOT
            fi
          fi
          continue
        fi
        #
        # searching & match JB_LAN0INF ~ JB_LAN9INF
        #
        if [[ ${dure_infs[j]} = "${JB_LAN0INF}" ]]; then # match JB_LAN0INF
          if [[ ${JB_LAN0,,} = "dhcp" || ${JB_LAN0} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN0INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN0INF}:
      dhcp4: false
      addresses: [${JB_LAN0}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN1INF}" ]]; then # match JB_LAN1INF
          if [[ ${JB_LAN1,,} = "dhcp" || ${JB_LAN1} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN1INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN1INF}:
      dhcp4: false
      addresses: [${JB_LAN1}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN2INF}" ]]; then # match JB_LAN2INF
          if [[ ${JB_LAN2,,} = "dhcp" || ${JB_LAN2} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN2INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN2INF}:
      dhcp4: false
      addresses: [${JB_LAN2}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN3INF}" ]]; then # match JB_LAN3INF
          if [[ ${JB_LAN3,,} = "dhcp" || ${JB_LAN3} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN3INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN3INF}:
      dhcp4: false
      addresses: [${JB_LAN3}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN4INF}" ]]; then # match JB_LAN4INF
          if [[ ${JB_LAN4,,} = "dhcp" || ${JB_LAN4} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN4INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN4INF}:
      dhcp4: false
      addresses: [${JB_LAN4}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN5INF}" ]]; then # match JB_LAN5INF
          if [[ ${JB_LAN5,,} = "dhcp" || ${JB_LAN5} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN5INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN5INF}:
      dhcp4: false
      addresses: [${JB_LAN5}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN6INF}" ]]; then # match JB_LAN6INF
          if [[ ${JB_LAN6,,} = "dhcp" || ${JB_LAN6} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN6INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN6INF}:
      dhcp4: false
      addresses: [${JB_LAN6}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN7INF}" ]]; then # match JB_LAN7INF
          if [[ ${JB_LAN7,,} = "dhcp" || ${JB_LAN7} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN7INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN7INF}:
      dhcp4: false
      addresses: [${JB_LAN7}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN8INF}" ]]; then # match JB_LAN8INF
          if [[ ${JB_LAN8,,} = "dhcp" || ${JB_LAN8} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN8INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN8INF}:
      dhcp4: false
      addresses: [${JB_LAN8}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${JB_LAN9INF}" ]]; then # match JB_LAN9INF
          if [[ ${JB_LAN9,,} = "dhcp" || ${JB_LAN9} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN9INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${JB_LAN9INF}:
      dhcp4: false
      addresses: [${JB_LAN9}]
EOT
          fi
          continue
        fi

        if [[ ${dure_infs[j]:0:1} != 'w' ]]; then # match REST
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${dure_infs[j]}:
      dhcp4: true
EOT
          continue
        fi
        if [[ ${dure_infs[j]} = "${wlaninf}" ]]; then # match JB_WLANINF
          if [[ ${JB_WLAN,,} = "dhcp" || ${JB_WLAN} = "" ]]; then # client, dhcp mode
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      access-points:
        "${JB_WLAN_SSID}":
          password: "${JB_WLAN_PASS}"
      dhcp4: yes
EOT
          else # gateway, wstunnel, ap mode, static gateway ip
            if [[ ! ${JB_WLANGW} ]]; then
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      addresses: [${JB_WLAN}]
      access-points:
        "${JB_WLAN_SSID}":
          password: "${JB_WLAN_PASS}"
      dhcp4: no
      dhcp6: no
EOT
            else
              WLANGW=${JB_WLANGW}
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      addresses: [${JB_WLAN}]
      access-points:
        "${JB_WLAN_SSID}":
          password: "${JB_WLAN_PASS}"
      dhcp4: no
      dhcp6: no
      routes:
        - to: 0.0.0.0/0
          via: ${WLANGW}
EOT
            fi
          fi
          continue
        fi
        if [[ ${dure_infs[j]:0:1} = 'w' ]]; then  # match REST
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${dure_infs[j]}:
      dhcp4: true
EOT
          continue
        fi
      }
      chmod 600 /etc/netplan/dure_network.yaml 2>&1 1>/dev/null
    fi
}

function __net-netplan_uninstall { 
    log_debug "Trying to uninstall net-netplan."
    apt purge -qy netplan.io
}

function __net-netplan_disable { 
    return 0
}

function __net-netplan_check { # running_status: 0 running, 1 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-netplan Check"

    # RUN_OS_SYSTEMD 1 - full systemd, 0 - disable completely, 2 - only journald
    [[ -z ${RUN_OS_SYSTEMD} ]] && \
        log_error "RUN_OS_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    [[ ${RUN_OS_SYSTEMD} == 0 ]] && \
        log_error "RUN_OS_SYSTEMD set to disable completely(RUN_OS_SYSTEMD=0)." && [[ $running_status -lt 20 ]] && running_status=20
    [[ ${RUN_OS_SYSTEMD} == 2 ]] && \
        log_error "RUN_OS_SYSTEMD set to only journald(RUN_OS_SYSTEMD=2)." && [[ $running_status -lt 20 ]] && running_status=20
    # check package netplan
    [[ $(dpkg -l|awk '{print $2}'|grep -c "netplan") -lt 1 ]] && \
        log_info "netplan is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if ~~running~~ configured
    #[[ -f /etc/netplan/dure_network.yaml ]] && \
    #    log_info "netplan is configured." && [[ $running_status -lt 0 ]] && running_status=0
    # check if running
    [[ $(systemctl status systemd-networkd 2>/dev/null|awk '{ print $2 }'|grep -c inactive) -lt 1 ]] && \
        log_info "systemd-networkd is running." && [[ $running_status -lt 1 ]] && running_status=1

    return 0
}

function __net-netplan_run {
    # Cannot call openvswitch: ovsdb-server.service is not running. msg is not relevant.
    netplan apply
    systemctl status systemd-networkd && return 0 || return 1
  return 0
}

complete -F __net-netplan_run net-netplan
