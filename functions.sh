#!/usr/bin/env bash
JANGBI_IT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# bash_it.sh
# Initialize Bash It
JANGBI_IT_LOG_PREFIX="core: main: "
: "${JANGBI_IT:=${BASH_SOURCE%/*}}"
: "${JANGBI_IT_CUSTOM:=${JANGBI_IT}/custom}"
: "${CUSTOM_THEME_DIR:="${JANGBI_IT_CUSTOM}/themes"}"
: "${JANGBI_IT_BASHRC:=${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}}"

# Load composure first, so we support function metadata
### start of composure ###
# https://github.com/Bash-it/jangbi-it/blob/master/vendor/github.com/erichs/composure/composure.sh

# composure - by erichs
# light-hearted functions for intuitive shell programming

# version: 1.3.1
# latest source available at http://git.io/composure

# install: source this script in your ~/.profile or ~/.${SHELL}rc script
# known to work on bash, zsh, and ksh93

# 'plumbing' functions

_bootstrap_composure() {
  _generate_metadata_functions
  _load_composed_functions
  _determine_printf_cmd
}

_get_composure_dir ()
{
  if [ -n "${XDG_DATA_HOME:-}" ]; then
    echo "$XDG_DATA_HOME/composure"
  else
    echo "$HOME/.local/composure"
  fi
}

_get_author_name ()
{
  typeset name localname
  localname="$(git --git-dir "$(_get_composure_dir)/.git" config --get user.name)"
  for name in "${GIT_AUTHOR_NAME:-}" "$localname"; do
    if [ -n "$name" ]; then
      echo "$name"
      break
    fi
  done
}

_composure_keywords ()
{
  echo "about author example group param version deps runtype"
}

_letterpress ()
{
  typeset rightcol="$1" leftcol="${2:- }" leftwidth="${3:-20}"

  if [ -z "$rightcol" ]; then
    return
  fi

  $_printf_cmd "%-*s%s\n" "$leftwidth" "$leftcol" "$rightcol"
}

_determine_printf_cmd() {
  if [ -z "${_printf_cmd:-}" ]; then
    _printf_cmd=printf
    # prefer GNU gprintf if available
    [ -x "$(which gprintf 2>/dev/null)" ] && _printf_cmd=gprintf
    export _printf_cmd
  fi
}

_longest_function_name_length ()
{
  echo "$1" | awk 'BEGIN{ maxlength=0 }
  {
  for(i=1;i<=NF;i++)
    if (length($i)>maxlength)
    {
    maxlength=length($i)
    }
  }
  END{ print maxlength}'
}

_temp_filename_for ()
{
  typeset file="$(mktemp "/tmp/$1.XXXX")"
  command rm "$file" 2>/dev/null   # ensure file is unlinked prior to use
  echo "$file"
}

_prompt ()
{
  typeset prompt="$1"
  typeset result
  case "$(_shell)" in
    bash)
      read -r -e -p "$prompt" result;;
    *)
      echo -n "$prompt" >&2; read -r result;;
  esac
  echo "$result"
}

_add_composure_file ()
{
  typeset func="$1"
  typeset file="$2"
  typeset operation="$3"
  typeset comment="${4:-}"
  typeset composure_dir=$(_get_composure_dir)

  (
    if ! cd "$composure_dir"; then
      printf "%s\n" "Oops! Can't find $composure_dir!"
      return
    fi
    if git rev-parse 2>/dev/null; then
      if [ ! -f "$file" ]; then
        printf "%s\n" "Oops! Couldn't find $file to version it for you..."
        return
      fi
      cp "$file" "$composure_dir/$func.inc"
      git add --all .
      if [ -z "$comment" ]; then
        comment="$(_prompt 'Git Comment: ')"
      fi
      git commit -m "$operation $func: $comment"
    fi
  )
}

_transcribe ()
{
  typeset func="$1"
  typeset file="$2"
  typeset operation="$3"
  typeset comment="${4:-}"
  typeset composure_dir=$(_get_composure_dir)

  if git --version >/dev/null 2>&1; then
    if [ -d "$composure_dir" ]; then
      _add_composure_file "$func" "$file" "$operation" "$comment"
    else
      if [ "${USE_COMPOSURE_REPO:-}" = "0" ]; then
        return  # if you say so...
      fi
      printf "%s\n" "I see you don't have a $composure_dir repo..."
      typeset input=''
      typeset valid=0
      while [ $valid != 1 ]; do
        printf "\n%s" 'would you like to create one? y/n: '
        read -r input
        case $input in
          y|yes|Y|Yes|YES)
            (
              echo 'creating git repository for your functions...'
              mkdir -p "$composure_dir" || return 1
              cd "$composure_dir" || return 1
              git init
              echo "composure stores your function definitions here" > README.txt
              git add README.txt
              git commit -m 'initial commit'
            )
            # if at first you don't succeed...
            _transcribe "$func" "$file" "$operation" "$comment"
            valid=1
            ;;
          n|no|N|No|NO)
            printf "%s\n" "ok. add 'export USE_COMPOSURE_REPO=0' to your startup script to disable this message."
            valid=1
          ;;
          *)
            printf "%s\n" "sorry, didn't get that..."
          ;;
        esac
      done
     fi
  fi
}

_typeset_functions ()
{
  # unfortunately, there does not seem to be a easy, portable way to list just the
  # names of the defined shell functions...

  case "$(_shell)" in
    sh|bash)
      typeset -F | awk '{print $3}'
      ;;
    *)
      # trim everything following '()' in ksh/zsh
      typeset +f | sed 's/().*$//'
      ;;
  esac
}

_typeset_functions_about ()
{
  typeset f
  for f in $(_typeset_functions); do
    typeset -f -- "$f" | grep -qE "^about[[:space:]]|[[:space:]]about[[:space:]]" && echo -- "$f"
  done
}

_shell () {
  # here's a hack I modified from a StackOverflow post:
  # get the ps listing for the current process ($$), and print the last column (CMD)
  # stripping any leading hyphens shells sometimes throw in there
  typeset this=$(ps -o comm -p $$ | tail -1 | awk '{print $NF}' | sed 's/^-*//')
  echo "${this##*/}"  # e.g. /bin/bash => bash
}

_generate_metadata_functions() {
  typeset f
  for f in $(_composure_keywords)
  do
    eval "$f() { :; }"
  done
}

_list_composure_files () {
  typeset composure_dir="$(_get_composure_dir)"
  [ -d "$composure_dir" ] && find "$composure_dir" -maxdepth 1 -name '*.inc'
}

_load_composed_functions () {
  # load previously composed functions into shell
  # you may disable this by adding the following line to your shell startup:
  # export LOAD_COMPOSED_FUNCTIONS=0

  if [ "${LOAD_COMPOSED_FUNCTIONS:-}" = "0" ]; then
    return  # if you say so...
  fi

  typeset inc
  for inc in $(_list_composure_files); do
    # shellcheck source=/dev/null
    . "$inc"
  done
}

_strip_trailing_whitespace () {
  sed -e 's/ \+$//'
}

_strip_semicolons () {
  sed -e 's/;$//'
}

# 'porcelain' functions

cite ()
{
  about 'creates one or more meta keywords for use in your functions'
  param 'one or more keywords'
  example '$ cite url username'
  example '$ url http://somewhere.com'
  example '$ username alice'
  group 'composure'

  # this is the storage half of the 'metadata' system:
  # we create dynamic metadata keywords with function wrappers around
  # the NOP command, ':'

  # anything following a keyword will get parsed as a positional
  # parameter, but stay resident in the ENV. As opposed to shell
  # comments, '#', which do not get parsed and are not available
  # at runtime.

  # a BIG caveat--your metadata must be roughly parsable: do not use
  # contractions, and consider single or double quoting if it contains
  # non-alphanumeric characters

  if [ -z "$1" ]; then
    printf '%s\n' 'missing parameter(s)'
    reference cite
    return
  fi

  typeset keyword
  for keyword in "$@"; do
    eval "$keyword() { :; }"
  done
}

draft ()
{
  about 'wraps command from history into a new function, default is last command'
  param '1: name to give function'
  param '2: optional history line number'
  example '$ ls'
  example '$ draft list'
  example '$ draft newfunc 1120  # wraps command at history line 1120 in newfunc()'
  group 'composure'

  typeset func=$1
  typeset num=$2

  if [ -z "$func" ]; then
    printf '%s\n' 'missing parameter(s)'
    reference draft
    return
  fi

  # aliases bind tighter than function names, disallow them
  if type -a "$func" 2>/dev/null | grep -q 'is.*alias'; then
    printf '%s\n' "sorry, $(type -a "$func"). please choose another name."
    return
  fi

  typeset cmd
  if [ -z "$num" ]; then
    # some versions of 'fix command, fc' need corrective lenses...
    typeset lines=$(fc -ln -1 | grep -q draft && echo 2 || echo 1)
    # parse last command from fc output
    # shellcheck disable=SC2086
    cmd=$(fc -ln -$lines | head -1 | sed 's/^[[:blank:]]*//')
  else
    # parse command from history line number
    cmd=$(eval "history | grep '^[[:blank:]]*$num' | head -1" | sed 's/^[[:blank:][:digit:]]*//')
  fi
  eval "function $func {
  author '$(_get_author_name)'
  about ''
  param ''
  example ''
  group ''

  $cmd;
}"
  typeset file=$(_temp_filename_for draft)
  typeset -f "$func" | _strip_trailing_whitespace | _strip_semicolons > "$file"
  _transcribe "$func" "$file" Draft "Initial draft"
  command rm "$file" 2>/dev/null
  revise "$func"
}

glossary ()
{
  about 'displays help summary for all functions, or summary for a group of functions'
  param '1: optional, group name'
  example '$ glossary'
  example '$ glossary misc'
  group 'composure'

  typeset targetgroup=${1:-}
  typeset functionlist="$(_typeset_functions_about)"
  typeset maxwidth=$(_longest_function_name_length "$functionlist" | awk '{print $1 + 5}')

  for func in $(echo $functionlist); do

    if [ "X${targetgroup}X" != "XX" ]; then
      typeset group="$(typeset -f -- $func | metafor group)"
      if [ "$group" != "$targetgroup" ]; then
        continue  # skip non-matching groups, if specified
      fi
    fi
    typeset about="$(typeset -f -- $func | metafor about)"
    typeset aboutline=
    echo "$about" | fmt | while read -r aboutline; do
      _letterpress "$aboutline" "$func" "$maxwidth"
      func=" " # only display function name once
    done
  done
}

metafor ()
{
  about 'prints function metadata associated with keyword'
  param '1: meta keyword'
  example '$ typeset -f glossary | metafor example'
  group 'composure'

  typeset keyword=$1

  if [ -z "$keyword" ]; then
    printf '%s\n' 'missing parameter(s)'
    reference metafor
    return
  fi

  # this sed-fu is the retrieval half of the 'metadata' system:
  # 'grep' for the metadata keyword, and then parse/filter the matching line

  # grep keyword # strip trailing '|"|; # ignore thru keyword and leading '|"
  sed -n "/$keyword / s/['\";]*\$//;s/^[ 	]*\(: _\)*$keyword ['\"]*\([^([].*\)*\$/\2/p"
}

reference ()
{
  about 'displays apidoc help for a specific function'
  param '1: function name'
  example '$ reference revise'
  group 'composure'

  typeset func=$1
  if [ -z "$func" ]; then
    printf '%s\n' 'missing parameter(s)'
    reference reference
    return
  fi

  typeset line

  typeset about="$(typeset -f "$func" | metafor about)"
  _letterpress "$about" "$func"

  typeset author="$(typeset -f $func | metafor author)"
  if [ -n "$author" ]; then
    _letterpress "$author" 'author:'
  fi

  typeset version="$(typeset -f $func | metafor version)"
  if [ -n "$version" ]; then
    _letterpress "$version" 'version:'
  fi

  if [ -n "$(typeset -f $func | metafor param)" ]; then
    printf "parameters:\n"
    typeset -f $func | metafor param | while read -r line
    do
      _letterpress "$line"
    done
  fi

  if [ -n "$(typeset -f $func | metafor example)" ]; then
    printf "examples:\n"
    typeset -f $func | metafor example | while read -r line
    do
      _letterpress "$line"
    done
  fi
}

revise ()
{
  about 'loads function into editor for revision'
  param '<optional> -e: revise version stored in ENV'
  param '1: name of function'
  example '$ revise myfunction'
  example '$ revise -e myfunction'
  example 'save a zero-length file to abort revision'
  group 'composure'

  typeset source='git'
  if [ "$1" = '-e' ]; then
    source='env'
    shift
  fi

  typeset func=$1
  if [ -z "$func" ]; then
    printf '%s\n' 'missing parameter(s)'
    reference revise
    return
  fi

  typeset composure_dir=$(_get_composure_dir)
  typeset temp=$(_temp_filename_for revise)
  # populate tempfile...
  if [ "$source" = 'env' ] || [ ! -f "$composure_dir/$func.inc" ]; then
    # ...with ENV if specified or not previously versioned
    typeset -f $func > $temp
  else
    # ...or with contents of latest git revision
    cat "$composure_dir/$func.inc" > "$temp"
  fi

  if [ -z "${EDITOR:-}" ]
  then
    typeset EDITOR=vi
  fi

  $EDITOR "$temp"
  if [ -s "$temp" ]; then
    typeset edit='N'

    # source edited file
    # shellcheck source=/dev/null
    . "$temp" || edit='Y'

    while [ $edit = 'Y' ]; do
      echo -n "Re-edit? Y/N: "
      read -r edit
      case $edit in
         y|yes|Y|Yes|YES)
           edit='Y'
           $EDITOR "$temp"
           # shellcheck source=/dev/null
           . "$temp" && edit='N';;
         *)
           edit='N';;
      esac
    done
    _transcribe "$func" "$temp" Revise
  else
    # zero-length files abort revision
    printf '%s\n' 'zero-length file, revision aborted!'
  fi
  command rm "$temp"
}

write ()
{
about 'writes one or more composed function definitions to stdout'
param 'one or more function names'
example '$ write finddown foo'
example '$ write finddown'
group 'composure'

if [ -z "$1" ]; then
  printf '%s\n' 'missing parameter(s)'
  reference write
  return
fi

echo "#!/usr/bin/env ${SHELL##*/}"

# bootstrap metadata
cat <<END
for f in $(_composure_keywords)
do
  eval "\$f() { :; }"
done
unset f
END

# write out function definitons
# shellcheck disable=SC2034
typeset -f cite "$@"

cat <<END
main() {
  echo "edit me to do something useful!"
  exit 0
}

main \$*
END
}

_bootstrap_composure

### end of composure ###

### start of colors.bash ###

black="\[\e[0;30m\]"
red="\[\e[0;31m\]"
green="\[\e[0;32m\]"
yellow="\[\e[0;33m\]"
blue="\[\e[0;34m\]"
purple="\[\e[0;35m\]"
cyan="\[\e[0;36m\]"
white="\[\e[0;37m\]"
orange="\[\e[0;91m\]"

bold_black="\[\e[30;1m\]"
bold_red="\[\e[31;1m\]"
bold_green="\[\e[32;1m\]"
bold_yellow="\[\e[33;1m\]"
bold_blue="\[\e[34;1m\]"
bold_purple="\[\e[35;1m\]"
bold_cyan="\[\e[36;1m\]"
bold_white="\[\e[37;1m\]"
bold_orange="\[\e[91;1m\]"

underline_black="\[\e[30;4m\]"
underline_red="\[\e[31;4m\]"
underline_green="\[\e[32;4m\]"
underline_yellow="\[\e[33;4m\]"
underline_blue="\[\e[34;4m\]"
underline_purple="\[\e[35;4m\]"
underline_cyan="\[\e[36;4m\]"
underline_white="\[\e[37;4m\]"
underline_orange="\[\e[91;4m\]"

background_black="\[\e[40m\]"
background_red="\[\e[41m\]"
background_green="\[\e[42m\]"
background_yellow="\[\e[43m\]"
background_blue="\[\e[44m\]"
background_purple="\[\e[45m\]"
background_cyan="\[\e[46m\]"
background_white="\[\e[47;1m\]"
background_orange="\[\e[101m\]"

normal="\[\e[0m\]"
reset_color="\[\e[39m\]"

# These colors are meant to be used with `echo -e`
echo_black="\033[0;30m"
echo_red="\033[0;31m"
echo_green="\033[0;32m"
echo_yellow="\033[0;33m"
echo_blue="\033[0;34m"
echo_purple="\033[0;35m"
echo_cyan="\033[0;36m"
echo_white="\033[0;37;1m"
echo_orange="\033[0;91m"

echo_bold_black="\033[30;1m"
echo_bold_red="\033[31;1m"
echo_bold_green="\033[32;1m"
echo_bold_yellow="\033[33;1m"
echo_bold_blue="\033[34;1m"
echo_bold_purple="\033[35;1m"
echo_bold_cyan="\033[36;1m"
echo_bold_white="\033[37;1m"
echo_bold_orange="\033[91;1m"

echo_underline_black="\033[30;4m"
echo_underline_red="\033[31;4m"
echo_underline_green="\033[32;4m"
echo_underline_yellow="\033[33;4m"
echo_underline_blue="\033[34;4m"
echo_underline_purple="\033[35;4m"
echo_underline_cyan="\033[36;4m"
echo_underline_white="\033[37;4m"
echo_underline_orange="\033[91;4m"

echo_background_black="\033[40m"
echo_background_red="\033[41m"
echo_background_green="\033[42m"
echo_background_yellow="\033[43m"
echo_background_blue="\033[44m"
echo_background_purple="\033[45m"
echo_background_cyan="\033[46m"
echo_background_white="\033[47;1m"
echo_background_orange="\033[101m"

echo_normal="\033[0m"
echo_reset_color="\033[39m"

### end of colors.bash

# support 'plumbing' metadata
cite _about _param _example _group _author _version _deps _runtype
cite about-alias about-plugin about-completion

# Declare our end-of-main finishing hook, but don't use `declare`/`typeset`
_jangbi_it_library_finalize_hook=()

### start of slib.sh loading ###

# shellcheck disable=SC3043 disable=SC2086 disable=SC2059 disable=SC2039 disable=SC2034 disable=SC2317
#------------------------------------------------------------------------------
# Utility function library for installation scripts
# slib v1.2.0 (https://github.com/virtualmin/slib)
# Copyright 2017-2025 Joe Cooper
# slog logging library Copyright Fred Palmer and Joe Cooper
# Licensed under the BSD 3 clause license
#------------------------------------------------------------------------------

restore_cursor () {
  tput cnorm
}

cleanup () {
  exit_code=$1
  stty echo 1>/dev/null 2>&1
  echo
  # Make super duper sure we reap all the spinners
  # This is ridiculous, and I still don't know why spinners stick around.
  if [ -n "$allpids" ]; then
    for pid in $allpids; do
      kill "$pid" 1>/dev/null 2>&1
    done
    tput sgr0
  fi
  restore_cursor
  # Clean any env dirs
  env | grep '_INSTALL_TEMPDIR=' | while IFS='=' read -r var temp_dir; do
    [ -z "$temp_dir" ] && continue
    prefix="${var%%_INSTALL_TEMPDIR}"
    if [ -d "$temp_dir" ] && echo "$temp_dir" | grep -iq "${prefix}-"; then
      rm -rf "$temp_dir"
    fi
  done

  if [ "$exit_code" -ne 0 ]; then
    echo
  fi

  exit $exit_code
}

# Check for interactive shell
INTERACTIVE_MODE="on"
[ -z "${NONINTERACTIVE-}" ] && NONINTERACTIVE=0      # Set only if unset
if [ ! -t 0 ] && [ -z "${PS1-}" ]; then
    INTERACTIVE_MODE="off"
    [ -z "${NONINTERACTIVE-}" ] && NONINTERACTIVE=1  # Only set if unset
fi

# This tries to catch any exit, whether normal or forced (e.g. Ctrl-C)
if [ "$INTERACTIVE_MODE" != "off" ]; then
  trap 'cleanup 2' INT
  trap 'cleanup 3' QUIT
  trap 'cleanup 15' TERM
  trap 'cleanup 0' EXIT
fi

# scolors - Color constants
# canonical source http://github.com/swelljoe/scolors

# do we have tput?
if command -pv 'tput' > /dev/null; then
  # do we have a terminal?
  if [ -t 1 ]; then
    # does the terminal have colors?
    ncolors=$(tput colors)
    if [ "$ncolors" -ge 8 ]; then
      BLACK="$(tput setaf 0)"
      RED=$(tput setaf 1)
      GREEN=$(tput setaf 2)
      YELLOW=$(tput setaf 3)
      ORANGE=$(tput setaf 3)
      BLUE=$(tput setaf 4)
      MAGENTA=$(tput setaf 5)
      CYAN=$(tput setaf 6)
      WHITE=$(tput setaf 7)
      REDBG=$(tput setab 1)
      GREENBG=$(tput setab 2)
      YELLOWBG=$(tput setab 3)
      ORANGEBG=$(tput setab 3)
      BLUEBG=$(tput setab 4)
      MAGENTABG=$(tput setab 5)
      CYANBG=$(tput setab 6)
      WHITEBG=$(tput setab 7)

      # Do we have support for bright colors?
      if [ "$ncolors" -ge 16 ]; then
        WHITE=$(tput setaf 15)
        WHITEBG=$(tput setab 15)
      fi

      # Do we have support for 256 colors to make it more readable?
      if [ "$ncolors" -ge 256 ]; then
        RED=$(tput setaf 124)
        GREEN=$(tput setaf 34)
        YELLOW=$(tput setaf 186)
        BLUE=$(tput setaf 25)
        ORANGE=$(tput setaf 202)
        MAGENTA=$(tput setaf 90)
        CYAN=$(tput setaf 45)
        WHITE=$(tput setaf 255)
        REDBG=$(tput setab 160)
        YELLOWBG=$(tput setab 186)
        ORANGEBG=$(tput setab 166)
        BLUEBG=$(tput setab 25)
        MAGENTABG=$(tput setab 90)
        CYANBG=$(tput setab 45)
      fi

      BOLD=$(tput bold)
      UNDERLINE=$(tput smul) # Many terminals don't support this
      NORMAL=$(tput sgr0)
    fi
  fi
else
  echo "tput not found, colorized output disabled."
  BLACK=''
  RED=''
  GREEN=''
  YELLOW=''
  ORANGE=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  WHITE=''
  REDBG=''
  GREENBG=''
  YELLOWBG=''
  ORANGEBG=''
  BLUEBG=''
  MAGENTABG=''
  CYANBG=''

  BOLD=''
  UNDERLINE=''
  NORMAL=''
fi

# slog - logging library
# canonical source http://github.com/swelljoe/slog

# LOG_PATH - Define $LOG_PATH in your script to log to a file, otherwise
# just writes to STDOUT.

# LOG_LEVEL_STDOUT - Define to determine above which level goes to STDOUT.
# By default, all log levels will be written to STDOUT.
LOG_LEVEL_STDOUT="INFO"

# LOG_LEVEL_LOG - Define to determine which level goes to LOG_PATH.
# By default all log levels will be written to LOG_PATH.
LOG_LEVEL_LOG="INFO"

# Useful global variables that users may wish to reference
SCRIPT_ARGS="$*"
SCRIPT_NAME="$0"
SCRIPT_NAME="${SCRIPT_NAME#\./}"
SCRIPT_NAME="${SCRIPT_NAME##/*/}"

#--------------------------------------------------------------------------------------------------
# Begin Logging Section
if [ "$INTERACTIVE_MODE" = "off" ]
then
    # Then we don't care about log colors
    LOG_DEFAULT_COLOR=""
    LOG_ERROR_COLOR=""
    LOG_INFO_COLOR=""
    LOG_SUCCESS_COLOR=""
    LOG_WARN_COLOR=""
    LOG_DEBUG_COLOR=""
else
    LOG_DEFAULT_COLOR=$(tput sgr0)
    LOG_ERROR_COLOR=$(tput setaf 1)
    LOG_INFO_COLOR=$(tput setaf 6)
    LOG_SUCCESS_COLOR=$(tput setaf 2)
    LOG_WARN_COLOR=$(tput setaf 3)
    LOG_DEBUG_COLOR=$(tput setaf 4)
fi

# This function scrubs the output of any control characters used in colorized output
# It's designed to be piped through with text that needs scrubbing.  The scrubbed
# text will come out the other side!
prepare_log_for_nonterminal () {
    # Essentially this strips all the control characters for log colors
    sed -E 's/\x1B\[[0-9;]*[mK]//g; s/\x1B\([A-Za-z]//g' | tr -d '[:cntrl:]'
}

log_date () {
  local log_date_level="$1"
  echo "[$(date +"%Y-%m-%d %H:%M:%S %Z")] [$log_date_level] "
}

log () {
  local log_text="$1"
  local log_level="$2"
  local log_color="$3"

  # Levels for comparing against LOG_LEVEL_STDOUT and LOG_LEVEL_LOG
  local LOG_LEVEL_DEBUG=0
  local LOG_LEVEL_INFO=1
  local LOG_LEVEL_SUCCESS=2
  local LOG_LEVEL_WARNING=3
  local LOG_LEVEL_ERROR=4

  # Default level to "info"
  [ -z "${log_level}" ] && log_level="INFO";
  [ -z "${log_color}" ] && log_color="${LOG_INFO_COLOR}";

  # Validate LOG_LEVEL_STDOUT and LOG_LEVEL_LOG since they'll be eval-ed.
  case $LOG_LEVEL_STDOUT in
    DEBUG|INFO|SUCCESS|WARNING|ERROR)
      ;;
    *)
      LOG_LEVEL_STDOUT=INFO
      ;;
  esac
  case $LOG_LEVEL_LOG in
    DEBUG|INFO|SUCCESS|WARNING|ERROR)
      ;;
    *)
      LOG_LEVEL_LOG=INFO
      ;;
  esac

  # Check LOG_LEVEL_STDOUT to see if this level of entry goes to STDOUT.
  # XXX This is the horror that happens when your language doesn't have a hash data struct.
  eval log_level_int="\$LOG_LEVEL_${log_level}";
  eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}"
  # shellcheck disable=SC2154
  if [[ "$log_level_stdout" -le "$log_level_int" ]]; then
    # STDOUT
    printf "%s[%s]%s %s\\n" "$log_color" "$log_level" "$LOG_DEFAULT_COLOR" "$log_text";
  fi
  # This is all very tricky; figures out a numeric value to compare.
  eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"
  # Check LOG_LEVEL_LOG to see if this level of entry goes to LOG_PATH
  # shellcheck disable=SC2154
  if [[ "$log_level_log" -le "$log_level_int" ]]; then
    # LOG_PATH minus fancypants colors
    if [ -n "$LOG_PATH" ]; then
      today=$(date +"%Y-%m-%d %H:%M:%S %Z")
      printf "[%s] [%s] %s\\n" "$today" "$log_level" "$log_text" >> "$LOG_PATH"
    fi
  fi

  return 0;
}

log_info()      { log "$@"; }
log_success()   { log "$1" "SUCCESS" "${LOG_SUCCESS_COLOR}"; }
log_error()     { log "$1" "ERROR" "${LOG_ERROR_COLOR}"; }
log_warning()   { log "$1" "WARNING" "${LOG_WARN_COLOR}"; }
log_debug()     { log "$1" "DEBUG" "${LOG_DEBUG_COLOR}"; }
log_fatal()     { printf "$1";  }
# End Logging Section
#--------------------------------------------------------------------------------------------------

# spinner - Log to provide spinners when long-running tasks happen
# Canonical source http://github.com/swelljoe/spinner

# Config variables, set these after sourcing to change behavior.
SPINNER_COLORNUM=2 # What color? Irrelevent if COLORCYCLE=1.
SPINNER_COLORCYCLE=1 # Does the color cycle?
SPINNER_DONEFILE="stopspinning" # Path/name of file to exit on.
SPINNER_SYMBOLS="WIDE_ASCII_PROG" # Name of the variable containing the symbols.
SPINNER_CLEAR=1 # Blank the line when done.

spinner () {
  # Add this trap to make sure the spinner is terminated and the cursor
  # is restored, when the script is either finished or killed.
  trap 'restore_cursor; exit' INT QUIT TERM EXIT
  # Safest option are one of these. Doesn't need Unicode, at all.
  local WIDE_ASCII_PROG="[>-] [->] [--] [--]"
  local WIDE_UNI_GREYSCALE2="▒▒▒ █▒▒ ██▒ ███ ▒██ ▒▒█ ▒▒▒"

  local SPINNER_NORMAL
  SPINNER_NORMAL=$(tput sgr0)

  eval SYMBOLS=\$${SPINNER_SYMBOLS}

  # Get the parent PID
  SPINNER_PPID=$(ps -p "$$" -o ppid=)
  while :; do
    tput civis
    for c in ${SYMBOLS}; do
      if [ $SPINNER_COLORCYCLE -eq 1 ]; then
        if [ $SPINNER_COLORNUM -eq 7 ]; then
          SPINNER_COLORNUM=1
        else
          SPINNER_COLORNUM=$((SPINNER_COLORNUM+1))
        fi
      fi
      local SPINNER_COLOR
      SPINNER_COLOR=$(tput setaf ${SPINNER_COLORNUM})
      tput sc
      env printf "${SPINNER_COLOR}${c}${SPINNER_NORMAL}"
      tput rc
      if [ -f "${SPINNER_DONEFILE}" ]; then
        if [ ${SPINNER_CLEAR} -eq 1 ]; then
          tput el
        fi
	      rm -f ${SPINNER_DONEFILE} "=1000" "=500" 2>/dev/null
	      break 2
      fi
      # This is questionable. sleep with fractional seconds is not
      # always available, but seems to not break things, when not.
      env sleep .2
      # Check to be sure parent is still going; handles sighup/kill
      if [ -n "$SPINNER_PPID" ]; then
        # This is ridiculous. ps prepends a space in the ppid call, which breaks
        # this ps with a "garbage option" error.
        # XXX Potential gotcha if ps produces weird output.
        # shellcheck disable=SC2086
        SPINNER_PARENTUP=$(ps --no-headers $SPINNER_PPID)
        if [ -z "$SPINNER_PARENTUP" ]; then
          break 2
        fi
      fi
    done
  done
  tput rc
  restore_cursor
  return 0
}

# run_ok - function to run a command or function, start a spinner and print a confirmation
# indicator when done.
# Canonical source - http://github.com/swelljoe/run_ok
RUN_LOG="run.log"

# Check for unicode support in the shell
# This is a weird function, but seems to work. Checks to see if a unicode char can be
# written to a file and can be read back.
shell_has_unicode () {
  # Write a unicode character to a file...read it back and see if it's handled right.
  env printf "\\u2714"> unitest.txt

  read -r unitest < unitest.txt
  rm -f unitest.txt
  if [ ${#unitest} -le 3 ]; then
    return 0
  else
    return 1
  fi
}

# Setup spinner with our prefs.
SPINNER_COLORCYCLE=0
SPINNER_COLORNUM=6
if shell_has_unicode; then
  SPINNER_SYMBOLS="WIDE_UNI_GREYSCALE2"
else
  SPINNER_SYMBOLS="WIDE_ASCII_PROG"
fi
SPINNER_CLEAR=0 # Don't blank the line, so our check/x can simply overwrite it.

# Perform an action, log it, and print a colorful checkmark or X if failed
# Returns 0 if successful, $? if failed.
run_ok () {
  # Shell is really clumsy with passing strings around.
  # This passes the unexpanded $1 and $2, so subsequent users get the
  # whole thing.
  local cmd="${1}"
  local msg="${2}"
  local log_pref
  log_pref="$(log_date "INFO")"
  local columns
  if [ "$INTERACTIVE_MODE" != "off" ];then
    columns=$(tput cols)
    if [ "$columns" -ge 80 ]; then
      columns=79
    fi
  else
      columns=79
  fi
  # shellcheck disable=SC2004
  COL=$((${columns}-${#msg}-3 ))

  printf "%s%${COL}s" "$2"
  # Make sure there some unicode action in the shell; there's no
  # way to check the terminal in a POSIX-compliant way, but terms
  # are mostly ahead of shells.
  # Unicode checkmark and x mark for run_ok function
  CHECK='\u2714'
  BALLOT_X='\u2718'
  if [ "$INTERACTIVE_MODE" != "off" ];then
    stty -echo 1>/dev/null 2>&1
    spinner &
    spinpid=$!
    allpids="$allpids $spinpid"
    echo "$log_pref Spin pid is: $spinpid" >> ${RUN_LOG}
  fi
  eval "${cmd}" 1>> ${RUN_LOG} 2>&1
  local res=$?
  touch ${SPINNER_DONEFILE}
  env sleep .4 # It's possible to have a race for stdout and spinner clobbering the next bit
  # Just in case the spinner survived somehow, kill it.
  if [ "$INTERACTIVE_MODE" != "off" ];then
    stty echo 1>/dev/null 2>&1
    pidcheck=$(ps --no-headers ${spinpid})
    if [ -n "$pidcheck" ]; then
      echo "$log_pref Made it here...why?" >> ${RUN_LOG}
      kill $spinpid 2>/dev/null
      rm -rf ${SPINNER_DONEFILE} 1>/dev/null 2>&1
      tput rc
      restore_cursor
    fi
  fi
  # Log what we were supposed to be running
  msg_safe=$(echo "$msg" | prepare_log_for_nonterminal)
  printf "$log_pref ${msg_safe}: " >> ${RUN_LOG}
  if shell_has_unicode; then
    if [ $res -eq 0 ]; then
      printf "$log_pref Success.\\n" >> ${RUN_LOG}
      env printf "${GREENBG}${WHITE} ${CHECK} ${NORMAL}\\n"
      return 0
    else
      printf "$log_pref Failed with error: ${res}\\n" >> ${RUN_LOG}
      env printf "${REDBG}${WHITE} ${BALLOT_X} ${NORMAL}\\n"
      if [ "$RUN_ERRORS_FATAL" ]; then
        echo
        log_fatal "Something went wrong. Exiting."
        log_fatal "The last few log entries were:"
        tail -17 "${RUN_LOG}" | head -15
        return 1
      fi
      return ${res}
    fi
  else
    if [ $res -eq 0 ]; then
      printf "$log_pref Success.\\n" >> ${RUN_LOG}
      env printf "${GREENBG} OK ${NORMAL}\\n"
      return 0
    else
      printf "$log_pref Failed with error: ${res}\\n" >> ${RUN_LOG}
      env printf "${REDBG} ER ${NORMAL}\\n"
      if [ "$RUN_ERRORS_FATAL" ]; then
        log_fatal "Something went wrong with the previous command. Exiting.\n"
        return 1
      fi
      return ${res}
    fi
  fi
}

# Ask a yes or no question
# if $skipyesno is 1, always Y
# if NONINTERACTIVE environment variable is 1, always N, and print error message to use --force
yesno () {
  # XXX skipyesno is a global set in the calling script
  # shellcheck disable=SC2154
  if [ "$skipyesno" = "1" ]; then
    return 0
  fi
  if [ "$NONINTERACTIVE" = "1" ]; then
    echo "Non-interactive shell detected. Cannot continue, as the script may need to ask questions."
    echo "If you're running this from a script and want to install with default options, use '--force'."
    return 1
  fi
  stty echo 1>/dev/null 2>&1
  while read -r line; do
    stty -echo 1>/dev/null 2>&1
    case $line in
      y|Y|Yes|YES|yes|yES|yEs|YeS|yeS) return 0
      ;;
      n|N|No|NO|no|nO) return 1
      ;;
      *)
      stty echo 1>/dev/null 2>&1
      printf "\\n${YELLOW}Please enter ${CYAN}[y]${YELLOW} or ${CYAN}[n]${YELLOW}:${NORMAL} "
      ;;
    esac
  done
  stty -echo 1>/dev/null 2>&1
}

# mkdir if it doesn't exist
testmkdir () {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

# Copy a file if the destination doesn't exist
testcp () {
  if [ ! -e "$2" ]; then
    cp "$1" "$2"
  fi
}

# Detect the primary IP address
# works across most Linux and FreeBSD (maybe)
detect_ip () {
  # Interface detection
  defaultdev=$(ip ro ls 2>>"${RUN_LOG}" | grep default | head -1 | sed -e 's/.*\sdev\s//g' | awk '{print $1}')
  # IPv6 only?
  if [ -z "$defaultdev" ]; then
    defaultdev=$(ip -6 ro ls 2>>"${RUN_LOG}" | grep default | head -1 | sed -e 's/.*\sdev\s//g' | awk '{print $1}')
  fi
  # No default route at all: isolated or internal-only system?
  if [ -z "$defaultdev" ]; then
    log_warning "No default route detected. Cannot determine primary interface."
    log_warning "Extracting the name of the first active network interface that is not the loopback!"
    defaultdev=$(ip -o link show 2>>"${RUN_LOG}" | awk -F': ' '/state UP/ && !/LOOPBACK/ {print $2}' | head -1)
  fi
  # IPv4
  primaryaddr=$(ip -f inet addr show dev "$defaultdev" 2>>"${RUN_LOG}" | grep 'inet ' | awk '{print $2}' | head -1 | cut -d"/" -f1 | cut -f1)
  # IPv6 only?
  if [ -z "$primaryaddr" ]; then
      primaryaddr=$(ip -f inet6 addr show dev "$defaultdev" 2>>"${RUN_LOG}" | grep 'inet6 ' | awk '{print $2}' | head -1 | cut -d"/" -f1 | cut -f1)
  fi
  if [ "$primaryaddr" ]; then
    log_debug "Primary address detected as $primaryaddr"
    address=$primaryaddr
    return 0
  else
    log_warning "Unable to determine IP address of primary interface."
    echo "Please enter the name of your primary network interface: "
    stty echo 1>/dev/null 2>&1
    read -r primaryinterface
    stty -echo 1>/dev/null 2>&1
    # IPv4
    primaryaddr=$(/sbin/ip -f inet -o -d addr show dev "$primaryinterface" 2>>"${RUN_LOG}" | head -1 | awk '{print $4}' | head -1 | cut -d"/" -f1)
    # IPv6 only?
    if [ -z "$primaryaddr" ]; then
      primaryaddr=$(/sbin/ip -f inet6 -o -d addr show dev "$primaryinterface" 2>>"${RUN_LOG}" | head -1 | awk '{print $4}' | head -1 | cut -d"/" -f1)
    fi
    if [ "$primaryaddr" = "" ]; then
      # FreeBSD (IPv4)
      primaryaddr=$(/sbin/ifconfig "$primaryinterface" 2>>"${RUN_LOG}" | grep 'inet' | awk '{ print $2 }')
      # FreeBSD IPv6 only?
      if [ -z "$primaryaddr" ]; then
        primaryaddr=$(/sbin/ifconfig "$primaryinterface" 2>>"${RUN_LOG}" | grep 'inet6' | awk '{ print $2 }')
      fi
    fi
    if [ "$primaryaddr" ]; then
      log_debug "Primary address detected as $primaryaddr"
      address=$primaryaddr
    else
      fatal "Unable to determine IP address of selected interface.  Cannot continue."
    fi
    return 0
  fi
}

# Set the hostname
set_hostname () {
  local i=0
  local forcehostname
  if [ -n "$1" ]; then
    forcehostname=$1
  fi
  while [ $i -le 3 ]; do
    if [ -z "$forcehostname" ]; then
      local name
      name=$(hostname -f)
      log_error "Your system hostname $name is not fully qualified."
      printf "Please enter a fully qualified hostname (e.g.: host.example.com): "
      stty echo 1>/dev/null 2>&1
      read -r line
      stty -echo 1>/dev/null 2>&1
    else
      log_debug "Setting hostname to $forcehostname"
      line=$forcehostname
    fi
    if ! is_fully_qualified "$line"; then
      i=$((i + 1))
      log_warning "Hostname $line is not fully qualified."
      if [ "$i" = "4" ]; then
        fatal "Unable to set fully qualified hostname."
      fi
    else
      hostname "$line"
      echo "$line" > /etc/hostname
      hostnamectl set-hostname "$line" 1>/dev/null 2>&1
      detect_ip
      shortname=$(echo "$line" | cut -d"." -f1)
      if grep "^$address" /etc/hosts >/dev/null; then
        log_debug "Entry for IP $address exists in /etc/hosts."
        log_debug "Updating with new hostname."
        sed -i "s/^$address.*/$address $line $shortname/" /etc/hosts
      else
        log_debug "Adding new entry for hostname $line on $address to /etc/hosts."
        printf "%s\\t%s\\t%s\\n" "$address" "$line" "$shortname" >> /etc/hosts
      fi
      i=4
    fi
  done
}

is_fully_qualified () {
  case $1 in
    localhost.localdomain)
      log_warning "Hostname cannot be localhost.localdomain."
      return 1
      ;;
    *.localdomain)
      log_warning "Hostname cannot be *.localdomain."
      return 1
      ;;
    *.internal)
      log_warning "Hostname cannot be *.internal."
      return 1
      ;;
    *.*)
      log_debug "Hostname is fully qualified as $1"
      return 0
      ;;
  esac
  return 1
}

# sets up distro version globals os_type, os_version, os_major_version, os_real
# returns 1 if something fails.
get_distro () {
  os=$(uname -o)
  # Make sure we're Linux
  if echo "$os" | grep -iq linux; then
    if [ -f /etc/cloudlinux-release ]; then # Oracle
      local os_string
      os_string=$(cat /etc/cloudlinux-release)
      os_real='CloudLinux'
      os_pretty=$os_string
      os_type='cloudlinux'
      os_version=$(echo "$os_string" | grep -o '[0-9\.]*')
      os_major_version=$(echo "$os_version" | cut -d '.' -f1)
    elif [ -f /etc/oracle-release ]; then # Oracle
      local os_string
      os_string=$(cat /etc/oracle-release)
      os_real='Oracle Linux'
      os_pretty=$os_string
      os_type='ol'
      os_version=$(echo "$os_string" | grep -o '[0-9\.]*')
      os_major_version=$(echo "$os_version" | cut -d '.' -f1)
    elif [ -f /etc/redhat-release ]; then # RHEL/CentOS/Alma/Rocky
      local os_string
      os_string=$(cat /etc/redhat-release)
      isrhel=$(echo "$os_string" | grep 'Red Hat')
      iscentosstream=$(echo "$os_string" | grep 'CentOS Stream')
      if [ -n "$isrhel" ]; then
        os_real='RHEL'
      elif [ -n "$iscentosstream" ]; then
        os_real='CentOS Stream'
      else
        os_real=$(echo "$os_string" | cut -d' ' -f1) # Doesn't work for Scientific
      fi
      os_pretty=$os_string
      os_type=$(echo "$os_real" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
      os_version=$(echo "$os_string" | grep -o '[0-9\.]*')
      os_major_version=$(echo "$os_version" | cut -d '.' -f1)
    elif [ -f /etc/os-release ]; then # Debian/Ubuntu
      # Source it, so we can check VERSION_ID
      # shellcheck disable=SC1091
      . /etc/os-release
      # Not technically correct, but os-release does not have 7.xxx for centos
      # shellcheck disable=SC2153
      os_real=$NAME
      os_pretty=$PRETTY_NAME
      os_type=$ID
      os_version=$VERSION_ID
      os_major_version=$(echo "${os_version}" | cut -d'.' -f1)
    else
      printf "${RED}No /etc/*-release file found, this OS is probably not supported.${NORMAL}\\n"
      return 1
    fi
  else
    printf "${RED}Failed to detect a supported operating system.${NORMAL}\\n"
    return 1
  fi
  if [ -n "$1" ]; then
    case $1 in
      real)
        echo "$os_real"
        ;;
      type)
        echo "$os_type"
        ;;
      version)
        echo "$os_version"
        ;;
      major)
        echo "$os_major_version"
        ;;
      *)
        printf "${RED}Unknown argument${NORMAL}\\n"
        return 1
        ;;
    esac
  fi
  return 0
}

# memory_ok - Function to check for enough memory. Will fix it, if not, by
# adding a swap file.
memory_ok () {
  min_mem=$1
  disk_space_required=$2
  # If swap hasn't been setup yet, try doing it
  is_swap=$(swapon -s|grep /swap.vm)
  if [ -n "$is_swap" ]; then
    if [ -z "$min_mem" ]; then
      min_mem=1048576
    fi
    # Check the available RAM and swap
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    all_mem=$((mem_total + swap_total))
    swap_min=$(( 1286144 - all_mem ))

    if [ "$swap_min" -lt '262144' ]; then
      swap_min=262144
    fi

    min_mem_h=$((min_mem / 1024))
    if [ "$all_mem" -gt "$min_mem" ]; then
      log_debug "Memory is greater than ${min_mem_h} MB, which should be sufficient."
      return 0
    else
      log_error "Memory is below ${min_mem_h} MB. A full installation may not be possible."
    fi

    # We'll need swap, so ask and turn some on.
    swap_min_h=$((swap_min / 1024))
    echo
    echo "  Your system has less than ${min_mem_h} MB of available memory and swap."
    echo "  Installation is likely to fail, especially on Debian/Ubuntu systems (apt-get"
    echo "  grows very large when installing large lists of packages). You could exit"
    echo "  and re-install with the --minimal flag to install a more compact selection"
    echo "  of packages, or we can try to create a swap file for you. To create a swap"
    echo "  file, you'll need ${swap_min_h} MB free disk space, in addition to $disk_space_required GB of free space"
    echo "  for packages installation."
    echo
    echo "  Would you like to continue? If you continue, you will be given the option to"
    printf "  create a swap file. (y/n) "
    if ! yesno; then
      return 1 # Should exit when this function returns 1
    fi
    echo
    echo "  Would you like for me to try to create a swap file? This will require"
    echo "   at least ${swap_min_h} MB of free space, in addition to $disk_space_required GB for the"

    printf "  installation. (y/n) "
    if ! yesno; then
      log_warning "Proceeding without creating a swap file. Installation may fail."
      return 0
    fi

    # Check for btrfs, because it can't host a swap file safely.
    root_fs_type=$(grep -v "^$\\|^\\s*#" /etc/fstab | awk '{print $2 " " $3}' | grep "/ " | cut -d' ' -f2)
    if [ "$root_fs_type" = "btrfs" ]; then
      log_fatal "Your root filesystem appears to be running btrfs. It is unsafe to create"
      log_fatal "a swap file on a btrfs filesystem. You'll either need to use the --minimal"
      log_fatal "installation or create a swap file manually (on some other filesystem)."
      return 2
    fi

    # Check for enough space.
    root_fs_avail=$(df /|grep -v Filesystem|awk '{print $4}')
    if [ "$root_fs_avail" -lt $((swap_min + 358400)) ]; then
      root_fs_avail_h=$((root_fs_avail / 1024))
      log_fatal "Root filesystem only has $root_fs_avail_h MB available, which is too small."
      log_fatal "You'll either need to use the --minimal installation of add more space to '/'."
      return 3
    fi

    # Create a new file
    if ! dd if=/dev/zero of=/swap.vm bs=1024 count=$swap_min 1>>${RUN_LOG} 2>&1; then
      log_fatal "Creating swap file /swap.vm failed."
      return 4
    fi
    chmod 0600 /swap.vm 1>>${RUN_LOG} 2>&1
    mkswap /swap.vm 1>>${RUN_LOG} 2>&1
    if ! swapon /swap.vm 1>>${RUN_LOG} 2>&1; then
      log_fatal "Enabling swap file failed. If this is a VM, it may be prohibited by your provider."
      return 5
    fi
    echo "/swap.vm          swap            swap    defaults        0 0" >> /etc/fstab
  fi
  return 0
}
### end of slib.sh loading ###

### start of jangbi-it(bash-it) loading ###

# Declare log severity levels, matching syslog numbering
: "${JANGBI_IT_LOG_LEVEL_FATAL:=1}"
: "${JANGBI_IT_LOG_LEVEL_ERROR:=3}"
: "${JANGBI_IT_LOG_LEVEL_WARNING:=4}"
: "${JANGBI_IT_LOG_LEVEL_ALL:=6}"
: "${JANGBI_IT_LOG_LEVEL_INFO:=6}"
: "${JANGBI_IT_LOG_LEVEL_TRACE:=7}"
readonly "${!JANGBI_IT_LOG_LEVEL_@}"

function _bash-it-log-prefix-by-path() {
	local component_path="${1?${FUNCNAME[0]}: path specification required}"
	local without_extension component_directory
	local component_filename component_type component_name

	# get the directory, if any
	component_directory="${component_path%/*}"
	# drop the directory, if any
	component_filename="${component_path##*/}"
	# strip the file extension
	without_extension="${component_filename%.bash}"
	# strip before the last dot
	component_type="${without_extension##*.}"
	# strip component type, but try not to strip other words
	# - aliases, completions, plugins, themes
	component_name="${without_extension%.[acpt][hlo][eimu]*[ens]}"
	# Finally, strip load priority prefix
	component_name="${component_name##[[:digit:]][[:digit:]][[:digit:]]"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR:----}"}"

	# best-guess for files without a type
	if [[ "${component_type:-${component_name}}" == "${component_name}" ]]; then
		if [[ "${component_directory}" == *'vendor'* ]]; then
			component_type='vendor'
		else
			component_type="${component_directory##*/}"
		fi
	fi

	# shellcheck disable=SC2034
	JANGBI_IT_LOG_PREFIX="${component_type:-lib}: $component_name"
}

function _has_colors() {
	# Check that stdout is a terminal, and that it has at least 8 colors.
	[[ -t 1 && "${CLICOLOR:=$(tput colors 2> /dev/null)}" -ge 8 ]]
}

function _jangbi-it-log-message() { # _jangbi-it-log-message "${echo_green:-}" "DEBUG: " "$1"
	: _about 'Internal function used for logging, uses JANGBI_IT_LOG_PREFIX as a prefix'
	: _param '1: color of the message'
	: _param '2: log level to print before the prefix'
	: _param '3: message to log'
	: _group 'log'

	local prefix="${JANGBI_IT_LOG_PREFIX:-default}"
	local color="${1-${echo_cyan:-}}"
	local level="${2:-TRACE}"
	local message="${level%: }: ${prefix%: }: ${3?}"
	if _has_colors; then
		printf '%b%s%b\n' "${color}" "${message}" "${echo_normal:-}"
	else
		printf '%s\n' "${message}"
	fi
}

# Functions for measuring and reporting how long a command takes to run.

# Get shell duration in decimal format regardless of runtime locale.
# Notice: This function runs as a sub-shell - notice '(' vs '{'.
function _shell_duration_en() (
	# DFARREL You would think LC_NUMERIC would do it, but not working in my local.
	# Note: LC_ALL='en_US.UTF-8' has been used to enforce the decimal point to be
	# a period, but the specific locale 'en_US.UTF-8' is not ensured to exist in
	# the system.  One should instead use the locale 'C', which is ensured by the
	# C and POSIX standards.
	local LC_ALL=C
	printf "%s" "${EPOCHREALTIME:-$SECONDS}"
)

: "${COMMAND_DURATION_START_SECONDS:=$(_shell_duration_en)}"
: "${COMMAND_DURATION_ICON:=🕘}"
: "${COMMAND_DURATION_MIN_SECONDS:=1}"

function _command_duration_pre_exec() {
	COMMAND_DURATION_START_SECONDS="$(_shell_duration_en)"
}

function _command_duration_pre_cmd() {
	COMMAND_DURATION_START_SECONDS=""
}

function _dynamic_clock_icon {
	local clock_hand
	# clock hand value is between 90 and 9b in hexadecimal.
	# so between 144 and 155 in base 10.
	printf -v clock_hand '%x' $((((${1:-${SECONDS}} - 1) % 12) + 144))
	printf -v 'COMMAND_DURATION_ICON' '%b' "\xf0\x9f\x95\x$clock_hand"
}

function _command_duration() {
	[[ -n "${JANGBI_IT_COMMAND_DURATION:-}" ]] || return
	[[ -n "${COMMAND_DURATION_START_SECONDS:-}" ]] || return

	local command_duration=0 command_start="${COMMAND_DURATION_START_SECONDS:-0}"
	local -i minutes=0 seconds=0 deciseconds=0
	local -i command_start_seconds="${command_start%.*}"
	local -i command_start_deciseconds=$((10#${command_start##*.}))
	command_start_deciseconds="${command_start_deciseconds:0:1}"
	local current_time
	current_time="$(_shell_duration_en)"
	local -i current_time_seconds="${current_time%.*}"
	local -i current_time_deciseconds="$((10#${current_time##*.}))"
	current_time_deciseconds="${current_time_deciseconds:0:1}"

	if [[ "${command_start_seconds:-0}" -gt 0 ]]; then
		# seconds
		command_duration="$((current_time_seconds - command_start_seconds))"

		if ((current_time_deciseconds >= command_start_deciseconds)); then
			deciseconds="$((current_time_deciseconds - command_start_deciseconds))"
		else
			((command_duration -= 1))
			deciseconds="$((10 - (command_start_deciseconds - current_time_deciseconds)))"
		fi
	else
		command_duration=0
	fi

	if ((command_duration >= COMMAND_DURATION_MIN_SECONDS)); then
		minutes=$((command_duration / 60))
		seconds=$((command_duration % 60))

		_dynamic_clock_icon "${command_duration}"
		if ((minutes > 0)); then
			printf "%s %s%dm %ds" "${COMMAND_DURATION_ICON:-}" "${COMMAND_DURATION_COLOR:-}" "$minutes" "$seconds"
		else
			printf "%s %s%d.%01ds" "${COMMAND_DURATION_ICON:-}" "${COMMAND_DURATION_COLOR:-}" "$seconds" "$deciseconds"
		fi
	fi
}

_jangbi_it_library_finalize_hook+=("safe_append_preexec '_command_duration_pre_exec'")
_jangbi_it_library_finalize_hook+=("safe_append_prompt_command '_command_duration_pre_cmd'")

# A collection of reusable functions.

: "${JANGBI_IT_LOAD_PRIORITY_PLUGIN:=250}"
JANGBI_IT_LOAD_PRIORITY_SEPARATOR="---"

# Handle the different ways of running `sed` without generating a backup file based on provenance:
# - GNU sed (Linux) uses `-i''`
# - BSD sed (FreeBSD/macOS/Solaris/PlayStation) uses `-i ''`
# To use this in Bash-it for inline replacements with `sed`, use the following syntax:
# sed "${JANGBI_IT_SED_I_PARAMETERS[@]}" -e "..." file
# shellcheck disable=SC2034 # expected for this case
if sed --version > /dev/null 2>&1; then
	# GNU sed accepts "long" options
	JANGBI_IT_SED_I_PARAMETERS=('-i')
else
	# BSD sed errors on invalid option `-`
	JANGBI_IT_SED_I_PARAMETERS=('-i' '')
fi

function _jangbi_it_homebrew_check() {
	if _binary_exists 'brew'; then
		# Homebrew is installed
		if [[ "${JANGBI_IT_HOMEBREW_PREFIX:-unset}" == 'unset' ]]; then
			# variable isn't set
			JANGBI_IT_HOMEBREW_PREFIX="$(brew --prefix)"
		else
			true # Variable is set already, don't invoke `brew`.
		fi
	else
		# Homebrew is not installed: clear variable.
		JANGBI_IT_HOMEBREW_PREFIX=
		false # return failure if brew not installed.
	fi
}

function _make_reload_alias() {
	echo "source '${JANGBI_IT?}/reloader.bash' '${1?}' '${2?}'"
}

# Alias for reloading plugins
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
	local verb=${1:-}
	shift
	local component=${1:-}
	shift
	local func

	case "$verb" in
		show)
			func="_jangbi-it-$component"
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
			func="_jangbi-it-doctor-$component"
			;;
    restart)
			func="_jangbi-it-restart"
			;;
    reload)
			func="_jangbi-it-reload"
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

		if [[ -n "${JANGBI_IT_AUTOMATIC_RELOAD_AFTER_CONFIG_CHANGE:-}" ]]; then
			_jangbi-it-reload
		fi
	else
		"$func" "$@"
	fi
}

function _jangbi-it-plugins() {
	_about 'summarizes available jangbi_it plugins'
	_group 'lib'

	_jangbi-it-describe "plugins" "a" "plugin" "Plugin"
}

function _jangbi-it-doctor() {
	_about 'reloads a profile file with a JANGBI_IT_LOG_LEVEL set'
	_param '1: JANGBI_IT_LOG_LEVEL argument: "errors" "warnings" "all"'
	_group 'lib'

	# shellcheck disable=SC2034 # expected for this case
	local JANGBI_IT_LOG_LEVEL="${1?}"
	_jangbi-it-reload
}

function _jangbi-it-doctor-all() {
	_about 'reloads a profile file with error, warning and debug logs'
	_group 'lib'

	_jangbi-it-doctor "${JANGBI_IT_LOG_LEVEL_ALL?}"
}

function _jangbi-it-doctor-warnings() {
	_about 'reloads a profile file with error and warning logs'
	_group 'lib'

	_jangbi-it-doctor "${JANGBI_IT_LOG_LEVEL_WARNING?}"
}

function _jangbi-it-doctor-errors() {
	_about 'reloads a profile file with error logs'
	_group 'lib'

	_jangbi-it-doctor "${JANGBI_IT_LOG_LEVEL_ERROR?}"
}

function _jangbi-it-doctor-() {
	_about 'default jangbi-it doctor behavior, behaves like jangbi-it doctor all'
	_group 'lib'

	_jangbi-it-doctor-all
}

function _jangbi-it-restart() {
	_about 'restarts the shell in order to fully reload it'
	_group 'lib'
  echo "please run '$ source "${JANGBI_IT}/functions.sh"' manually."
	exec "${0#-}" --rcfile "${BASH_IT_BASHRC:-${HOME?}/.bashrc}"
}

function _jangbi-it-reload() {
	_about 'reloads the shell initialization file'
	_group 'lib'

	# shellcheck disable=SC1090
	source "${BASH_IT_BASHRC:-${HOME?}/.bashrc}"
  source "${JANGBI_IT}/functions.sh"
}

function _jangbi-it-describe() {
	_about 'summarizes available jangbi_it components'
	_param '1: subdirectory'
	_param '2: preposition'
	_param '3: file_type'
	_param '4: column_header'
	_example '$ _jangbi-it-describe "plugins" "a" "plugin" "Plugin"'

	local subdirectory preposition file_type column_header f enabled enabled_file
	subdirectory="$1"
	preposition="$2"
	file_type="$3"
	column_header="$4"

	printf "%-20s %-10s %s\n" "$column_header" 'Enabled?' 'Description'
	for f in "${JANGBI_IT?}/$subdirectory/available"/*.*.bash; do
		enabled=''
		enabled_file="${f##*/}"
		enabled_file="${enabled_file%."${file_type}"*.bash}"
		_jangbi-it-component-item-is-enabled "${file_type}" "${enabled_file}" && enabled='x'
		printf "%-20s %-10s %s\n" "$enabled_file" "[${enabled:- }]" "$(metafor "about-$file_type" < "$f")"
	done
	printf '\n%s\n' "to enable $preposition $file_type, do:"
	printf '%s\n' "$ jangbi-it enable $file_type  <$file_type name> [$file_type name]... -or- $ jangbi-it enable $file_type all"
	printf '\n%s\n' "to disable $preposition $file_type, do:"
	printf '%s\n' "$ jangbi-it disable $file_type <$file_type name> [$file_type name]... -or- $ jangbi-it disable $file_type all"
}

function _on-disable-callback() {
	_about 'Calls the disabled plugin destructor, if present'
	_param '1: plugin name'
	_example '$ _on-disable-callback gitstatus'
	_group 'lib'

	local callback="${1}_on_disable"
	if _command_exists "$callback"; then
		"$callback"
	fi
}

function _disable-all() {
	_about 'disables all jangbi_it components'
	_example '$ _disable-all'
	_group 'lib'

	_disable-plugin "all"
}

function _disable-plugin() {
	_about 'disables jangbi_it plugin'
	_param '1: plugin name'
	_example '$ disable-plugin rvm'
	_group 'lib'

	_disable-thing "plugins" "plugin" "${1?}"
	_on-disable-callback "${1?}"
}

function _disable-thing() {
	_about 'disables a jangbi_it component'
	_param '1: subdirectory'
	_param '2: file_type'
	_param '3: file_entity'
	_example '$ _disable-thing "plugins" "plugin" "ssh"'

	local subdirectory="${1?}"
	local file_type="${2?}"
	local file_entity="${3:-}"

	if [[ -z "$file_entity" ]]; then
		reference "disable-$file_type"
		return
	fi

	local f suffix _jangbi_it_config_file plugin
	suffix="${subdirectory/plugins/plugin}"

	if [[ "$file_entity" == "all" ]]; then
		# Disable everything that's using the old structure and everything in the global "enabled" directory.
		for _jangbi_it_config_file in "${JANGBI_IT}/$subdirectory/enabled"/*."${suffix}.bash" "${JANGBI_IT}/enabled"/*".${suffix}.bash"; do
			rm -f "$_jangbi_it_config_file"
		done
	else
		# Use a glob to search for both possible patterns
		# 250---node.plugin.bash
		# node.plugin.bash
		# Either one will be matched by this glob
		for plugin in "${JANGBI_IT}/enabled"/[[:digit:]][[:digit:]][[:digit:]]"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR}${file_entity}.${suffix}.bash" "${JANGBI_IT}/$subdirectory/enabled/"{[[:digit:]][[:digit:]][[:digit:]]"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR}${file_entity}.${suffix}.bash","${file_entity}.${suffix}.bash"}; do
			if [[ -e "${plugin}" ]]; then
				rm -f "${plugin}"
				plugin=
				break
			fi
		done
		if [[ -n "${plugin}" ]]; then
			printf '%s\n' "sorry, $file_entity does not appear to be an enabled $file_type."
			return
		fi
	fi

	_jangbi-it-component-cache-clean "${file_type}"

	if [[ "$file_entity" == "all" ]]; then
		_jangbi-it-component-pluralize "$file_type" file_type
		printf '%s\n' "$file_entity ${file_type} disabled."
	else
		printf '%s\n' "$file_entity disabled."
	fi
}

function _enable-plugin() {
	_about 'enables jangbi_it plugin'
	_param '1: plugin name'
	_example '$ enable-plugin rvm'
	_group 'lib'

	_enable-thing "plugins" "plugin" "${1?}" "$JANGBI_IT_LOAD_PRIORITY_PLUGIN"
}

function _enable-plugins() {
	_about 'alias of _enable-plugin'
	_enable-plugin "$@"
}

function _enable-thing() {
	cite _about _param _example
	_about 'enables a jangbi_it component'
	_param '1: subdirectory'
	_param '2: file_type'
	_param '3: file_entity'
	_param '4: load priority'
	_example '$ _enable-thing "plugins" "plugin" "ssh" "150"'

	local subdirectory="${1?}"
	local file_type="${2?}"
	local file_entity="${3:-}"
	local load_priority="${4:-500}"

	if [[ -z "$file_entity" ]]; then
		reference "enable-$file_type"
		return
	fi

	local _jangbi_it_config_file to_enable to_enables enabled_plugin local_file_priority use_load_priority
	local suffix="${subdirectory/plugins/plugin}"

	if [[ "$file_entity" == "all" ]]; then
		for _jangbi_it_config_file in "${JANGBI_IT}/$subdirectory/available"/*.bash; do
			to_enable="${_jangbi_it_config_file##*/}"
			_enable-thing "$subdirectory" "$file_type" "${to_enable%."${file_type/alias/aliases}".bash}" "$load_priority"
		done
	else
		to_enables=("${JANGBI_IT}/$subdirectory/available/$file_entity.${suffix}.bash")
		if [[ ! -e "${to_enables[0]}" ]]; then
			printf '%s\n' "sorry, $file_entity does not appear to be an available $file_type."
			return
		fi

		to_enable="${to_enables[0]##*/}"
		# Check for existence of the file using a wildcard, since we don't know which priority might have been used when enabling it.
		for enabled_plugin in "${JANGBI_IT}/$subdirectory/enabled"/{[[:digit:]][[:digit:]][[:digit:]]"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR}${to_enable}","${to_enable}"} "${JANGBI_IT}/enabled"/[[:digit:]][[:digit:]][[:digit:]]"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR?}${to_enable}"; do
			if [[ -e "${enabled_plugin}" ]]; then
				printf '%s\n' "$file_entity is already enabled."
				return
			fi
		done

		mkdir -p "${JANGBI_IT}/enabled"

		# Load the priority from the file if it present there
		local_file_priority="$(awk -F': ' '$1 == "# JANGBI_IT_LOAD_PRIORITY" { print $2 }' "${JANGBI_IT}/$subdirectory/available/$to_enable")"
		use_load_priority="${local_file_priority:-$load_priority}"

		ln -s "../$subdirectory/available/$to_enable" "${JANGBI_IT}/enabled/${use_load_priority}${JANGBI_IT_LOAD_PRIORITY_SEPARATOR}${to_enable}"
	fi

	_jangbi-it-component-cache-clean "${file_type}"

	printf '%s\n' "$file_entity enabled with priority $use_load_priority."
}

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

function pathmunge() {
	about 'prevent duplicate directories in your PATH variable'
	group 'helpers'
	example 'pathmunge /path/to/dir is equivalent to PATH=/path/to/dir:$PATH'
	example 'pathmunge /path/to/dir after is equivalent to PATH=$PATH:/path/to/dir'

	if [[ -d "${1:-}" && ! $PATH =~ (^|:)"${1}"($|:) ]]; then
		if [[ "${2:-before}" == "after" ]]; then
			export PATH="$PATH:${1}"
		else
			export PATH="${1}:$PATH"
		fi
	fi
}

# `_jangbi-it-find-in-ancestor` uses the shell's ability to run a function in
# a subshell to simplify our search to a simple `cd ..` and `[[ -r $1 ]]`
# without any external dependencies. Let the shell do what it's good at.
function _jangbi-it-find-in-ancestor() (
	: _about 'searches parents of the current directory for any of the specified file names'
	: _group 'helpers'
	: _param '*: names of files or folders to search for'
	: _returns '0: prints path of closest matching ancestor directory to stdout'
	: _returns '1: no match found'
	: _returns '2: improper usage of shell builtin' # uncommon
	: _example '_jangbi-it-find-in-ancestor .git .hg'
	: _example '_jangbi-it-find-in-ancestor GNUmakefile Makefile makefile'

	local kin
	# To keep things simple, we do not search the root dir.
	while [[ "${PWD}" != '/' ]]; do
		for kin in "$@"; do
			if [[ -r "${PWD}/${kin}" ]]; then
				printf '%s' "${PWD}"
				return "$?"
			fi
		done
		command cd .. || return "$?"
	done
	return 1
)

# Load the `bash-preexec.sh` library, and define helper functions

## Prepare, load, fix, and install `bash-preexec.sh`

# Disable `$PROMPT_COMMAND` modification for now.
__bp_delay_install="delayed"

# shellcheck source-path=SCRIPTDIR/../vendor/github.com/rcaloras/bash-preexec
# bash-preexec.sh -- Bash support for ZSH-like 'preexec' and 'precmd' functions.
# https://github.com/rcaloras/bash-preexec
#
#
# 'preexec' functions are executed before each interactive command is
# executed, with the interactive command as its argument. The 'precmd'
# function is executed before each prompt is displayed.
#
# Author: Ryan Caloras (ryan@bashhub.com)
# Forked from Original Author: Glyph Lefkowitz
#
# V0.4.1
#

# General Usage:
#
#  1. Source this file at the end of your bash profile so as not to interfere
#     with anything else that's using PROMPT_COMMAND.
#
#  2. Add any precmd or preexec functions by appending them to their arrays:
#       e.g.
#       precmd_functions+=(my_precmd_function)
#       precmd_functions+=(some_other_precmd_function)
#
#       preexec_functions+=(my_preexec_function)
#
#  3. Consider changing anything using the DEBUG trap or PROMPT_COMMAND
#     to use preexec and precmd instead. Preexisting usages will be
#     preserved, but doing so manually may be less surprising.
#
#  Note: This module requires two Bash features which you must not otherwise be
#  using: the "DEBUG" trap, and the "PROMPT_COMMAND" variable. If you override
#  either of these after bash-preexec has been installed it will most likely break.

# Make sure this is bash that's running and return otherwise.
if [[ -z "${BASH_VERSION:-}" ]]; then
    return 1;
fi

# Avoid duplicate inclusion
if [[ -n "${bash_preexec_imported:-}" ]]; then
    return 0
fi
bash_preexec_imported="defined"

# WARNING: This variable is no longer used and should not be relied upon.
# Use ${bash_preexec_imported} instead.
__bp_imported="${bash_preexec_imported}"

# Should be available to each precmd and preexec
# functions, should they want it. $? and $_ are available as $? and $_, but
# $PIPESTATUS is available only in a copy, $BP_PIPESTATUS.
# TODO: Figure out how to restore PIPESTATUS before each precmd or preexec
# function.
__bp_last_ret_value="$?"
BP_PIPESTATUS=("${PIPESTATUS[@]}")
__bp_last_argument_prev_command="$_"

__bp_inside_precmd=0
__bp_inside_preexec=0

# Initial PROMPT_COMMAND string that is removed from PROMPT_COMMAND post __bp_install
__bp_install_string=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'

# Fails if any of the given variables are readonly
# Reference https://stackoverflow.com/a/4441178
__bp_require_not_readonly() {
  local var
  for var; do
    if ! ( unset "$var" 2> /dev/null ); then
      echo "bash-preexec requires write access to ${var}" >&2
      return 1
    fi
  done
}

# Remove ignorespace and or replace ignoreboth from HISTCONTROL
# so we can accurately invoke preexec with a command from our
# history even if it starts with a space.
__bp_adjust_histcontrol() {
    local histcontrol
    histcontrol="${HISTCONTROL:-}"
    histcontrol="${histcontrol//ignorespace}"
    # Replace ignoreboth with ignoredups
    if [[ "$histcontrol" == *"ignoreboth"* ]]; then
        histcontrol="ignoredups:${histcontrol//ignoreboth}"
    fi;
    export HISTCONTROL="$histcontrol"
}

# This variable describes whether we are currently in "interactive mode";
# i.e. whether this shell has just executed a prompt and is waiting for user
# input.  It documents whether the current command invoked by the trace hook is
# run interactively by the user; it's set immediately after the prompt hook,
# and unset as soon as the trace hook is run.
__bp_preexec_interactive_mode=""

# These arrays are used to add functions to be run before, or after, prompts.
declare -a precmd_functions
declare -a preexec_functions

# Trims leading and trailing whitespace from $2 and writes it to the variable
# name passed as $1
__bp_trim_whitespace() {
    local var=${1:?} text=${2:-}
    text="${text#"${text%%[![:space:]]*}"}"   # remove leading whitespace characters
    text="${text%"${text##*[![:space:]]}"}"   # remove trailing whitespace characters
    printf -v "$var" '%s' "$text"
}


# Trims whitespace and removes any leading or trailing semicolons from $2 and
# writes the resulting string to the variable name passed as $1. Used for
# manipulating substrings in PROMPT_COMMAND
__bp_sanitize_string() {
    local var=${1:?} text=${2:-} sanitized
    __bp_trim_whitespace sanitized "$text"
    sanitized=${sanitized%;}
    sanitized=${sanitized#;}
    __bp_trim_whitespace sanitized "$sanitized"
    printf -v "$var" '%s' "$sanitized"
}

# This function is installed as part of the PROMPT_COMMAND;
# It sets a variable to indicate that the prompt was just displayed,
# to allow the DEBUG trap to know that the next command is likely interactive.
__bp_interactive_mode() {
    __bp_preexec_interactive_mode="on";
}


# This function is installed as part of the PROMPT_COMMAND.
# It will invoke any functions defined in the precmd_functions array.
__bp_precmd_invoke_cmd() {
    # Save the returned value from our last command, and from each process in
    # its pipeline. Note: this MUST be the first thing done in this function.
    __bp_last_ret_value="$?" BP_PIPESTATUS=("${PIPESTATUS[@]}")

    # Don't invoke precmds if we are inside an execution of an "original
    # prompt command" by another precmd execution loop. This avoids infinite
    # recursion.
    if (( __bp_inside_precmd > 0 )); then
      return
    fi
    local __bp_inside_precmd=1

    # Invoke every function defined in our function array.
    local precmd_function
    for precmd_function in "${precmd_functions[@]}"; do

        # Only execute this function if it actually exists.
        # Test existence of functions with: declare -[Ff]
        if type -t "$precmd_function" 1>/dev/null; then
            __bp_set_ret_value "$__bp_last_ret_value" "$__bp_last_argument_prev_command"
            # Quote our function invocation to prevent issues with IFS
            "$precmd_function"
        fi
    done
}

# Sets a return value in $?. We may want to get access to the $? variable in our
# precmd functions. This is available for instance in zsh. We can simulate it in bash
# by setting the value here.
__bp_set_ret_value() {
    return ${1:-}
}

__bp_in_prompt_command() {

    local prompt_command_array
    IFS=$'\n;' read -rd '' -a prompt_command_array <<< "${PROMPT_COMMAND:-}"

    local trimmed_arg
    __bp_trim_whitespace trimmed_arg "${1:-}"

    local command trimmed_command
    for command in "${prompt_command_array[@]:-}"; do
        __bp_trim_whitespace trimmed_command "$command"
        if [[ "$trimmed_command" == "$trimmed_arg" ]]; then
            return 0
        fi
    done

    return 1
}

# This function is installed as the DEBUG trap.  It is invoked before each
# interactive prompt display.  Its purpose is to inspect the current
# environment to attempt to detect if the current command is being invoked
# interactively, and invoke 'preexec' if so.
__bp_preexec_invoke_exec() {

    # Save the contents of $_ so that it can be restored later on.
    # https://stackoverflow.com/questions/40944532/bash-preserve-in-a-debug-trap#40944702
    __bp_last_argument_prev_command="${1:-}"
    # Don't invoke preexecs if we are inside of another preexec.
    if (( __bp_inside_preexec > 0 )); then
      return
    fi
    local __bp_inside_preexec=1

    # Checks if the file descriptor is not standard out (i.e. '1')
    # __bp_delay_install checks if we're in test. Needed for bats to run.
    # Prevents preexec from being invoked for functions in PS1
    if [[ ! -t 1 && -z "${__bp_delay_install:-}" ]]; then
        return
    fi

    if [[ -n "${COMP_LINE:-}" ]]; then
        # We're in the middle of a completer. This obviously can't be
        # an interactively issued command.
        return
    fi
    if [[ -z "${__bp_preexec_interactive_mode:-}" ]]; then
        # We're doing something related to displaying the prompt.  Let the
        # prompt set the title instead of me.
        return
    else
        # If we're in a subshell, then the prompt won't be re-displayed to put
        # us back into interactive mode, so let's not set the variable back.
        # In other words, if you have a subshell like
        #   (sleep 1; sleep 2)
        # You want to see the 'sleep 2' as a set_command_title as well.
        if [[ 0 -eq "${BASH_SUBSHELL:-}" ]]; then
            __bp_preexec_interactive_mode=""
        fi
    fi

    if  __bp_in_prompt_command "${BASH_COMMAND:-}"; then
        # If we're executing something inside our prompt_command then we don't
        # want to call preexec. Bash prior to 3.1 can't detect this at all :/
        __bp_preexec_interactive_mode=""
        return
    fi

    local this_command
    this_command=$(
        export LC_ALL=C
        HISTTIMEFORMAT= builtin history 1 | sed '1 s/^ *[0-9][0-9]*[* ] //'
    )

    # Sanity check to make sure we have something to invoke our function with.
    if [[ -z "$this_command" ]]; then
        return
    fi

    # Invoke every function defined in our function array.
    local preexec_function
    local preexec_function_ret_value
    local preexec_ret_value=0
    for preexec_function in "${preexec_functions[@]:-}"; do

        # Only execute each function if it actually exists.
        # Test existence of function with: declare -[fF]
        if type -t "$preexec_function" 1>/dev/null; then
            __bp_set_ret_value ${__bp_last_ret_value:-}
            # Quote our function invocation to prevent issues with IFS
            "$preexec_function" "$this_command"
            preexec_function_ret_value="$?"
            if [[ "$preexec_function_ret_value" != 0 ]]; then
                preexec_ret_value="$preexec_function_ret_value"
            fi
        fi
    done

    # Restore the last argument of the last executed command, and set the return
    # value of the DEBUG trap to be the return code of the last preexec function
    # to return an error.
    # If `extdebug` is enabled a non-zero return value from any preexec function
    # will cause the user's command not to execute.
    # Run `shopt -s extdebug` to enable
    __bp_set_ret_value "$preexec_ret_value" "$__bp_last_argument_prev_command"
}

__bp_install() {
    # Exit if we already have this installed.
    if [[ "${PROMPT_COMMAND:-}" == *"__bp_precmd_invoke_cmd"* ]]; then
        return 1;
    fi

    trap '__bp_preexec_invoke_exec "$_"' DEBUG

    # Preserve any prior DEBUG trap as a preexec function
    local prior_trap=$(sed "s/[^']*'\(.*\)'[^']*/\1/" <<<"${__bp_trap_string:-}")
    unset __bp_trap_string
    if [[ -n "$prior_trap" ]]; then
        eval '__bp_original_debug_trap() {
          '"$prior_trap"'
        }'
        preexec_functions+=(__bp_original_debug_trap)
    fi

    # Adjust our HISTCONTROL Variable if needed.
    __bp_adjust_histcontrol

    # Issue #25. Setting debug trap for subshells causes sessions to exit for
    # backgrounded subshell commands (e.g. (pwd)& ). Believe this is a bug in Bash.
    #
    # Disabling this by default. It can be enabled by setting this variable.
    if [[ -n "${__bp_enable_subshells:-}" ]]; then

        # Set so debug trap will work be invoked in subshells.
        set -o functrace > /dev/null 2>&1
        shopt -s extdebug > /dev/null 2>&1
    fi;

    local existing_prompt_command
    # Remove setting our trap install string and sanitize the existing prompt command string
    existing_prompt_command="${PROMPT_COMMAND:-}"
    # shellcheck disable=SC1087
    existing_prompt_command="${existing_prompt_command//$__bp_install_string[;$'\n']}" # Edge case of appending to PROMPT_COMMAND
    existing_prompt_command="${existing_prompt_command//$__bp_install_string}"
    __bp_sanitize_string existing_prompt_command "$existing_prompt_command"

    # Install our hooks in PROMPT_COMMAND to allow our trap to know when we've
    # actually entered something.
    PROMPT_COMMAND=$'__bp_precmd_invoke_cmd\n'
    if [[ -n "$existing_prompt_command" ]]; then
        PROMPT_COMMAND+=${existing_prompt_command}$'\n'
    fi;
    PROMPT_COMMAND+='__bp_interactive_mode'

    # Add two functions to our arrays for convenience
    # of definition.
    precmd_functions+=(precmd)
    preexec_functions+=(preexec)

    # Invoke our two functions manually that were added to $PROMPT_COMMAND
    __bp_precmd_invoke_cmd
    __bp_interactive_mode
}

# Sets an installation string as part of our PROMPT_COMMAND to install
# after our session has started. This allows bash-preexec to be included
# at any point in our bash profile.
__bp_install_after_session_init() {
    # bash-preexec needs to modify these variables in order to work correctly
    # if it can't, just stop the installation
    __bp_require_not_readonly PROMPT_COMMAND HISTCONTROL HISTTIMEFORMAT || return

    local sanitized_prompt_command
    __bp_sanitize_string sanitized_prompt_command "${PROMPT_COMMAND:-}"
    if [[ -n "$sanitized_prompt_command" ]]; then
        PROMPT_COMMAND=${sanitized_prompt_command}$'\n'
    fi;
    PROMPT_COMMAND+=${__bp_install_string}
}

# Run our install so long as we're not delaying it.
if [[ -z "${__bp_delay_install:-}" ]]; then
    __bp_install_after_session_init
fi;

# Block damanaging user's `$HISTCONTROL`
function __bp_adjust_histcontrol() { :; }

# Don't fail on readonly variables
function __bp_require_not_readonly() { :; }

# For performance, testing, and to avoid unexpected behavior: disable DEBUG traps in subshells.
# See jangbi-it/jangbi-it#1040 and rcaloras/bash-preexec#26
: "${__bp_enable_subshells:=}" # blank

# Modify `$PROMPT_COMMAND` in finalize hook
_jangbi_it_library_finalize_hook+=('__bp_install_after_session_init')

## Helper functions
function __check_precmd_conflict() {
	local f
	__bp_trim_whitespace f "${1?}"
	_bash-it-array-contains-element "${f}" "${precmd_functions[@]}"
}

function __check_preexec_conflict() {
	local f
	__bp_trim_whitespace f "${1?}"
	_bash-it-array-contains-element "${f}" "${preexec_functions[@]}"
}

function safe_append_prompt_command() {
	local prompt_re prompt_er f

	if [[ "${bash_preexec_imported:-${__bp_imported:-missing}}" == "defined" ]]; then
		# We are using bash-preexec
		__bp_trim_whitespace f "${1?}"
		if ! __check_precmd_conflict "${f}"; then
			precmd_functions+=("${f}")
		fi
	else
		# Match on word-boundaries
		prompt_re='(^|[^[:alnum:]_])'
		prompt_er='([^[:alnum:]_]|$)'
		if [[ ${PROMPT_COMMAND} =~ ${prompt_re}"${1}"${prompt_er} ]]; then
			return
		elif [[ -z ${PROMPT_COMMAND} ]]; then
			PROMPT_COMMAND="${1}"
		else
			PROMPT_COMMAND="${1};${PROMPT_COMMAND}"
		fi
	fi
}

function safe_append_preexec() {
	local prompt_re f

	if [[ "${bash_preexec_imported:-${__bp_imported:-missing}}" == "defined" ]]; then
		# We are using bash-preexec
		__bp_trim_whitespace f "${1?}"
		if ! __check_preexec_conflict "${f}"; then
			preexec_functions+=("${f}")
		fi
	fi
}

# A collection of reusable functions.

###########################################################################
# Generic utilies
###########################################################################

function _bash-it-get-component-name-from-path() {
	local filename
	# filename without path
	filename="${1##*/}"
	# filename without path or priority
	filename="${filename##*"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR?}"}"
	# filename without path, priority or extension
	echo "${filename%.*.bash}"
}

function _bash-it-get-component-type-from-path() {
	local filename
	# filename without path
	filename="${1##*/}"
	# filename without extension
	filename="${filename%.bash}"
	# extension without priority or name
	filename="${filename##*.}"
	echo "${filename}"
}

# This function searches an array for an exact match against the term passed
# as the first argument to the function. This function exits as soon as
# a match is found.
#
# Returns:
#   0 when a match is found, otherwise 1.
#
# Examples:
#   $ declare -a fruits=(apple orange pear mandarin)
#
#   $ _bash-it-array-contains-element apple "@{fruits[@]}" && echo 'contains apple'
#   contains apple
#
#   $ if _bash-it-array-contains-element pear "${fruits[@]}"; then
#       echo "contains pear!"
#     fi
#   contains pear!
#
#
function _bash-it-array-contains-element() {
	local e element="${1?}"
	shift
	for e in "$@"; do
		[[ "$e" == "${element}" ]] && return 0
	done
	return 1
}

# Dedupe an array (without embedded newlines).
function _bash-it-array-dedup() {
	printf '%s\n' "$@" | sort -u
}

# Runs `grep` with *just* the provided arguments
function _bash-it-grep() {
	: "${JANGBI_IT_GREP:=$(type -P grep)}"
	"${JANGBI_IT_GREP:-/usr/bin/grep}" "$@"
}

# Runs `grep` with fixed-string expressions (-F)
function _bash-it-fgrep() {
	: "${JANGBI_IT_GREP:=$(type -P grep)}"
	"${JANGBI_IT_GREP:-/usr/bin/grep}" -F "$@"
}

# Runs `grep` with extended regular expressions (-E)
function _bash-it-egrep() {
	: "${JANGBI_IT_GREP:=$(type -P grep)}"
	"${JANGBI_IT_GREP:-/usr/bin/grep}" -E "$@"
}

function _command_exists() {
	: _about 'checks for existence of a command'
	: _param '1: command to check'
	: _example '$ _command_exists ls && echo exists'
	: _group 'lib'

	type -t "${1?}" > /dev/null
}

function _binary_exists() {
	: _about 'checks for existence of a binary'
	: _param '1: binary to check'
	: _example '$ _binary_exists ls && echo exists'
	: _group 'lib'

	type -P "${1?}" > /dev/null
}

function _completion_exists() {
	: _about 'checks for existence of a completion'
	: _param '1: command to check'
	: _example '$ _completion_exists gh && echo exists'
	: _group 'lib'

	complete -p "${1?}" &> /dev/null
}

function _is_function() {
	: _about 'sets $? to true if parameter is the name of a function'
	: _param '1: name of alleged function'
	: _example '$ _is_function ls && echo exists'
	: _group 'lib'

	declare -F "${1?}" > /dev/null
}

###########################################################################
# Component-specific functions (component is either an alias, a plugin, or a
# completion).
###########################################################################

function _jangbi-it-component-help() {
	local component file func
	_jangbi-it-component-pluralize "${1}" component
	_jangbi-it-component-cache-file "${component}" file
	if [[ ! -s "${file?}" || -z "$(find "${file}" -mmin -300)" ]]; then
		func="_jangbi-it-${component?}"
		"${func}" | _bash-it-egrep '\[[x ]\]' >| "${file}"
	fi
	cat "${file}"
}

function _jangbi-it-component-cache-file() {
	local _component_to_cache _file_path _result="${2:-${FUNCNAME[0]//-/_}}"
	_jangbi-it-component-pluralize "${1?${FUNCNAME[0]}: component name required}" _component_to_cache
	_file_path="${XDG_CACHE_HOME:-${HOME?}/.cache}/bash/${_component_to_cache?}"
	[[ -f "${_file_path}" ]] || mkdir -p "${_file_path%/*}"
	printf -v "${_result?}" '%s' "${_file_path}"
}

function _jangbi-it-component-singularize() {
	local _result="${2:-${FUNCNAME[0]//-/_}}"
	local _component_to_single="${1?${FUNCNAME[0]}: component name required}"
	local -i len="$((${#_component_to_single} - 2))"
	if [[ "${_component_to_single:${len}:2}" == 'ns' ]]; then
		_component_to_single="${_component_to_single%s}"
	elif [[ "${_component_to_single}" == "aliases" ]]; then
		_component_to_single="${_component_to_single%es}"
	fi
	printf -v "${_result?}" '%s' "${_component_to_single}"
}

function _jangbi-it-component-pluralize() {
	local _result="${2:-${FUNCNAME[0]//-/_}}"
	local _component_to_plural="${1?${FUNCNAME[0]}: component name required}"
	local -i len="$((${#_component_to_plural} - 1))"
	# pluralize component name for consistency
	if [[ "${_component_to_plural:${len}:1}" != 's' ]]; then
		_component_to_plural="${_component_to_plural}s"
	elif [[ "${_component_to_plural}" == "alias" ]]; then
		_component_to_plural="${_component_to_plural}es"
	fi
	printf -v "${_result?}" '%s' "${_component_to_plural}"
}

function _jangbi-it-component-cache-clean() {
	local component="${1:-}"
	local cache
	local -a components=('plugins')
	if [[ -z "${component}" ]]; then
		for component in "${components[@]}"; do
			_jangbi-it-component-cache-clean "${component}"
		done
	else
		_jangbi-it-component-cache-file "${component}" cache
		: >| "${cache:?}"
	fi
}

# Returns an array of items within each compoenent.
function _jangbi-it-component-list() {
	local IFS=$'\n' component="$1"
	_jangbi-it-component-help "${component}" | awk '{print $1}' | sort -u
}

function _jangbi-it-component-list-matching() {
	local component="$1"
	shift
	local term="$1"
	_jangbi-it-component-help "${component}" | _bash-it-egrep -- "${term}" | awk '{print $1}' | sort -u
}

function _jangbi-it-component-list-enabled() {
	local IFS=$'\n' component="$1"
	_jangbi-it-component-help "${component}" | _bash-it-fgrep '[x]' | awk '{print $1}' | sort -u
}

function _jangbi-it-component-list-disabled() {
	local IFS=$'\n' component="$1"
	_jangbi-it-component-help "${component}" | _bash-it-fgrep -v '[x]' | awk '{print $1}' | sort -u
}

# Checks if a given item is enabled for a particular component/file-type.
#
# Returns:
#    0 if an item of the component is enabled, 1 otherwise.
#
# Examples:
#    _jangbi-it-component-item-is-enabled alias git && echo "git alias is enabled"
function _jangbi-it-component-item-is-enabled() {
	local component_type item_name each_file

	if [[ -f "${1?}" ]]; then
		item_name="$(_jangbi-it-get-component-name-from-path "${1}")"
		component_type="$(_jangbi-it-get-component-type-from-path "${1}")"
	else
		component_type="${1}" item_name="${2?}"
	fi

	for each_file in "${JANGBI_IT?}/enabled"/*"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR?}${item_name}.${component_type}"*."bash" \
		"${JANGBI_IT}/${component_type}"*/"enabled/${item_name}.${component_type}"*."bash" \
		"${JANGBI_IT}/${component_type}"*/"enabled"/*"${JANGBI_IT_LOAD_PRIORITY_SEPARATOR?}${item_name}.${component_type}"*."bash"; do
		if [[ -f "${each_file}" ]]; then
			return 0
		fi
	done

	return 1
}

# Checks if a given item is disabled for a particular component/file-type.
#
# Returns:
#    0 if an item of the component is enabled, 1 otherwise.
#
# Examples:
#    _jangbi-it-component-item-is-disabled alias git && echo "git aliases are disabled"
function _jangbi-it-component-item-is-disabled() {
	! _jangbi-it-component-item-is-enabled "$@"
}

# Load the global "enabled" directory, then enabled aliases, completion, plugins
# "_jangbi_it_main_file_type" param is empty so that files get sourced in glob order
for _jangbi_it_main_file_type in "" "plugins"; do
	JANGBI_IT_LOG_PREFIX="core: reloader: "
	# shellcheck disable=SC2140
	source "${JANGBI_IT}/reloader.bash" ${_jangbi_it_main_file_type:+"skip" "$_jangbi_it_main_file_type"}
	JANGBI_IT_LOG_PREFIX="core: main: "
done
### end of jangbi-it(bash-it) loading ###

### custom functions for jangbi ###
_get_rip(){
  if [[ $(ip addr show dev "${1}" |grep inet|wc -l) -gt 1 ]]; then
    ip addr show dev "${1}" |grep inet|grep -v inet6|cut -d' ' -f6
  else
    echo "127.0.0.1"
  fi
}

_trim_string() { # Usage: _trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

_load_config() { # Load config including parent config ex) _load_config .config
  local conf=".config"
  JB_VARS=""
  [[ ! -f "${conf}" ]] && log_fatal "config file ${conf} not exist." && exit 1
  stack=()
  pushstk() { stack+=("$@"); }
  # track config to top
  while [[ -n ${conf} ]] ;
  do
    pushstk ${conf//\"/}
    if [[ $(cat ${conf//\"/}|grep -c ^PARENT_CONFIG) -gt 0 ]]; then
      conf=$(cat ${conf//\"/}|grep PARENT_CONFIG|cut -d= -f2)
    else
      conf=
    fi
  done
  # echo "load next configs : ${stack[@]}"
  # load config in order
  for((j=${#stack[@]};j>0;j--)){
    conf=${stack[j-1]}
    # echo "config file(${conf}) is loading..."
    [[ -f ${conf} ]] && source ${conf}
    JB_VARS="${JB_VARS} $(cat ${conf}|grep -v '^#'|grep .|cut -d= -f1)"
    JB_CFILES="${JB_CFILES} ${conf}"
  }
  JB_VARS="${JB_VARS} JB_CFILES"

  # setup slog
  LOGFILE=${LOGFILE:="jangbi.log"}
  LOG_PATH="$LOGFILE"
  RUN_LOG="$LOGFILE"
  RUN_ERRORS_FATAL=${RUN_ERRORS_FATAL:=1}
  LOG_LEVEL_STDOUT=${LOG_LEVEL_STDOUT:="INFO"}
  LOG_LEVEL_LOG=${LOG_LEVEL_LOG:="DEBUG"}
}

_checkbin() {
  if ! which "${1}" 1>/dev/null 2>&1;then
    log_fatal "You must install '${1}'."
    return 1
  fi
}

_root_only() {
  if [[ $EUID -ne 0 ]]; then
    log_fatal "This script must be run as root"
    exit 1
  fi
}

_distname_check() {
  sysosinfo=$(lsb_release -i|awk '{print tolower($3)}')_$(lsb_release -cs)_$(arch)

  if [[ ${DIST_NAME,,} != ${sysosinfo,,} ]]; then
    log_fatal "DIST_NAME=${DIST_NAME} on  config is different system value(${sysosinfo})"
    exit 1
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
  apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends $1| grep "^\w" > /tmp/compare_pkg
  grep -Fxv -f .task-desktop /tmp/compare_pkg > /tmp/unique_pkg
  pushd pkgs 1>/dev/null 2>&1
  cp /tmp/unique_pkg "${pkgname}.pkgs"
  apt download $(</tmp/unique_pkg)
  popd 1>/dev/null 2>&1
}

_download_github_pkgs(){ # _download_github_pkgs DNSCrypt/dnscrypt-proxy dnscrypt-proxy-linux*.tar.gz
  local arch1=$(dpkg --print-architecture)
  local arch2=$(arch)
  [[ $(echo $1|grep -c "/") != 1 ]] && log_debug "please set only githubid/repoid." && return 1
  local pkgurl="https://api.github.com/repos/$(_trim_string $1)/releases/latest"
  # log_debug "DownloadURL : ${pkgurl}"
  IFS=$'\*' read -rd '' -a pkgfilefix <<<"$(_trim_string $2)"
  [[ $(find ./pkgs/$2 2>/dev/null|wc -l) -gt 0 ]] && rm ./pkgs/$2
  pkgfileprefix=$(_trim_string ${pkgfilefix[0],,})
  pkgfilepostfix=$(_trim_string ${pkgfilefix[1],,})
  local possible_list=$(curl -sSL "${pkgurl}" | jq -r '.assets[] | select(.name | contains("'${arch1}'") or contains("'${arch2}'")) | .browser_download_url')
  # log_debug "List : ${possible_list}"
  IFS=$'\n' read -rd '' -a durls <<<"$possible_list"
  for((k=0;k<${#durls[@]};k++)){
    durl=$(_trim_string ${durls[k],,});
    if [[ ${#durls[@]} -gt 1 ]]; then # https://github.com/draios/sysdig/releases/download/0.40.1/sysdig-0.40.1-x86_64.deb
      if [[ ${durl} == *"linux"* && ${durl} == *"${pkgfilepostfix}" ]]; then # https://github.com/vectordotdev/vector/releases/download/v0.48.0/vector_0.48.0-1_amd64.deb
        log_debug "Downloading ${durl} to ${pkgfileprefix} ${pkgfilepostfix}..."
        wget --directory-prefix=./pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        break
      elif [[ ${durl} == *"${arch1}"* && ${durl} == *"${pkgfilepostfix}" ]]; then
        log_debug "Downloading ${durl} to ${arch1} ${pkgfilepostfix}..."
        wget --directory-prefix=./pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        break
      elif [[ ${durl} == *"${arch2}"* && ${durl} == *"${pkgfilepostfix}" ]]; then
        log_debug "Downloading ${durl} to ${arch2} ${pkgfilepostfix}..."
        wget --directory-prefix=./pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        break
      fi
    else
      if [[ ${durl} == *"${pkgfileprefix}"* && ${durl} == *"${pkgfilepostfix}" ]]; then 
        log_debug "Downloading ${durl} to ${pkgfileprefix} ${pkgfilepostfix}..."
        wget --directory-prefix=./pkgs "${durl}" || (log_error "error downloading ${pkgfile}"; return 1)
        break
      fi
    fi
  }
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

