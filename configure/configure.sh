#!/bin/bash

###
#
# Tis configuration script is part of 
# runxtb.bash -- 
#   a repository to set the environment for the xtb program
# Copyright (C) 2019 - 2020 Martin C Schwarzer
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

# This script should be used to configure runxtb.sh

#
# Messaging functions
#

message ()
{
    echo    "INFO    : $*" >&3
}

warning ()
{
    echo    "WARNING:  $*" >&2
    return 1
}

fatal ()
{
    echo    "ERROR  :  $*" >&2
    exit 1
}

debug ()
{
    echo    "DEBUG   : $*" >&4
}    

ask ()
{
    echo    "Question: $*" >&3
}

# 
# Support functions
#

backup_if_exists ()
{
  if [[ -e "$1" ]]; then
    local filecount=1
    while [[ -e "$1.$filecount" ]]; do
      ((filecount++))
    done
    warning "File '$1' exists, will make backup."
    local move_message
    move_message="$(mv -v "$1" "$1.$filecount")"
    message "$move_message"
  fi
}

expand_tilde ()
{
  local expand_string="$1" return_string
  # Tilde does not expand like a variable, this might lead to files not being found
  # The regex is trying to exclude special meanings of '~+' and '~-'
  if [[ $expand_string =~ ^~([^/+-]*)/(.*)$ ]] ; then
    debug "Expandinging tilde, match: ${BASH_REMATCH[0]}"
    if [[ -z ${BASH_REMATCH[1]} ]] ; then
      # If the tilde is followed by a slash it expands to the users home
      return_string="$HOME/${BASH_REMATCH[2]}"
    else
      # If the tilde is followed by a string, it expands to another user's home
      return_string="/home/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    debug "Expanded tilde for '$return_string'."
  else
    return_string="$expand_string"
  fi
  echo "$return_string"
}
  
check_exist_executable ()
{
  local resolve_file="$1"
  if [[ -e "$resolve_file" && -x "$resolve_file" ]] ; then
    debug "Found file and is executable."
  else
    warning "File '$resolve_file' does not exist or is not executable."
    return 1
  fi
}

get_bindir ()
{
#  Taken from https://stackoverflow.com/a/246128/3180795
  local resolve_file="$1" description="$2" link_target directory_name resolve_dir_name
  debug "Getting directory for '$resolve_file'."
  
  #  resolve $resolve_file until it is no longer a symlink
  while [ -h "$resolve_file" ]; do 
    link_target="$(readlink "$resolve_file")"
    if [[ $link_target == /* ]]; then
      debug "File '$resolve_file' is an absolute symlink to '$link_target'"
      resolve_file="$link_target"
    else
      directory_name="$( dirname "$resolve_file" )" 
      debug "File '$resolve_file' is a relative symlink to '$link_target' (relative to '$directory_name')"
      #  If $SOURCE was a relative symlink, we need to resolve 
      #+ it relative to the path where the symlink file was located
      resolve_file="$directory_name/$link_target"
    fi
  done
  debug "File is '$resolve_file'" 
  resolve_dir_name="$( dirname "$resolve_file")"
  directory_name="$( cd -P "$( dirname "$resolve_file" )" && pwd )"
  if [ "$directory_name" != "$resolve_dir_name" ]; then
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
# Recover from previous files
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
  while [[ ! -z $1 ]] ; do
    test_runxtbrc_dir="$1"
    shift
    if test_runxtbrc_loc="$(test_rc_file "$test_runxtbrc_dir/.runxtbrc")" ; then
      return_runxtbrc_loc="$test_runxtbrc_loc" 
      debug "   (found) return_runxtbrc_loc=$return_runxtbrc_loc"
      continue
    elif test_runxtbrc_loc="$(test_rc_file "$test_runxtbrc_dir/runxtb.rc")" ; then 
      return_runxtbrc_loc="$test_runxtbrc_loc"
      debug "   (found) return_runxtbrc_loc=$return_runxtbrc_loc"
    fi
  done
  debug "(returned) return_runxtbrc_loc=$return_runxtbrc_loc"
  echo "$return_runxtbrc_loc"
}

recover_rc ()
{
  local runxtbrc_loc
  # Guess some locations where a rc file could be located
  runxtbrc_loc="$(get_rc "$scriptpath" "$runxtbrc_path" "/home/$USER" "/home/$USER/.config/" "$PWD")"
  debug "runxtbrc_loc=$runxtbrc_loc"
  
  if [[ ! -z $runxtbrc_loc ]] ; then
    # shellcheck source=/home/te768755/devel/runxtb.bash/runxtb.rc
    . "$runxtbrc_loc"
    message "Configuration file '$runxtbrc_loc' applied."
    ask "Would you like to specify a different file?"
    if read_boolean ; then
      ask "What file would you like to load?"
      runxtbrc_loc=$(read_human_input)
      if runxtbrc_loc=$(test_rc_file "$runxtbrc_loc") ; then
        # shellcheck source=/home/te768755/devel/runxtb.bash/runxtb.rc
        . "$runxtbrc_loc"
        message "Configuration file '$runxtbrc_loc' applied."
        message "If some values were not set in this file,"
        message "the previously loaded values have not been replaced."
      else
        warning "Loading configuration file '$runxtbrc_loc' failed."
        message "Continue with previously recovered settings."
      fi
    fi
  else
    debug "No configuration file in standard locations found."
    ask "Would you like to specify a file to try to recover previous settings from?"
    if read_boolean ; then
      ask "What file would you like to load?"
      runxtbrc_loc=$(read_human_input)
      if runxtbrc_loc=$(test_rc_file "$runxtbrc_loc") ; then
        # shellcheck source=/home/te768755/devel/runxtb.bash/runxtb.rc
        . "$runxtbrc_loc"
        message "Configuration file '$runxtbrc_loc' applied."
      else
        warning "Loading configuration file failed."
        return 1
      fi
    else
      return 1
    fi
    return 1
  fi

  use_threads="$requested_numCPU"
  if [[ -z $use_threads ]] ; then
    ask_threads
  else
    message "Recovered setting 'requested_numCPU=$use_threads'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_threads ; fi
  fi
  debug "use_threads=$use_threads"
     
  use_memory="$requested_memory"
  if [[ -z $use_memory ]] ; then
    ask_memory
  else
    message "Recovered setting 'requested_memory=$use_memory'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_memory ; fi
  fi
  debug "use_memory=$use_memory"

  use_xtbhome="$xtb_install_root"
  use_xtbname="$xtb_callname"
  if [[ -z $use_xtbhome || -z $use_xtbname ]] ; then
    ask_installation_path
  else
    message "Recovered setting 'xtb_install_root=$use_xtbhome' and"
    message "recovered setting 'xtb_callname=$use_xtbname'."
    ask "Would you like to change these settings?"
    if read_boolean ; then ask_installation_path ; fi
  fi
  debug "use_xtbhome=$use_xtbhome; use_xtbname=$use_xtbname"
  if [[ -z $use_xtbname ]] ; then 
    ask_callname
  else
    message "recovered setting 'xtb_callname=$use_xtbname'."
    ask "Would you like to change these settings?"
    if read_boolean ; then ask_callname ; fi
  fi

  use_chatty="$stay_quiet"
  if [[ -z $use_chatty ]] ; then
    ask_chattyness
  else
    message "Recovered verbosity setting 'stay_quiet=$use_chatty'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_chattyness ; fi
  fi
  debug "use_chatty=$use_chatty"

  use_outputfile_name="$output_file"
  if [[ -z $use_outputfile_name ]] ; then
    ask_files
  else
    message "Recovered default output setting 'output_file=$use_outputfile_name'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_files ; fi
  fi
  debug "use_outputfile_name=$use_outputfile_name"

  use_interactivity="$run_interactive"
  if [[ -z $use_interactivity ]] ; then
    ask_interactivity
  else
    message "Recovered interactivity setting 'run_interactive=$use_interactivity'."
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_interactivity ; fi
  fi
  debug "use_interactivity=$use_interactivity"

  use_queue="$request_qsys"
  # Try to recover old vrsion where it was bsub_project
  use_qsys_project="${qsys_project:-$bsub_project}"
  if [[ -z $use_queue ]] ; then
    ask_qsys_details
  else
    message "Recovered queueing system setting 'request_qsys=$use_queue'."
    if [[ -n $use_qsys_project ]] ; then 
      message "Recovered project setting 'qsys_project=$use_qsys_project'."
      ask "Would you like to change these settings?"
    else
      ask "Would you like to change this setting?"
    fi
    if read_boolean ; then ask_qsys_details ; fi
  fi
  debug "use_queue=$use_queue; use_qsys_project=$use_qsys_project"

  use_module_system="$use_modules"
  use_module_items=( "${load_modules[@]}" )
  if [[ -z $use_modules ]] ; then
    ask_modules
  else
    message "Recovered module setting 'use_modules=$use_module_system'."
    if (( ${#use_module_items[@]} > 0 )) ; then
      message "Recovered the use of the following modules:"
      local module_index=0
      while (( module_index < ${#use_module_items[@]} )) ; do
        message "   load_modules[$module_index]=\"${use_module_items[$module_index]}\""
        (( module_index++ ))
      done
    fi
    ask "Would you like to change these settings?"
    if read_boolean ; then ask_modules ; fi
  fi
  debug "use_module_system=$use_module_system"
  debug "use_module_items=(${use_module_items[*]})"

  use_walltime="$requested_walltime"
  if [[ -z $use_walltime ]] ; then
    ask_walltime
  else
    message "Recovered setting 'requested_walltime=$use_walltime'"
    ask "Would you like to change this setting?"
    if read_boolean ; then ask_walltime ; fi
  fi
  debug "use_threads=$use_walltime"
  
  return 0
}

#
# Input functions
#

read_human_input ()
{
  debug "Reading human input."
  message "Enter '0' to skip or exit this section."
  local readvar
  while [[ -z $readvar ]] ; do
    echo -n "Answer  : " >&3
    read -r readvar
    [[ "$readvar" == 0 ]] && unset readvar && break 
  done
  debug "readvar=$readvar"
  echo "$readvar"
}

read_boolean ()
{
  debug "Reading boolean."
  local readvar pattern_true_false pattern_yes_no pattern
  pattern_true_false="[Tt]([Rr]([Uu][Ee]?)?)?|[Ff]([Aa]([Ll]([Ss][Ee]?)?)?)?"
  pattern_yes_no="[Yy]([Ee][Ss]?)?|[Nn][Oo]?"
  pattern="($pattern_true_false|$pattern_yes_no|0|1)"
  until [[ $readvar =~ ^[[:space:]]*${pattern}[[:space:]]*$ ]] ; do
    message "Please enter t(rue)/y(es)/1 or f(alse)/n(o)/0."
    echo -n "Answer  : " >&3
    read -r readvar
  done
  debug "Found match '${BASH_REMATCH[0]}'"
  case ${BASH_REMATCH[0]} in
    [Tt]* | [Yy]* | 1) return 0 ;;
    [Ff]* | [Nn]* | 0) return 1 ;;
  esac
}

read_true_false ()
{
  if read_boolean ; then
    echo "true"
  else
    echo "false"
  fi
}

read_yes_no ()
{
  if read_boolean ; then
    echo "yes"
  else
    echo "no"
  fi
}

read_integer ()
{
  debug "Reading integer."
  local readvar
  until [[ $readvar =~ ^[[:space:]]*([[:digit:]]+)[[:space:]]*$ ]] ; do
    message "Please enter an integer value."
    echo -n "Answer  : " >&3
    read -r readvar
  done
  debug "Whole match is |${BASH_REMATCH[0]}|; Numeric is |${BASH_REMATCH[1]}|"
  readvar="${BASH_REMATCH[1]}"
  debug "readvar=$readvar"
  echo "$readvar"
}

#
# Configure functions
#

ask_installation_path ()
{
  ask "Where is the xtb executable? Please specify the full path."
  use_xtbpath=$(read_human_input)
  # Will be empty if skipped; can return without assigning/testing empty values
  [[ -z $use_xtbpath ]] && return
  debug "use_xtbpath=$use_xtbpath"
  use_xtbpath="$(expand_tilde "$use_xtbpath")"
  if check_exist_executable "$use_xtbpath" ; then
    use_xtbhome=$(get_bindir "$use_xtbpath" "XTB bin directory") && use_xtbname=${use_xtbpath##*/}
    use_xtbhome="${use_xtbhome%/bin}"
  else
    warning "Problem locating executable, unsetting variable."
    unset use_xtbpath use_xtbhome
  fi
  debug "use_xtbhome=$use_xtbhome"
  debug "use_xtbname=$use_xtbname"
}

ask_callname ()
{
  ask "What is the name of the xtb binary?"
  use_xtbname="$(read_human_input)"
  debug "use_xtbname=$use_xtbname"
}

ask_modules ()
{
  ask "If a modular cluster management is available, do you want to use it?"
  use_module_system=$(read_true_false)
  debug "use_module_system=$use_module_system"
  if [[ "$use_module_system" =~ ^[Tt]([Rr]([Uu]([Ee])?)?)?$ ]] ; then
    if ( command -v module &> /dev/null ) ; then
      debug "Command 'module' is available."
    else
      warnung "Command 'module' appears not to be available; continue anyway."
      # Something like this was included, but is not really necessary
      # use_module_system="false"
      # warning "Switching the use of modules off."
    fi
    # Unsetting read in module
    unset use_module_items
    local module_index=0
    while [[ -z ${use_module_items[$module_index]} ]] ; do
      debug "Reading use_module_items[$module_index]"
      ask "What modules do need to be loaded?"
      use_module_items[$module_index]=$(read_human_input)
      debug "use_module_items[$module_index]=${use_module_items[$module_index]}"
      if [[ ${use_module_items[$module_index]} =~ ^[[:space:]]*$ ]] ; then 
        debug "Finished reading modules."
        unset 'use_module_items[module_index]'
        break
      fi
      (( module_index++ ))
    done
    debug "Number of elements: ${#use_module_items[@]}"
    if (( ${#use_module_items[@]} == 0 )) ; then
      warning "No modules specified."
      use_module_system="false"
      warning "Switching the use of modules off."
    fi
  else
    debug "No modules used."
  fi
}

ask_interactivity ()
{
  ask "Would you like your standard operation to be interactive?"
  use_interactivity=$(read_yes_no)
  debug "use_interactivity=$use_interactivity"
  if [[ $use_interactivity =~ [Nn][Oo]? ]] ; then
    ask "Would you like to automatically submit to the queueing system?"
    read_boolean && use_interactivity="sub"
    debug "use_interactivity=$use_interactivity"
  fi

  ask "What queueing system would you like to use?"
}

ask_qsys_details ()
{
  message "Currently supported: pbs-gen, bsub-gen, slurm-gen, bsub-rwth, slurm-rwth"
  local test_queue
  test_queue=$(read_human_input)
  debug "test_queue=$test_queue"
  case $test_queue in
    [Pp][Bb][Ss]* ) 
      use_queue="pbs-gen"
      ;;
    [Bb][Ss][Uu][Bb]* )
      use_queue="bsub-gen"
      ask "What project would you like to specify?"
      use_qsys_project=$(read_human_input)
      debug "use_qsys_project=$use_qsys_project"
      ;;&
    [Ss][Ll][Uu][Rr][Mm]* )
      use_queue="slurm-gen"
      ask "What project would you like to specify?"
      use_qsys_project=$(read_human_input)
      debug "use_qsys_project=$use_qsys_project"
      ;;&
    *[Rr][Ww][Tt][Hh] )
      use_queue="${use_queue%-*}-rwth"
      ;;
    '' )
      : ;;
    * )
      [[ -z $use_queue ]] && warning "Unrecognised queueing system ($test_queue)"
      ;;
  esac
  debug "use_queue=$use_queue"
}

ask_queueing_system ()
{
  ask_interactivity 
  ask_qsys_details
}

ask_threads ()
{
  ask "How many threads do you want to use by default?"
  use_threads=$(read_integer)
  if (( use_threads == 0 )) ; then
    warning "It is impossible to use no threads. Unsetting choice."
    unset use_threads
  fi
  debug "use_threads=$use_threads"
}

ask_memory ()
{
  ask "How much memory (in MB) do you want to use by default?"
  use_memory=$(read_integer)
  if (( use_memory == 0 )) ; then
    warning "It is impossible to use no memory. Unsetting choice."
    unset use_memory
  fi
  debug "use_memory=$use_memory"
}

ask_walltime ()
{
  ask "How much walltime (in hours) do you want to use if submitted to a queueing system?"
  use_walltime=$(read_integer)
  if (( use_walltime == 0 )) ; then
    warning "It is no good idea to set the walltime to zero. Unsetting choice."
    unset use_walltime
  else
    use_walltime="$use_walltime:00:00"
  fi
  debug "use_walltime=$use_walltime"
}

ask_environment_vars ()
{
  ask_threads
  ask_memory
  ask_walltime
}

ask_chattyness ()
{
  ask "What level of chattyness of runxtb would you like to set?" 
  message "(0: all; 1: no info; 2: no warnings; >2: nothing)"
  use_chatty=$(read_integer)
  debug "use_chatty=$use_chatty"
}

ask_files ()
{
  ask "Do you want to use a default file name for the output of xtb?"
  message "If you enter 'auto' runxtb will create a name based on the supplied input file."
  use_outputfile_name=$(read_human_input)
  debug "use_outputfile_name=$use_outputfile_name"
}

ask_all_settings ()
{
  ask_installation_path
  ask_modules
  ask_environment_vars
  ask_chattyness
  ask_files
  ask_queueing_system
}

print_settings ()
{
  echo     "## Set default processes (< number of available cores)."
  echo     "#  "
  if [[ -z $use_threads ]] ; then
    echo   "#  requested_numCPU=4"
  else
    echo   "   requested_numCPU=$use_threads"
  fi
  echo     "#  "
  echo     "###"

  echo     "## Set default memory to be used in megabyte."
  echo     "#  "
  if [[ -z $use_memory ]] ; then
    echo   "#  requested_memory=1000"
  else
    echo   "   requested_memory=$use_memory"
  fi
  echo     "#  "
  echo     "###"

  echo     "## Set directory."
  echo     "#  (Without including the bin directory/ executable name; avoid trailing slashes.)"
  echo     "#  "
  if [[ -z $use_xtbhome ]] ; then
    echo   "#  xtb_install_root=/path/to/xtbhome"
    echo   "#  xtb_install_root='~polyluxus/chemsoft/xtb/xtb_6.3.pre2'"
  else
    echo   "   xtb_install_root=\"$use_xtbhome\""
  fi
  echo     "#  "
  echo     "## Set the name of the executable."
  echo     "## (This should be xtb. Here set to xtb.dummy for testing.)"
  echo     "#"
  echo     "#  xtb_callname=\"xtb.dummy\""
  if [[ ! -z $use_xtbname ]] ; then
    echo   "   xtb_callname=\"$use_xtbname\""
  fi
  echo     "#"
  echo     "## The above two lines combined should give the full path to the program, i.e."
  echo     "## XTBHOME/xtb_callname"
  echo     "###"

  echo     "## Set chattyness." 
  echo     "## (0: all; 1: no info; 2: no warnings; >2: nothing)"
  echo     "#  "
  if [[ -z $use_chatty ]] ; then
    echo   "#  stay_quiet=0"
  else
   echo    "   stay_quiet=$use_chatty"
  fi
  echo     "#  "
  echo     "###"

  echo     "## Trap output of xtb in a file."
  echo     "## This will cause runxtb to always use the same filename, "
  echo     "## which can be overwritten with the -o switch."
  echo     "## Always generate a file with the output of xtb, but generate this name"
  echo     "## automagically, use arguments: 'auto' or '0'."
  echo     "## This can be overwritten with an explicit empty argument to -c:"
  echo     "##   runxtb -c '' [other opts] <coord> [xtb options]"
  echo     "#  "
  if [[ -z $use_outputfile_name ]] ; then
    echo   "#  output_file=\"runxtb.out\""
    echo   "#  output_file=\"auto\""
  else
    echo   "   output_file=\"$use_outputfile_name\""
  fi
  echo     "#  "
  echo     "###"

  echo     "## Set default mode, where interactive means that it is calculated immediately."
  echo     "## (yes: interactive; no: write script; sub: write and submit)"
  echo     "#  "
  if [[ -z $use_interactivity ]] ; then
    echo   "#  run_interactive=\"yes\""
  else
    echo   "   run_interactive=\"$use_interactivity\""
  fi
  echo     "#  "
  echo     "###"

  echo     "## Set default queueing system for which the script should be written"
  echo     "## (pbs-gen, bsub-gen, slurm-gen, or *-rwth [special cases, see source])"
  echo     "#  "
  if [[ -z $use_queue ]] ; then
    echo   "#  request_qsys=\"bsub-rwth\""
  else
    echo   "   request_qsys=\"$use_queue\""
  fi
  echo     "#  "
  echo     "###"

  echo     "## If project/ account options are enabled (e.g. for bsub-rwth), "
  echo     "## set the name to which it should be accounted to."
  echo     "## This can be overwritten with -P0 or -P default."
  echo     "#"
  if [[ -z $use_qsys_project ]] ; then
    echo   "#  qsys_project=\"default\""
  else
    echo   "   qsys_project=\"$use_qsys_project\""
  fi
  echo     "#  "
  echo     "###"

  echo     "## If modules are installed, their use can be enabled here."
  echo     "## The default is setting the path, see above."
  echo     "#"
  if [[ -z $use_module_system ]] ; then
    echo   "#  use_modules=\"true\""
  else
    echo   "   use_modules=\"$use_module_system\""
  fi
  echo     "#"
  if (( ${#use_module_items[@]} == 0 )) ; then
    echo   "#  They need to be named, too. For example:"
    echo   "#"
    echo   "#  load_modules[0]=\"CHEMISTRY\""
    echo   "#  load_modules[1]=\"xtb\""
  else
    echo   "#  Specified modules to be loaded:"
    echo   "#"
    local module_index=0 
    while (( module_index < ${#use_module_items[@]} )) ; do
      echo "   load_modules[$module_index]=\"${use_module_items[$module_index]}\""
      (( module_index++ ))
    done
  fi
  echo     "#  "
  echo     "###"

  echo     "## Set Walltime for non-interactive mode."
  echo     "#  "
  if [[ -z $use_walltime ]] ; then
    echo   "#  requested_walltime=\"24:00:00\""
  else
    echo   "   requested_walltime=\"$use_walltime\""
  fi
  echo     "#  "
  echo     "###"

  echo     "#  "
  echo     "## "
  echo -n  "###  "
  date
  echo     "#### End of file. (Automatic configuration.)"
}

create_bin_link ()
{
  local link_target_path="$HOME/bin"
  local link_target_name link_target link_source
    
  for link_target_name in "runxtb" "crest.prepare" ; do
    link_target="$link_target_path/$link_target_name"
    link_source="$runxtbrc_path/${link_target_name}.sh"
    if [[ -e "$link_target" ]] ; then
      debug "Link '$link_target' does already exist."
      continue
    else
      ask "Would you like to create a symbolic link '$link_target'?"
      if read_boolean ; then
        [[ -r "$link_target_path" ]] || fatal "Cannot read '$link_target_path'."
        [[ -w "$link_target_path" ]] || fatal "Cannot write to '$link_target_path'."
        [[ -x "$link_source" ]] || fatal "Not executable: '$link_source'."
        message "$( ln -vs "$link_source" "$link_target" )"
      fi
    fi
  done
}

#
# Executes the options
#

# Redirect messages to standard out
exec 3>&1

# Enable debug mode
if [[ "$1" == "debug" ]] ; then 
  exec 4>&1
else 
  exec 4> /dev/null 
fi

# Get to know where this script is located
scriptpath="$(get_bindir "$0" "directory of configure script")"
runxtbrc_path="$(get_bindir "$scriptpath/../.runxtbrc" "directory of configuration file")"

# Gather all information
recover_rc || ask_all_settings

ask "Where do you want to store these settings? (Please enter an absolute/ relatiuve file and path.)"
message "Predefined location: $PWD/runxtb.rc"
message "  (This is the current directory. It will be chosen if the input is empty.)"
message "Suggested location : $runxtbrc_path/.runxtbrc"
message "  (This is the runxtb installation directory.)"
message "You may also choose to enter a directory in which the file 'runxtb.rc' will be created."

settings_filename=$(read_human_input)
if [[ -z $settings_filename ]] ; then
  settings_filename="$PWD/runxtb.rc"
elif [[ -d "$settings_filename" ]] ; then
  settings_filename="$settings_filename/runxtb.rc"
  message "No filename specified, use '$settings_filename' instead."
elif [[ $settings_filename =~ ^[Aa][Uu][Tt][Oo]$ ]] ; then
  settings_filename="$runxtbrc_path/.runxtbrc"
  message "Automatic mode chosen, using '$settings_filename'."
fi
backup_if_exists "$settings_filename"

print_settings > "$settings_filename"

message "Written configuration to '$settings_filename'."

create_bin_link

message "Finished."

