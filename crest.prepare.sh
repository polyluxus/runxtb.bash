#!/bin/bash

###
#
# crest.prepare.sh --
#   a script to copy files needed for CREST into a new directory
# Copyright (C) 2019 - 2024  Martin C Schwarzer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
###

#hlp ===== Not Part of xTB =====
#hlp DESCRIPTION:
#hlp   This is a little helper script to set up a crest (via xTB) calculation.
#hlp
#hlp   It basically creates a directory (optional) with a molecular
#hlp   structure in turbomole format called 'coord'.
#hlp   Script requires Open Babel.
#hlp
#hlp LICENSE:
#hlp   crest.prepare.sh  Copyright (C) 2019 - 2024  Martin C Schwarzer
#hlp   This program comes with ABSOLUTELY NO WARRANTY; this is free software,
#hlp   and you are welcome to redistribute it under certain conditions;
#hlp   please see the license file distributed alongside this repository,
#hlp   which is available when you type '${0##*/} license',
#hlp   or at <https://github.com/polyluxus/runxtb.bash>.
#hlp
#hlp USAGE:
#hlp   ${0##*/} [script options]
#hlp 

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.
#

message ()
{
  if (( stay_quiet <= 0 )) ; then
    echo "INFO   : $*" >&3
  else
    debug "(info   ) $*"
  fi
}

warning ()
{
  if (( stay_quiet <= 1 )) ; then
    echo "WARNING: $*" >&2
  else
    debug "(warning) $*"
  fi
  return 1
}

fatal ()
{
  exit_status=1
  if (( stay_quiet <= 2 )) ; then
    echo "ERROR  : $*" >&2
  else
    debug "(error  ) $*"
  fi
  exit "$exit_status"
}

debug ()
{
  # Include the fuction that called the debug statement (hence index 1, as 0 would be the debug function itself)
  local line
  while read -r line || [[ -n "$line" ]] ; do
    echo "DEBUG  : (${FUNCNAME[1]}) $line" >&4
  done <<< "$*"
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

backup_if_exists ()
{
  local move_source="$1"
  # File does not exist, then everithing is fine, return with status 0
  [[ -f "$move_source" ]] || return 0
  # File exists, print a warning
  warning "File '$move_source' already exists."
  # make a backup
  # (test default name first, if that exists, relegate to tool)
  local move_target="${move_source}.bak"
  [[ -f "$move_target" ]] && move_target=$( mktemp "${move_target}.XXXX" )
  # if moving failed for whatever reason, return with status 1
  message "Create backup: $( mv -v -- "$move_source" "$move_target" 2>&1 )" || return 1
}

# Auxiliary function to do what the bash usually does by itself
expand_tilde_path ()
{
  local test_string="$1" return_string
  # Tilde does not expand like a variable, this might lead to files not being found
  # The regex is trying to exclude special meanings of '~+' and '~-'
  if [[ $test_string =~ ^~([^/+-]*)/(.*)$ ]] ; then
    debug "Expandinging tilde, match: ${BASH_REMATCH[0]}"
    if [[ -z ${BASH_REMATCH[1]} ]] ; then
      # If the tilde is followed by a slash it expands to the users home
      return_string="$HOME/${BASH_REMATCH[2]}"
    else
      # If the tilde is followed by a string, it expands to another user's home
      return_string="/home/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    debug "Expanded tilde to '$return_string'."
  else
    return_string="$test_string"
  fi
  echo "$return_string"
}

# Resolve the directory where the script is located (necessary to load rc and aux files)
get_bindir ()
{
  # Resolves the absolute location of parameter and returns it
  # partially taken from https://stackoverflow.com/a/246128/3180795
  local resolve_file="$1" description="$2" 
  local link_target directory_name resolve_dir_name
  debug "Getting directory for '$resolve_file'."
  resolve_file=$( expand_tilde_path "$resolve_file" )

  # resolve $resolve_file until it is no longer a symlink
  while [[ -h "$resolve_file" ]] ; do 
    link_target="$( readlink "$resolve_file" )"
    if [[ $link_target == /* ]]; then
      debug "File '$resolve_file' is an absolute symlink to '$link_target'"
      resolve_file="$link_target"
    else
      directory_name="$( dirname "$resolve_file" )" 
      debug "File '$resolve_file' is a relative symlink to '$link_target' (relative to '$directory_name')"
      #  If $resolve_file was a relative symlink, we need to resolve 
      #+ it relative to the path where the symlink file was located
      resolve_file="$directory_name/$link_target"
    fi
  done
  debug "File is '$resolve_file'"
  resolve_dir_name="$( dirname "$resolve_file")"
  directory_name="$( cd -P "$( dirname "$resolve_file" )" && pwd )"
  if [[ "$directory_name" != "$resolve_dir_name" ]] ; then
    debug "$description '$directory_name' resolves to '$directory_name'"
  fi
  debug "$description is '$directory_name'"
  if [[ -z $directory_name ]] ; then
    echo "."
  else
    echo "$directory_name"
  fi
}

#
# Get settings from configuration file
#

test_rc_file ()
{
  local test_runxtbrc="$1"
  debug "Testing '$test_runxtbrc' ..."
  if [[ -f "$test_runxtbrc" && -r "$test_runxtbrc" ]] ; then
    echo "$test_runxtbrc"
    return 0
  else
    debug "... missing."
    return 1
  fi
}

get_rc ()
{
  local test_runxtbrc_dir test_runxtbrc_loc return_runxtbrc_loc
  while [[ -n $1 ]] ; do
    test_runxtbrc_dir="$1"
    shift
    if test_runxtbrc_loc="$( test_rc_file "$test_runxtbrc_dir/.runxtbrc" )" ; then
      return_runxtbrc_loc="$test_runxtbrc_loc" 
      debug "   (found) return_runxtbrc_loc=$return_runxtbrc_loc"
      continue
    elif test_runxtbrc_loc="$( test_rc_file "$test_runxtbrc_dir/runxtb.rc" )" ; then 
      return_runxtbrc_loc="$test_runxtbrc_loc"
      debug "   (found) return_runxtbrc_loc=$return_runxtbrc_loc"
      continue
    fi
  done
  debug "(returned) return_runxtbrc_loc=$return_runxtbrc_loc"
  echo "$return_runxtbrc_loc"
}

# OpenBabel helper function

convert_xyz_to_coord ()
{
  # Convert the coordinates from xmol to tmol format with Open Babel
  # Usage: function source target
  (( $# == 2 )) || fatal "Wrong call of function. Raise an issue!."
  # Check for the dependency, allow for it to be set in the rc settings
  # This could or should come from the configuration, if it doesn't, use the default
  obabel_cmd="${obabel_cmd:-obabel}"
  obabel_cmd_found="$( command -v "$obabel_cmd" )" || fatal "Command not found: $obabel_cmd"
  local source_file="$1"
  local target_file="$2"
  backup_if_exists "$target_file"
  message "$( "$obabel_cmd_found" -ixyz "$source_file" -oTmol -O"$target_file" 2>&1 )" || fatal "Failure in Open Babel."
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

# Default verbosity
stay_quiet="0"

#
# Details about this script to be read from external files
#

# Where this script is located:
scriptpath="$( get_bindir "$0" "Directory of runxtb" )"
# there should be a file with versioning information
# shellcheck source=./VERSION
[[ -r "$scriptpath/VERSION" ]] && . "$scriptpath/VERSION"
version="${version:-unspecified}"
versiondate="${versiondate:-unspecified}"
debug "Version ${version} from ${versiondate}."

if [[ "$1" =~ ^[Ll][Ii][Cc][Ee][Nn][Ss][Ee]$ ]] ; then
  [[ -r "$scriptpath/LICENSE" ]] || fatal "No license file found. Your copy of the repository might be corrupted."
  if command -v less &> /dev/null ; then
    less "$scriptpath/LICENSE"
  else
    cat "$scriptpath/LICENSE"
  fi
  message "Displayed license and will exit."
  exit 0
fi

runxtbrc_loc="$(get_rc "$scriptpath" "/home/$USER" "/home/$USER/.config/" "$PWD")"
debug "runxtbrc_loc=$runxtbrc_loc"

if [[ -n $runxtbrc_loc ]] ; then
  # shellcheck source=./runxtb.rc
  . "$runxtbrc_loc"
  message "Configuration file '$runxtbrc_loc' applied."
else
  debug "No configuration file found."
fi


# Initialise Variables
OPTIND=1

while getopts :d:cqh options ; do
  case $options in
    #hlp OPTIONS:
    #hlp 
    #hlp   -d <ARG> Use <ARG> as directory name to set up. [Default: crest]
    #hlp            If <ARG> is '.', then skip creating a directory,
    #hlp            instead convert a found '*.xyz' to 'coord', or
    #hlp            rename existing 'xtbopt.coord' to 'coord'.
    d) 
      crest_dir="$OPTARG"
      ;;
    #hlp   -c       Create a 'coord' file. [Default: no]
    #hlp            This requires openbabel to be installed.
    c)
      use_openbabel="yes"
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

# Set a default target, if none was provided
crest_dir="${crest_dir:-crest}"
debug "Target is: $crest_dir"
# Strip trailing slash
crest_dir="${crest_dir%/}"
if [[  "$crest_dir" != '.' ]] ; then
  # If the directory is not pwd, then check if it exists (as existing directories cannot be created)
  if [[ -e "$crest_dir" ]] ; then
    debug "It exists: $crest_dir"
    if try_to_delete=$( rmdir -v -- "$crest_dir" 2>&1 ) ; then
      debug "Deletion of directory: $try_to_delete"
    else
      debug "Deletion failed. Message(s):"
      debug "$try_to_delete"
      warning "Directory exists and cannot be deleted: $crest_dir"
      fatal "Cannot recover; please check the directory manually."
    fi
  fi
  message "$( mkdir -v -- "$crest_dir" )" || fatal "Failed to create '$crest_dir'."
else
  # The pwd is the target directory, treat it like a newly created one
  debug "Target directory is '$crest_dir'."
fi

# Check for structure files
if [[ -r "xtbopt.xyz" ]] ; then
  # Ideally copy optimised structure information to crest-directory, set the filename:
  structure_file_name="xtbopt.xyz"
  debug "Structurefile is readable: $structure_file_name"
  # Copy the new structure file to the crest directory (it is no longer necessary to be named coord, but that is still the default)
  # Maybe get rid of the obabel dependency in the process or make it optional
  if [[ "$use_openbabel" =~ [Yy][Ee][Ss] ]] ; then
    convert_xyz_to_coord "$structure_file_name" "$crest_dir/coord"
  else
    message "$( cp -v -- "$structure_file_name" "$crest_dir" )"
  fi
elif [[ -r "xtbopt.coord" ]] ; then
  # Copy the found optimised structure (in tmol format) to the crest directory
  message "Found optimised molecular structure in Turbomole format."
  backup_if_exists "$crest_dir/coord"
  message "$( cp -v -- "xtbopt.coord" "$crest_dir/coord" )"
  # Nothing further needs to be done
else
  warning "No optimised molecular structure found in current directory."
  # Look for other structure files
  for structure_file in "coord" *.coord *.xyz ; do
    if [[ -r "$structure_file" ]] ; then
      message "Found '$structure_file' and will use this molecular structure instead."
      message "It is recommended to preoptimise the molecular structure with xtb at the same level"
      message "as the conformational search with crest shall be conducted, as it will be used as a reference for sanity checks."
      if [[ "${structure_file##*.}" == "coord" ]] ; then
        # Assume that a file ending on coord is in the right format already, just try to copy
        if copied_structure_file="$( cp -v -- "$structure_file" "$crest_dir/coord" 2>&1 )" ; then
          message "$copied_structure_file"
          break
        else
          debug "$copied_structure_file"
          fatal "Copying the structure data file failed."
        fi
      else
        # Use thes first file to consider
        if [[ "$use_openbabel" == "yes" ]] ; then
          convert_xyz_to_coord "$structure_file" "$crest_dir/coord"
        else
          message "$( cp -v -- "$structure_file_name" "$crest_dir" )"
        fi
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
message "All Done: ${0##*/} (part of runxtb.bash $version, $versiondate)"

#hlp
#hlp This script is part of runxtb.bash ($version, $versiondate).
