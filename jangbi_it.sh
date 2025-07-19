#!/usr/bin/env bash
# https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html
# BASH_IT_LOG_LEVEL=7
BASH_IT_LOG_PREFIX="core: main: "
: "${BASH_IT:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
: "${BASH_IT_CUSTOM:=${BASH_IT}/custom}"
: "${BASH_IT_BASHRC:=${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}}"
JANGBI_IT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ ${BASH_IT} != ${JANGBI_IT} ]] && BASH_IT_=${BASH_IT}
BASH_IT="${JANGBI_IT}/vendor/bash-it"
BASH_IT_LOG_FILE="${BASH_IT_LOG_FILE:-${JANGBI_IT}/output.log}"

source "${BASH_IT}/vendor/github.com/erichs/composure/composure.sh"
# regenerate composure keywords
_composure_keywords ()
{
  echo "about author example group param version deps runtype"
}
_bootstrap_composure() {
  _generate_metadata_functions
  _load_composed_functions
  _determine_printf_cmd
}
_bootstrap_composure

# support 'plumbing' metadata
cite _about _param _example _group _author _version _deps _runtype
cite about-alias about-plugin about-completion

# Declare our end-of-main finishing hook, but don't use `declare`/`typeset`
_bash_it_library_finalize_hook=()

source "${BASH_IT}/lib/colors.bash"
# convert slib logsystem to bash-it logsystem 
source "${JANGBI_IT}/vendor/slib/slib.sh"
# We need to load logging module early in order to be able to log
source "${BASH_IT}/lib/log.bash"
unset log

log_and_tee() {
  printf '%s%s\n' "[$(date +"%Y-%m-%d %H:%M:%S %Z")] " "$@" | tee -a "${BASH_IT_LOG_FILE}"
} # BASH_IT_LOG_LEVEL=5 # 0 - no log, 1 - fatal, 3 - error, 4 - warning, 5 - debug, 6 - info, 6 - all, 7 - trace, 
log_info()   { [[ "${BASH_IT_LOG_LEVEL:-0}" -ge "${BASH_IT_LOG_LEVEL_INFO?}" ]] && printf '%b%s%b\n' "${echo_cyan:-}" "$@" "${echo_normal:-}" && log_and_tee "$@"; }
log_success(){ printf '%b%s%b\n' "${echo_blue:-}" "$@" "${echo_normal:-}" && log_and_tee "$@"; } # 6 - info
log_fatal()  { printf '%b%s%b\n' "${echo_background_red:-}" "$@" "${echo_normal:-}" && log_and_tee "$@"; } # 1 - fatal
log_error()  { _log_error "$@" && log_and_tee "$@"; } # 3 - error
log_warning(){ _log_warning "$@" && log_and_tee "$@"; } # 4 - warning
log_debug()  { _log_debug "$@" && log_and_tee "$@"; } # 5 - debug

# libraries, but skip appearance (themes) for now
source "${BASH_IT}/lib/command_duration.bash"
source "${BASH_IT}/lib/helpers.bash"

function _help-plugins() {
	_about 'summarize all functions defined by enabled jangbi-it plugins'
	_group 'lib'

	local grouplist func group about gfile defn
	# display a brief progress message...
	printf '%s' 'please wait, building help...'
	grouplist="$(mktemp -t grouplist.XXXXXX)"
	while read -ra func; do
		defn="$(declare -f "${func[2]}")"
		group="$(metafor group <<< "$defn")"
		if [[ -z "$group" ]]; then
			group='misc'
		fi
		about="$(metafor about <<< "$defn")"
		_letterpress "$about" "${func[2]}" >> "$grouplist.$group"
		echo "$grouplist.$group" >> "$grouplist"
	done < <(declare -F)
	# clear progress message
	printf '\r%s\n' '                              '
	while IFS= read -r gfile; do
		printf '%s\n' "${gfile##*.}:"
		cat "$gfile"
		printf '\n'
		rm "$gfile" 2> /dev/null
	done < <(sort -u "$grouplist") | less
	rm "$grouplist" 2> /dev/null
}

# no bash-it env, remove bash-it
[[ ! ${BASH_IT_} ]] && unset bash-it reload_completion reload_aliases
# shellcheck disable=SC2139
alias reload_plugins="$(_make_reload_alias plugin plugins)"

function jangbi-it() {
	about 'Jangbi-it help and maintenance'
	param '1: verb [one of: help | show | enable | disable | doctor | restart | reload ] '
	param '2: component type [one of: plugin(s) ] or search term(s)'
	param '3: specific component [optional]'
	example '$ jangbi-it show plugins'
	example '$ jangbi-it enable plugin git [tmux]...'
	example '$ jangbi-it doctor errors|warnings|all'
  BASH_IT="${JANGBI_IT}"
	local verb=${1:-}
	shift
	local component=${1:-}
	shift
	local func

	case "$verb" in
		show)
			func="_bash-it-$component"
			;;
		enable)
			func="_enable-$component"
			;;
		disable)
			func="_disable-$component"
			;;
		help)
			func="_help-$component"
			;;
		doctor)
			func="_bash-it-doctor-$component"
			;;
    restart)
			func="_bash-it-restart"
			;;
    reload)
			func="reload_plugins"
      ;;
		*)
			reference "jangbi-it"
			return
			;;
	esac

	# pluralize component if necessary
	if ! _is_function "$func"; then
		if _is_function "${func}s"; then
			func="${func}s"
		else
			if _is_function "${func}es"; then
				func="${func}es"
			else
				echo "oops! $component is not a valid option!"
				reference jangbi-it
				return
			fi
		fi
	fi

	if [[ "$verb" == "enable" || "$verb" == "disable" ]]; then
		# Automatically run a migration if required
		# _jangbi-it-migrate

		for arg in "$@"; do
			"$func" "$arg"
		done

		if [[ -n "${BASH_IT_AUTOMATIC_RELOAD_AFTER_CONFIG_CHANGE:-}" ]]; then
			_jangbi-it-reload
		fi
	else
		"$func" "$@"
	fi

  # recover bash_it var
  [[ ${BASH_IT_} ]] && BASH_IT=${BASH_IT_}
}

source "${BASH_IT}/lib/preexec.bash"
source "${BASH_IT}/lib/utilities.bash"

# Load the global "enabled" directory, then enabled aliases, completion, plugins
# "_bash_it_main_file_type" param is empty so that files get sourced in glob order
for _bash_it_main_file_type in "" "plugins"; do
	BASH_IT_LOG_PREFIX="core: reloader: "
	# shellcheck disable=SC2140
	source "${JANGBI_IT}/reloader.bash" ${_bash_it_main_file_type:+"skip" "$_bash_it_main_file_type"}
	BASH_IT_LOG_PREFIX="core: main: "
done

for _bash_it_library_finalize_f in "${_bash_it_library_finalize_hook[@]:-}"; do
	eval "${_bash_it_library_finalize_f?}" # Use `eval` to achieve the same behavior as `$PROMPT_COMMAND`.
done
unset "${!_bash_it_library_finalize_@}" "${!_bash_it_main_file_@}"

# recover bash_it var
[[ ${BASH_IT_} ]] && BASH_IT=${BASH_IT_}

_get_rip(){
  if [[ $(ip addr show dev "${1}" |grep inet|wc -l) -gt 1 ]]; then
    ip addr show dev "${1}" |grep inet|grep -v inet6|cut -d' ' -f6
  else
    echo "127.0.0.1"
  fi
}

_get_inf_of_infmark(){
  local inf=$1 tarinf
  if [[ ${inf,,} =~ ^(wan|lan|wlan|lan[0-9])$ ]]; then
    :
  else
    log_error "Interface ${inf} is not valid. Please set correct interface name in config."
    return 1
  fi
  if [[ ${inf,,} == "wan" ]]; then
    echo "${JB_WANINF}"
  elif [[ ${inf,,} == "lan" ]]; then
    echo "${JB_LANINF}"
  elif [[ ${inf,,} == "wlan" ]]; then
    echo "${JB_WLANINF}"
  elif [[ ${inf,,} == "lan0" ]]; then
    echo "${JB_LAN0INF}"
  elif [[ ${inf,,} == "lan1" ]]; then
    echo "${JB_LAN1INF}"
  elif [[ ${inf,,} == "lan2" ]]; then
    echo "${JB_LAN2INF}"
  elif [[ ${inf,,} == "lan3" ]]; then
    echo "${JB_LAN3INF}"
  elif [[ ${inf,,} == "lan4" ]]; then
    echo "${JB_LAN4INF}"
  elif [[ ${inf,,} == "lan5" ]]; then
    echo "${JB_LAN5INF}"
  elif [[ ${inf,,} == "lan6" ]]; then
    echo "${JB_LAN6INF}"
  elif [[ ${inf,,} == "lan7" ]]; then
    echo "${JB_LAN7INF}"
  elif [[ ${inf,,} == "lan8" ]]; then
    echo "${JB_LAN8INF}"
  else
    echo "${JB_LAN9INF}"
  fi
  return 0
}

_get_ip_of_infmark(){
  local inf=$1 tarinf
  if [[ ${inf,,} =~ ^(wan|lan|wlan|lan[0-9])$ ]]; then
    :
  else
    log_error "Interface ${inf} is not valid. Please set correct interface name in config."
    return 1
  fi

  if [[ ${inf,,} == "wan" ]]; then
    tarinf=${JB_WANINF}
  elif [[ ${inf,,} == "lan" ]]; then
    tarinf=${JB_LANINF}
  elif [[ ${inf,,} == "wlan" ]]; then
    tarinf=${JB_WLANINF}
  elif [[ ${inf,,} == "lan0" ]]; then
    tarinf=${JB_LAN0INF}
  elif [[ ${inf,,} == "lan1" ]]; then
    tarinf=${JB_LAN1INF}
  elif [[ ${inf,,} == "lan2" ]]; then
    tarinf=${JB_LAN2INF}
  elif [[ ${inf,,} == "lan3" ]]; then
    tarinf=${JB_LAN3INF}
  elif [[ ${inf,,} == "lan4" ]]; then
    tarinf=${JB_LAN4INF}
  elif [[ ${inf,,} == "lan5" ]]; then
    tarinf=${JB_LAN5INF}
  elif [[ ${inf,,} == "lan6" ]]; then
    tarinf=${JB_LAN6INF}
  elif [[ ${inf,,} == "lan7" ]]; then
    tarinf=${JB_LAN7INF}
  elif [[ ${inf,,} == "lan8" ]]; then
    tarinf=${JB_LAN8INF}
  else
    tarinf=${JB_LAN9INF}
  fi
  if [[ ! ${tarinf} ]]; then
    log_error "Interface ${inf}/${tarinf} is not set. Please set correct interface name in config."
    return 1
  fi
  _get_ip_of_inf "${tarinf}"
  return 0
}

_get_ip_of_inf(){
  local tarinf
  tarinf=${1,,}
  if [[ -n ${!tarinf} ]]; then
    log_error "Interface ${tarinf} is not set. Please set correct interface name in config."
    return 1
  fi
  if [[ $(ip link show "${tarinf}" 2>/dev/null|grep -c "state UP") -lt 1 ]]; then
    log_error "Interface ${tarinf} is not up."
    return 1
  fi
  if [[ $(ip addr show "${tarinf}" 2>/dev/null|grep -c "inet ") -lt 1 ]]; then
    log_error "Interface ${tarinf} has no IP address."
    return 1
  fi
  local infip=$(ip addr show "${tarinf}" |grep inet |grep -v inet6 |awk '{print $2}'|cut -d'/' -f1)
  if [[ -z ${infip} ]]; then
    log_error "Interface ${tarinf} has no IP address."
    return 1
  fi
  echo "${infip}"
  return 0
}

_trim_string() { # Usage: _trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

_load_config() { # Load config including parent config ex) _load_config .config
  local conf=".config"
  JB_VARS=""
  # log_debug "Load config from ${JANGBI_IT}/${conf}" 
  [[ ! -f "${JANGBI_IT}/${conf}" ]] && log_fatal "config file ${JANGBI_IT}/${conf} not exist." && _safe_exit 1
  stack=()
  pushstk() { stack+=("$@"); }
  # track config to top
  while [[ -n ${conf} ]] ;
  do
    pushstk ${conf//\"/}
    if [[ $(cat ${JANGBI_IT}/${conf//\"/}|grep -c ^PARENT_CONFIG) -gt 0 ]]; then
      conf=$(cat ${JANGBI_IT}/${conf//\"/}|grep PARENT_CONFIG|cut -d= -f2)
    else
      conf=
    fi
  done
  # echo "load next configs : ${stack[@]}"
  # load config in order
  for((j=${#stack[@]};j>0;j--)){
    conf=${stack[j-1]}
    # echo "config file(${conf}) is loading..."
    [[ -f ${JANGBI_IT}/${conf} ]] && source ${JANGBI_IT}/${conf}
    JB_VARS="${JB_VARS} $(cat ${JANGBI_IT}/${conf}|grep -v '^#'|grep .|cut -d= -f1)"
    JB_CFILES="${JB_CFILES} ${conf}"
  }
  JB_VARS="${JB_VARS} JB_CFILES"

  # setup slog
  log_debug "LOGFILE: $LOGFILE LOG_PATH: $LOG_PATH RUN_LOG: $RUN_LOG"
  LOGFILE=${LOGFILE:="output.log"}
  LOG_PATH=${LOG_PATH:="output.log"}
  RUN_LOG=${RUN_LOG:="output.log"}
  # RUN_ERRORS_FATAL=${RUN_ERRORS_FATAL:=1}
  # LOG_LEVEL_STDOUT=${LOG_LEVEL_STDOUT:="INFO"}
  # LOG_LEVEL_LOG=${LOG_LEVEL_LOG:="DEBUG"}
  # RUN_LOG="/dev/null"
}

_checkbin() {
  if ! which "${1}" 1>/dev/null 2>&1;then
    log_fatal "You must install '${1}'."
    return 1
  fi
}

_safe_exit() {
  local exit_code=${1:-1}
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is executed directly
    exit "$exit_code"
  else
    # Script is sourced
    return "$exit_code"
  fi
}

_root_only() {
  if [[ $EUID -ne 0 ]]; then
    log_fatal "This script must be run as root"
    _safe_exit 1
  fi
}

_distname_check() {
  sysosinfo=$(lsb_release -i|awk '{print tolower($3)}')_$(lsb_release -cs)_$(arch)

  if [[ ${DIST_NAME,,} != ${sysosinfo,,} ]]; then
    log_fatal "DIST_NAME=${DIST_NAME} on  config is different system value(${sysosinfo})"
    _safe_exit 1
  else
  log_debug "Running system(${sysosinfo}) match DIST_NAME config(${DIST_NAME})."
  fi
}

_download_apt_pkgs() { # _download_apt_pkgs darkstat
  local pkgs=($1)
  local pkgname=$(_trim_string ${pkgs[0]})
  [[ $(find /etc/apt/sources.list.d|grep -c "extrepo_debian_official") -lt 1 ]] && extrepo enable debian_official
  [[ $(stat /var/lib/apt/lists -c "%X") -lt $(date -d "1 day ago" +%s) ]] && apt update -qy
  # [[ ! -f .task-ssh-server ]] && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends task-ssh-server| grep "^\w" > .task-ssh-server
  [[ ! -f .task-desktop ]] && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends task-desktop| grep "^\w" > .task-desktop
  # [[ ! -f .task-ssh-server ]] && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends task-ssh-server| grep "^\w" > .task-ssh-server
  apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends $1| grep "^\w" > /tmp/compare_pkg
  grep -Fxv -f .task-desktop /tmp/compare_pkg > /tmp/unique_pkg
  pushd "${JANGBI_IT}/pkgs" 1>/dev/null 2>&1
  cp /tmp/unique_pkg "${pkgname}.pkgs"
  apt download $(</tmp/unique_pkg)
  popd 1>/dev/null 2>&1
}

_download_github_pkgs(){ # _download_github_pkgs DNSCrypt/dnscrypt-proxy dnscrypt-proxy-linux*.tar.gz
  local arch1 arch2 
  arch1=$(dpkg --print-architecture)
  arch2=$(arch)
  [[ -n ${3} ]] && arch1=${3}
  [[ -n ${4} ]] && arch2=${4}
  [[ $(echo $1|grep -c "/") != 1 ]] && log_debug "please set githubid/repoid." && return 1
  local pkgurl="https://api.github.com/repos/$(_trim_string $1)/releases/latest"
  # log_debug "DownloadURL : ${pkgurl}"
  IFS=$'\*' read -rd '' -a pkgfilefix <<<"$(_trim_string $2)"
  [[ $(find ${JANGBI_IT}/pkgs/$2 2>/dev/null|wc -l) -gt 0 ]] && rm ${JANGBI_IT}/pkgs/$2
  pkgfileprefix=$(_trim_string ${pkgfilefix[0],,})
  pkgfilepostfix=$(_trim_string ${pkgfilefix[1],,})
  local possible_list=$(curl -sSL "${pkgurl}" | jq -r '.assets[] | select(.name | contains("'${arch1}'") or contains("'${arch2}'")) | .browser_download_url')
  # log_debug "List : ${possible_list}"
  IFS=$'\n' read -rd '' -a durls <<<"$possible_list"

  if [[ ${#durls[@]} -gt 1 ]]; then
    for((k=0;k<${#durls[@]};k++)){ # sysdig-0.40.1-x86_64.deb dnscrypt-proxy-linux_x86_64-2.1.12.tar.gz
      durl=$(_trim_string ${durls[k],,});
      if [[ ${durl} == *"${pkgfileprefix}"* && ${durl} == *"${pkgfilepostfix}" ]]; then
        log_debug "Downloading(type1) ${durl} to ${pkgfileprefix} ${pkgfilepostfix}..."
        wget --directory-prefix=${JANGBI_IT}/pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        return 0
      fi
    }
    for((k=0;k<${#durls[@]};k++)){ # hysteria-linux-amd64 
      durl=$(_trim_string ${durls[k],,});
      if [[ ${durl} == *"${pkgfileprefix}"* && ${durl} == *"linux"* ]]; then
        log_debug "Downloading(type2) ${durl} to ${arch1} ${pkgfilepostfix}..."
        wget --directory-prefix=${JANGBI_IT}/pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        return 0
      fi
    }
    for((k=0;k<${#durls[@]};k++)){ #
      durl=$(_trim_string ${durls[k],,});
      if [[ ${durl} == *"${arch1}"* && ${durl} == *"${pkgfilepostfix}" ]]; then
        log_debug "Downloading(type3) ${durl} to ${arch1} ${pkgfilepostfix}..."
        wget --directory-prefix=${JANGBI_IT}/pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        return 0
      fi
    }
    for((k=0;k<${#durls[@]};k++)){ #
      durl=$(_trim_string ${durls[k],,});
      if [[ ${durl} == *"${arch2}"* && ${durl} == *"${pkgfilepostfix}" ]]; then
        log_debug "Downloading(type4) ${durl} to ${arch2} ${pkgfilepostfix}..."
        wget --directory-prefix=${JANGBI_IT}/pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        return 0
      fi
    }
  fi
  log_error "No matching package found for ${pkgfileprefix} ${comparch} ${pkgfilepostfix} in ${possible_list}"
  return 1
}

_blank(){
  :
}

_time_sync(){
  # date -s "$(curl -s --head ${1} | grep ^Date: | sed 's/Date: //g')"
  log_debug "Syncing system time with 1.1. Taking time."
  sudo date -us "$(curl -Is 1.1 | sed -n 's/^Date://p')"
}

# _get_delay() { # UDP comms on bash not working
# 	TIMESERVER="$1"
# 	TIMES="${2:-20}"
# 	TIMEPORT=123
# 	TIME1970=2208988800      # Thanks to F.Lundh 0x 0xD2AA5F0
# 	exec 6<>/dev/udp/$TIMESERVER/$TIMEPORT &&
# 	echo -en "\x1b\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" >&6 \
# 		|| echo "error writing to $TIMESERVER $TIMEPORT"
# 		read -u 6 -n 1 -t 2 || { echo "*"; return; }

# 	for (( n=0; n<TIMES; n++ )); do
# 		echo -en "\x1b\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" >&6 \
# 		|| echo "error writing to $TIMESERVER $TIMEPORT"
# 		REPLY="$(dd bs=50 count=1 <&6 | dd skip=32 bs=1 count=16 | xxd -p)"
# 		echo -n "."
#     echo "${REPLY}"

# 		seconds="${REPLY:0:8}"
# 		secondsf="${REPLY:8:8}"

# 		sec=0x$( echo -n "$seconds" )
# 		secf=0x$( echo -n "$secondsf" )
# 		(( i_seconds = $sec - TIME1970 ))
# 		(( i_secondsf = ( 1000 * $secf / 0xffffffff ) ))
# 		# echo i_seconds: $i_seconds.$i_secondsf
# 		s[$n]=$i_seconds
# 		m[$n]=$i_secondsf
# 	done
# 	echo

# 	# declare -p s m

# 	for (( m=1; m<TIMES-1; m++)); do
# 		(( n = m + 1 ))
# 		# (( d[$m] = ( 1000 * ( s[$n] - s[$m] ) ) + $m[$n] - $m[$m] ))
# 		(( d[m] = ( 1000 * ( s[n] - s[m] ) ) + m[n] - m[m] ))
# 		printf "%s\n" "${d[$m]} ms"
# 	done
# } 2>/dev/null

_ip2conv() {
  IFS=. read a b c d <<< "$1"
  echo "$(((a<<24)+(b<<16)+(c<<8)+d))"
}

