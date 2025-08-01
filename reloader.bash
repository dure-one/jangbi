# shellcheck shell=bash
#
# The core component loader.

# shellcheck disable=SC2034
BASH_IT_LOG_PREFIX="core: reloader: "
_bash_it_reloader_type=""

if [[ "${1:-}" != "skip" ]] && [[ -d "${JANGBI_IT?}/enabled" ]]; then
	case $1 in
		plugin)
			_bash_it_reloader_type=$1
			[[ ! $SKIP_LOG ]] && log_trace "Loading enabled $1 components..."
			;;
		'' | *)
			[[ ! $SKIP_LOG ]] && log_trace "Loading all enabled components..."
			;;
	esac

	for _bash_it_reloader_file in "$JANGBI_IT/enabled"/*"${_bash_it_reloader_type}.bash"; do
		if [[ -e "${_bash_it_reloader_file}" ]]; then
			_bash-it-log-prefix-by-path "${_bash_it_reloader_file}"
			[[ ! $SKIP_LOG ]] && log_trace "Loading ${_bash_it_reloader_file} component..."
			# shellcheck source=/dev/null
			source "$_bash_it_reloader_file"
			[[ ! $SKIP_LOG ]] && log_trace "Loaded."
		else
			log_trace "Unable to read ${_bash_it_reloader_file}"
		fi
	done
fi

if [[ -n "${2:-}" ]] && [[ -d "$JANGBI_IT/${2}/enabled" ]]; then
	case $2 in
		plugins)
			log_warning "Using legacy enabling for $2, please update your bash-it version and migrate"
			for _bash_it_reloader_file in "$JANGBI_IT/${2}/enabled"/*.bash; do
				if [[ -e "$_bash_it_reloader_file" ]]; then
					_bash-it-log-prefix-by-path "${_bash_it_reloader_file}"
					[[ ! $SKIP_LOG ]] && log_trace "Loading ${_bash_it_reloader_file} component..."
					# shellcheck source=/dev/null
					source "$_bash_it_reloader_file"
					[[ ! $SKIP_LOG ]] && log_trace "Loaded."
				else
					log_trace "Unable to locate ${_bash_it_reloader_file}"
				fi
			done
			;;
	esac
fi

unset "${!_bash_it_reloader_@}"