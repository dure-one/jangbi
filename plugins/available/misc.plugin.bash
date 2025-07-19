## \brief miscellaneous tools and utilities.
## \desc This plugin provides a collection of miscellaneous utility functions
## for network diagnostics, file operations, and system information gathering.
## It includes tools for IP address detection, website availability checking,
## random file operations, and various system utilities for daily administration tasks.

## \exit 1 Invalid command or parameters provided.

# shellcheck shell=bash
cite about-plugin
about-plugin 'miscellaneous tools'

if _command_exists mkisofs; then
    function mkiso() {
        about 'creates iso from current dir in the parent dir (unless defined)'
        param '1: ISO name'
        param '2: dest/path'
        param '3: src/path'
        example 'mkiso'
        example 'mkiso ISO-Name dest/path src/path'
        group 'base'

        local isoname="${1:-${PWD##*/}}"
        local destpath="${2:-../}"
        local srcpath="${3:-${PWD}}"

        if [[ ! -f "${destpath%/}/${isoname}.iso" ]]; then
            echo "writing ${isoname}.iso to ${destpath} from ${srcpath}"
            mkisofs -V "${isoname}" -iso-level 3 -r -o "${destpath%/}/${isoname}.iso" "${srcpath}"
        else
            echo "${destpath%/}/${isoname}.iso already exists"
        fi
    }
fi

function wol() {
    about 'sends wake-on-lan magic packet'
    group 'base'
    param '1: MAC address'
    param '2: broadcast address'
    param '3: port (default: 9)'
    example 'wol 00:11:22:33:44:55 192.168.1.255 9'
    example 'wol 00:11:22:33:44:55 192.168.1.255'
    example 'wol 00:11:22:33:44:55' # uses default broadcast and port
    if [[ $# -lt 1 ]]; then
        echo "Usage: wol <mac-address> [<broadcast-address>] [<port>]"
        return 1
    fi
    # Validate MAC address format
    if ! [[ "$1" =~ ^([0-9a-fA-F]{2}[:-]){5}([0-9a-fA-F]{2})$ ]]; then
        echo "Invalid MAC address format: $1"
        return 1
    fi
    # Validate broadcast address format
    if [[ $# -ge 2 ]] && ! [[ "$2" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Invalid broadcast address format: $2"
        return 1
    fi
    # Validate port number
    if [[ $# -ge 3 ]] && ! [[ "$3" =~ ^[0-9]{1,5}$ ]] || [[ "$3" -lt 1 ]] || [[ "$3" -gt 65535 ]]; then
        echo "Invalid port number: $3"
        return 1
    fi
    local macaddr bcast port tmac mpack
    macaddr="$1"
    bcast="$2"
    port="${3:-9}"
    tmac=$(echo "$macaddr" | sed 's/[ :-]//g')
    mpack=$(
        printf 'f%.0s' {1..12}
        printf "${tmac}%.0s" {1..16}
    )
    mpack=$(
        echo "$mpack" | sed -e 's/../\\x&/g'
    )
    echo -e "$mpack" | nc -w1 -u "$bcast" "$port"
}