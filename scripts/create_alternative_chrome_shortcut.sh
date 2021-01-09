#!/usr/bin/env bash

read -r -d '' _HELP <<EOM
This script creates a new shortcut for Google Chrome which opens using a
different user data directory. This lets you have different icons for different
instances of Google Chrome.

Please check the following URL for more information:
  https://github.com/gustavoggsb/dotfiles#create_alternative_chrome_shortcutsh
EOM

# ARG_POSITIONAL_SINGLE([display-name],[The name which will be displayed in the app launcher],[Alternative])
# ARG_OPTIONAL_BOOLEAN([force],[f],[Do not ask for confirmation])
# ARG_HELP([],[$_HELP\n])
# ARGBASH_SET_INDENT([  ])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.8.1 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info

die() {
  local _ret="${2:-1}"
  test "${_PRINT_HELP:-no}" = yes && print_help >&2
  echo "$1" >&2
  exit "${_ret}"
}

begins_with_short_option() {
  local first_option all_short_options='fh'
  first_option="${1:0:1}"
  test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_display_name="Alternative"
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_force="off"

print_help() {
  printf 'Usage: %s [-f|--(no-)force] [-h|--help] [<display-name>]\n' "$0"
  printf '\t%s\n' "<display-name>: The name which will be displayed in the app launcher (default: 'Alternative')"
  printf '\t%s\n' "-f, --force, --no-force: Do not ask for confirmation (off by default)"
  printf '\t%s\n' "-h, --help: Prints help"
  printf '\n%s\n' "$_HELP
"
}

parse_commandline() {
  _positionals_count=0
  while test $# -gt 0; do
    _key="$1"
    case "$_key" in
    -f | --no-force | --force)
      _arg_force="on"
      test "${1:0:5}" = "--no-" && _arg_force="off"
      ;;
    -f*)
      _arg_force="on"
      _next="${_key##-f}"
      if test -n "$_next" -a "$_next" != "$_key"; then
        { begins_with_short_option "$_next" && shift && set -- "-f" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
      fi
      ;;
    -h | --help)
      print_help
      exit 0
      ;;
    -h*)
      print_help
      exit 0
      ;;
    *)
      _last_positional="$1"
      _positionals+=("$_last_positional")
      _positionals_count=$((_positionals_count + 1))
      ;;
    esac
    shift
  done
}

handle_passed_args_count() {
  test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect between 0 and 1, but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}

assign_positional_args() {
  local _positional_name _shift_for=$1
  _positional_names="_arg_display_name "

  shift "$_shift_for"
  for _positional_name in ${_positional_names}; do
    test $# -gt 0 || break
    eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
    shift
  done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

# OTHER STUFF GENERATED BY Argbash

### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash

set -euo pipefail

display_name=$_arg_display_name
force=$_arg_force

default_chrome_desktop=/usr/share/applications/google-chrome.desktop
if [ ! -f "$default_chrome_desktop" ]; then
  echo "Could not find the file $default_chrome_desktop. Are you sure that Google Chrome is installed?"
  exit 1
fi

safe_display_name=${display_name,,}         # Make lowercase
safe_display_name=${safe_display_name// /-} # Replace spaces with dashes
user_data_dir_name="google-chrome-$safe_display_name"
user_data_dir="$HOME/.config/$user_data_dir_name"
shortcut="$HOME/.local/share/applications/$user_data_dir_name.desktop"

echo
echo "We will:"
echo "  - Create the file '$shortcut'"
echo "  - Use '$display_name' as the display name"
echo "  - Use '$user_data_dir' as the user data directory"
echo
if [ "$force" = off ]; then
  read -p "Do you confirm? (Yy)" -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

## Create the shortcut
cp -f $default_chrome_desktop "$shortcut"
chrome_name="Google Chrome"
sed -i "s:Name=$chrome_name:Name=$chrome_name ($display_name):g" "$shortcut"
chrome_binary="/usr/bin/google-chrome-stable"
sed -i "s:Exec=$chrome_binary:Exec=$chrome_binary --class=$user_data_dir_name --user-data-dir=$user_data_dir:g" "$shortcut" # The //\//\\/ is used to escape forward slashes

echo
echo "All done. To uninstall, run:"
echo "  $ rm -f $shortcut"
echo

# ] <-- needed because of Argbash
