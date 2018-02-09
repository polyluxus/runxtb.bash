#!/bin/bash

#hlp ===== Not Part of xTB =====
#hlp This is a little helper script to use xTB from
#hlp https://www.chemie.uni-bonn.de/pctc/mulliken-center/software/xtb/xtb
#hlp without making changes to any local setting files like
#hlp '.bashrc', '.profile', etc.
#hlp  

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.
#

message ()
{
    (( stay_quiet <= 0 )) && echo "INFO   : " "$*" >&3
}

indent ()
{
    (( stay_quiet <= 0 )) && echo -n "INFO   : " "$*" >&3
}

warning ()
{
    (( stay_quiet <= 1 )) && echo "WARNING: " "$*" >&2
    return 1
}

fatal ()
{
    (( stay_quiet <= 2 )) && echo "ERROR  : " "$*" >&2
    exit 1
}

#
# Print some helping commands
# The lines are distributed throughout the script and grepped for
#

helpme ()
{
    local line
    local pattern="^[[:space:]]*#hlp[[:space:]](.*$)"
    while read -r line; do
      [[ $line =~ $pattern ]] && eval "echo \"${BASH_REMATCH[1]}\""
    done < <(grep "#hlp" "$0")
    exit 0
}

get_bindir ()
{
#  Taken from https://stackoverflow.com/a/246128/3180795
  local resolve_file="$1" directory_name="$2" link_target DIR RDIR
  message "Getting directory for '$resolve_file'."
  #  resolve $resolve_file until it is no longer a symlink
  while [ -h "$resolve_file" ]; do 
    TARGET="$(readlink "$resolve_file")"
    if [[ $link_target == /* ]]; then
      message "File '$resolve_file' is an absolute symlink to '$link_target'"
      resolve_file="$link_target"
    else
      DIR="$( dirname "$resolve_file" )" 
      message "File '$resolve_file' is a relative symlink to '$link_target' (relative to '$DIR')"
      #  If $SOURCE was a relative symlink, we need to resolve 
      #+ it relative to the path where the symlink file was located
      resolve_file="$DIR/$link_target"
    fi
  done
  message "File is '$resolve_file'" 
  RDIR="$( dirname "$resolve_file")"
  DIR="$( cd -P "$( dirname "$resolve_file" )" && pwd )"
  if [ "$DIR" != "$RDIR" ]; then
    message "$directory_name '$DIR' resolves to '$DIR'"
  fi
  message "$directory_name is '$DIR'"
  if [[ -z $DIR ]] ; then
    echo "."
  else
    echo "$DIR"
  fi
}

#
# Test if a given value is an integer
#

is_integer()
{
    [[ $1 =~ ^[[:digit:]]+$ ]]
}

validate_integer ()
{
    if ! is_integer "$1"; then
        [ ! -z "$2" ] && fatal "Value for $2 ($1) is no integer."
          [ -z "$2" ] && fatal "Value '$1' is no integer."
    fi
}

# 
# Test and add to PATH
#

check_program_or_exit ()
{
    if [[ -f "$1" && -x "$1" ]] ; then
      message "Found programm '$1'."
    else
      warning "Programm '$1' does not seem to exist or is not executable."
      warning "The script might not have been set up properly."
      fatal   "Cannot continue."
    fi
}    

add_to_PATH ()
{
    [[ -d "$1" ]] || fatal "Cowardly refuse to add non-existent directory to PATH."
    [[ -x "$1" ]] || fatal "Cowardly refuse to add non-accessible directory to PATH."
    [[ :$PATH: =~ :$1: ]] || PATH="$PATH:$1"
}

print_info ()
{
    message "Setting OMP_NUM_THREADS=$OMP_NUM_THREADS."
    message "Setting MKL_NUM_THREADS=$MKL_NUM_THREADS."
    message "Setting OMP_STACKSIZE=$OMP_STACKSIZE."
    message "Setting XTBHOME=$XTBHOME."
}

#
# Check if file exists and prevent overwriting
#

backup_if_exists ()
{
    if [[ -e "$1" ]]; then
      local filecount=1
      while [[ -e "$1.$filecount" ]]; do
          ((filecount++))
      done
      warning "File '$1' exists, will make backup."
      indent "  "
      if (( stay_quiet <= 0 )) ; then  
        mv -v "$1" "$1.$filecount"
      else
        mv "$1" "$1.$filecount"
      fi
    fi
}

#
# Start main script
#


# Sent logging information to stdout
exec 3>&1

# Defaults
OMP_NUM_THREADS=4
MKL_NUM_THREADS=4
OMP_STACKSIZE=1000m
xtb_callname="xtb"

stay_quiet=1        # Suppress logging messages for finding the script   
[[ "$1" == "debug" ]] && stay_quiet=0 && shift # Secret debugging switch

scriptpath="$(get_bindir "$0" "Directory of runxtb")"
runxtbrc="$scriptpath/.runxtbrc"

stay_quiet=0        # Reset to default logging

if [[ -f "$runxtbrc" && -r "$runxtbrc" ]] ; then
  . "$runxtbrc"
  message "Applied configuration file settings."
fi

OPTIND=1

while getopts :p:m:o:B:qh options ; do
  case $options in
    #hlp OPTIONS:
    #hlp   -p <ARG> Set number of professors
    p) validate_integer "$OPTARG"
       OMP_NUM_THREADS="$OPTARG"
       MKL_NUM_THREADS="$OPTARG"
       ;;
    #hlp   -m <ARG> Set the number of memories (in megabyte?)
    m) validate_integer "$OPTARG"
       OMP_STACKSIZE="${OPTARG}m"
       ;;
    #hlp   -o <ARG> Trap the output into a file called <ARG>.
    o) output_file="$OPTARG"
       ;;
    #hlp   -B <ARG> Set absolute path to xtb to <ARG>.
    B) XTBHOME="$(get_bindir "$OPTARG" "XTBHOME")"
       xtb_callname="${OPTARG##*/}"
       ;;

    #hlp   -q       Stay quiet! (Only this startup script)
    #hlp            May be specified multiple times to be more forceful.
    q) (( stay_quiet++ )) 
       ;;
    #hlp   -h       Prints this help text
    h) helpme ;;

   \?) fatal "Invalid option: -$OPTARG." ;;

    :) fatal "Option -$OPTARG requires an argument." ;;

  esac
done

shift $(( OPTIND - 1 ))

# Before proceeding, print a warning, that this is  N O T  the real program.
warning "This is not the original xtb program!"
warning "this is only a wrapper to set paths and variables."

# If not set explicitly, assume xtb is in same directory as script
[[ -z $XTBHOME ]] && XTBHOME="$scriptpath"

check_program_or_exit "$XTBHOME/$xtb_callname"
add_to_PATH "$XTBHOME"
export XTBHOME OMP_NUM_THREADS MKL_NUM_THREADS OMP_STACKSIZE

print_info

if [[ -z $output_file ]] ; then 
  $xtb_callname "$@" 
  exit $? # Carry over exit status
else
  backup_if_exists "$output_file"
  $xtb_callname "$@" > "$output_file"
fi


exec 3>&-
#hlp ===== End of Script ===== (Martin, 2018/02/09)
