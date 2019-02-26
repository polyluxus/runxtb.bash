#!/bin/bash
#hlp ===== Not Part of xTB =====
#hlp DESCRIPTION:
#hlp   This is a little helper script to set up a crest (via xTB) calculation.
#hlp   
#hlp   It basically creates a directory (optional) with a molecular 
#hlp   structure in turbomole format called 'coord'.
#hlp   Script requires Open Babel.
#hlp  
#hlp USAGE:
#hlp   ${0##*} [script options] 
#hlp 

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.
#

message ()
{
    if (( stay_quiet <= 0 )) ; then
      echo "INFO   : " "$*" >&3
    else
      debug "(info   ) " "$*"
    fi
}

warning ()
{
    if (( stay_quiet <= 1 )) ; then
      echo "WARNING: " "$*" >&2
    else
      debug "(warning) " "$*"
    fi
    return 1
}

fatal ()
{
    exit_status=1
    if (( stay_quiet <= 2 )) ; then 
      echo "ERROR  : " "$*" >&2
    else
      debug "(error  ) " "$*"
    fi
    exit "$exit_status"
}

debug ()
{
  echo "DEBUG  : (${FUNCNAME[1]})" "$*" >&4
}    

#
# Print some helping commands
# The lines are distributed throughout the script and grepped for
#

helpme ()
{
    local line
    local pattern="^[[:space:]]*#hlp[[:space:]]?(.*)?$"
    while read -r line; do
      [[ "$line" =~ $pattern ]] && eval "echo \"${BASH_REMATCH[1]}\""
    done < <(grep "#hlp" "$0")
    exit 0
}

###
#
# MAIN
#
###

exec 3>&1

if [[ "$1" == "debug" ]] ; then
  # Secret debugging switch
  exec 4>&1
  shift 
else
  exec 4> /dev/null
fi


# Initialise Variables
stay_quiet="0"
OPTIND=1

while getopts :d:qh options ; do
  case $options in
    #hlp OPTIONS:
    #hlp 
    #hlp   -d <ARG> Use <ARG> as directory name to set up.
    d) 
      crest_dir="$OPTARG"
      ;;
    #hlp   -q       Stay quiet! (Only this startup script)
    #hlp            May be specified multiple times to be more forceful.
    q) 
      (( stay_quiet++ )) 
      ;;
    #hlp   -h       Prints this help text
    h) 
      helpme 
      ;;
    \?) 
      fatal "Invalid option: -$OPTARG." 
      ;;
    :) 
      fatal "Option -$OPTARG requires an argument." 
      ;;

  esac
done

crest_dir="${crest_dir:-crest}"
[[ -d "$crest_dir" ]] && fatal "Directory exists: $crest_dir"
message "$( mkdir -v -- "$crest_dir" )" || fatal "Failed to create '$crest_dir'."

if [[ -r "xtbopt.xyz" ]] ; then
  obabel_cmd="$( command -v obabel )" || fatal "Command not found: obabel"
  message "$( "$obabel_cmd" -ixyz "xtbopt.xyz" -oTmol -O"$crest_dir/coord" )"
elif [[ -r "xtbopt.coord" ]] ; then
  message "Found optimised molecular structure in turbomole format."
  message "$( cp -v -- "xtbopt.coord" "$crest_dir/coord" )"
else
  warning "No optimised molecular structure found in current directory."
  for structure_file in "coord" *.xyz ; do
    if [[ -r "$structure_file" ]] ; then
      message "Will use molecular structure in '$structure_file' instead."
      if [[ "$structure_file" == "coord" ]] ; then
        message "$( cp -v -- "$structure_file" "$crest_dir/coord" )"
        break
      else
        obabel_cmd="$( command -v obabel )" || fatal "Command not found: obabel"
        message "$( "$obabel_cmd" -ixyz "xtbopt.xyz" -oTmol -O"$crest_dir/coord" )"
        break
      fi
    fi
  done
fi

if [[ -r ".UHF" ]] ; then
  message "$( cp -v -- ".UHF" "$crest_dir/.UHF" )"
fi

if [[ -r ".CHRG" ]] ; then
  message "$( cp -v -- ".CHRG" "$crest_dir/.CHRG" )"
fi

debug "Content of created directory: $( ls -lah "$crest_dir" )"
message "All Done: ${0##*/}."

