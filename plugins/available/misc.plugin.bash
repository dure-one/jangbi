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
