# shellcheck shell=bash
cite about-plugin
about-plugin 'netplan install configurations.'

function net-netplan {
  about 'netplan install configurations'
  group 'net'
    param '1: command'
    param '2: params'
    example '$ net-netplan check/install/uninstall/run'

    if [[ -z ${DURE_DEPLOY_PATH} ]]; then
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
    [[ $(dpkg -l|awk '{print $2}'|grep libnetplan0|wc -l) -lt 1 ]] && apt install -qy ./pkgs/libnetplan0*.deb
    [[ $(dpkg -l|awk '{print $2}'|grep python3-netifaces|wc -l) -lt 1 ]] && apt install -qy ./pkgs/python3-netifaces*.deb
    apt install -yq ./pkgs/netplan.io*.deb
    mkdir -p /etc/netplan
    __net-netplan_build
}

function __net-netplan_build { # UPDATE_FIRMWARE=0
    # backup exsisting netplan configs
    for f in /etc/netplan/*.yaml; do chmod 600 "$f" && mv "$f" $(echo $f|sed 's/.yaml/.yaml.old/g'); done

    if [[ -n ${DURE_NETPLAN} ]];then # custom netplan exists
      echo "${DURE_NETPLAN}" > /etc/netplan/dure_network.yaml
      chmod 600 /etc/netplan/dure_network.yaml 2>&1 1>/dev/null
    else # custom netplan not exists
      tee /etc/netplan/dure_network.yaml > /dev/null <<EOT
network:
  version: 2
  renderer: networkd
  ethernets:
EOT
      local waninf=${DURE_WANINF} laninf=${DURE_LANINF} wlaninf=${DURE_WLANINF}
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
        sed -i "s|DURE_WANINF=.*|DURE_WANINF=${waninf}|g" "${DURE_DEPLOY_PATH}/.config"
        [[ -z ${DURE_WAN} ]] && sed -i "s|DURE_WAN=.*|DURE_WAN=\"dhcp\"|g" "${DURE_DEPLOY_PATH}/.config"
        sed -i "s|DURE_LANINF=.*|DURE_LANINF=${laninf}|g" "${DURE_DEPLOY_PATH}/.config"
        [[ -z ${DURE_LAN} ]] && sed -i "s|DURE_LAN=.*|DURE_LAN=\"192.168.1.1/24\"|g" "${DURE_DEPLOY_PATH}/.config"
        sed -i "s|DURE_WLANINF=.*|DURE_WLANINF=${wlaninf}|g" "${DURE_DEPLOY_PATH}/.config"
        [[ -z ${DURE_WLAN} ]] && sed -i "s|DURE_WLAN=.*|DURE_WLAN=\"192.168.100.1/24\"|g" "${DURE_DEPLOY_PATH}/.config"
        [[ -z ${DURE_WLAN_SSID} ]] && sed -i "s|DURE_WLAN_SSID=.*|DURE_WLAN_SSID=\"durejangbi\"|g" "${DURE_DEPLOY_PATH}/.config"
        [[ -z ${DURE_WLAN_PASS} ]] && sed -i "s|DURE_WLAN=.*|DURE_WLAN=\"durejangbi\"|g" "${DURE_DEPLOY_PATH}/.config"
      fi

      for((j=0;j<${#dure_infs[@]};j++)){
        if [[ ${dure_infs[j]} = "${waninf}" ]]; then # match DURE_WANINF
          if [[ ${DURE_WAN,,} = "dhcp" || ${DURE_WAN} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${waninf}:
      dhcp4: true
EOT
          else
            if [[ ! ${DURE_WANGW} ]]; then
              WANGW=$(ipcalc-ng "${DURE_WAN}"|grep HostMin:|cut -f2)
            else
              WANGW=${DURE_WANGW}
            fi
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${waninf}:
      dhcp4: false
      addresses: [${DURE_WAN}]
      routes:
        - to: 0.0.0.0/0
          via: ${WANGW}
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${laninf}" ]]; then # match DURE_LANINF
          if [[ ${DURE_LAN,,} = "dhcp" || ${DURE_LAN} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: true
EOT
          else
            if [[ ! ${DURE_LANGW} ]]; then
              LANGW=$(ipcalc-ng "${DURE_LAN}"|grep HostMin:|cut -f2)
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: false
      addresses: [${DURE_LAN}]
EOT
            else
              LANGW=${DURE_LANGW}
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${laninf}:
      dhcp4: false
      addresses: [${DURE_LAN}]
      routes:
        - to: 0.0.0.0/0
          via: ${LANGW}
EOT
            fi
          fi
          continue
        fi
        #
        # searching & match DURE_LAN0INF ~ DURE_LAN9INF
        #
        if [[ ${dure_infs[j]} = "${DURE_LAN0INF}" ]]; then # match DURE_LAN0INF
          if [[ ${DURE_LAN0,,} = "dhcp" || ${DURE_LAN0} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN0INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN0INF}:
      dhcp4: false
      addresses: [${DURE_LAN0}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN1INF}" ]]; then # match DURE_LAN1INF
          if [[ ${DURE_LAN1,,} = "dhcp" || ${DURE_LAN1} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN1INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN1INF}:
      dhcp4: false
      addresses: [${DURE_LAN1}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN2INF}" ]]; then # match DURE_LAN2INF
          if [[ ${DURE_LAN2,,} = "dhcp" || ${DURE_LAN2} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN2INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN2INF}:
      dhcp4: false
      addresses: [${DURE_LAN2}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN3INF}" ]]; then # match DURE_LAN3INF
          if [[ ${DURE_LAN3,,} = "dhcp" || ${DURE_LAN3} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN3INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN3INF}:
      dhcp4: false
      addresses: [${DURE_LAN3}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN4INF}" ]]; then # match DURE_LAN4INF
          if [[ ${DURE_LAN4,,} = "dhcp" || ${DURE_LAN4} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN4INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN4INF}:
      dhcp4: false
      addresses: [${DURE_LAN4}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN5INF}" ]]; then # match DURE_LAN5INF
          if [[ ${DURE_LAN5,,} = "dhcp" || ${DURE_LAN5} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN5INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN5INF}:
      dhcp4: false
      addresses: [${DURE_LAN5}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN6INF}" ]]; then # match DURE_LAN6INF
          if [[ ${DURE_LAN6,,} = "dhcp" || ${DURE_LAN6} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN6INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN6INF}:
      dhcp4: false
      addresses: [${DURE_LAN6}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN7INF}" ]]; then # match DURE_LAN7INF
          if [[ ${DURE_LAN7,,} = "dhcp" || ${DURE_LAN7} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN7INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN7INF}:
      dhcp4: false
      addresses: [${DURE_LAN7}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN8INF}" ]]; then # match DURE_LAN8INF
          if [[ ${DURE_LAN8,,} = "dhcp" || ${DURE_LAN8} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN8INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN8INF}:
      dhcp4: false
      addresses: [${DURE_LAN8}]
EOT
          fi
          continue
        fi
        if [[ ${dure_infs[j]} = "${DURE_LAN9INF}" ]]; then # match DURE_LAN9INF
          if [[ ${DURE_LAN9,,} = "dhcp" || ${DURE_LAN9} = "" ]]; then
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN9INF}:
      dhcp4: true
EOT
          else
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
    ${DURE_LAN9INF}:
      dhcp4: false
      addresses: [${DURE_LAN9}]
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
        if [[ ${dure_infs[j]} = "${wlaninf}" ]]; then # match DURE_WLANINF
          if [[ ${DURE_WLAN,,} = "dhcp" || ${DURE_WLAN} = "" ]]; then # client, dhcp mode
            tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      access-points:
        "${DURE_WLAN_SSID}":
          password: "${DURE_WLAN_PASS}"
      dhcp4: yes
EOT
          else # gateway, wstunnel, ap mode, static gateway ip
            if [[ ! ${DURE_WLANGW} ]]; then
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      addresses: [${DURE_WLAN}]
      access-points:
        "${DURE_WLAN_SSID}":
          password: "${DURE_WLAN_PASS}"
      dhcp4: no
      dhcp6: no
EOT
            else
              WLANGW=${DURE_WLANGW}
              tee -a /etc/netplan/dure_network.yaml > /dev/null <<EOT
  wifis:
    ${wlaninf}:
      addresses: [${DURE_WLAN}]
      access-points:
        "${DURE_WLAN_SSID}":
          password: "${DURE_WLAN_PASS}"
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

function __net-netplan_uninstall { # UPDATE_FIRMWARE=0
    log_debug "Trying to uninstall net-netplan."
    apt purge -qy netplan.io
}

function __net-netplan_check { # running_status 0 installed, running_status 5 can install, running_status 10 can't install, 20 skip
    running_status=0
    log_debug "Starting net-netplan Check"

    # check global variable, netplan depends on systemd config
    [[ ${DISABLE_SYSTEMD} -lt 1 ]] && \
        log_info "DISABLE_SYSTEMD variable is not set." && [[ $running_status -lt 10 ]] && running_status=10
    # check package netplan
    [[ $(dpkg -l|awk '{print $2}'|grep -c "netplan") -lt 1 ]] && \
        log_info "netplan is not installed." && [[ $running_status -lt 5 ]] && running_status=5
    # check if ~~running~~ configured
    [[ -f /etc/netplan/dure_network.yaml ]] && \
        log_info "netplan is configured." && [[ $running_status -lt 0 ]] && running_status=0

    return 0
}

function __net-netplan_run {
    # Cannot call openvswitch: ovsdb-server.service is not running. msg is not relevant.
    netplan apply
    systemctl status systemd-networkd && return 0 || return 1
  return 0
}

complete -F __net-netplan_run net-netplan
