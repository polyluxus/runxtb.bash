#!/bin/bash

#hlp ===== Not Part of xTB =====
#hlp DESCRIPTION:
#hlp   This is a little helper script to use xTB from
#hlp   https://www.chemie.uni-bonn.de/pctc/mulliken-center/software/xtb/xtb
#hlp   without making changes to any local setting files like
#hlp   '.bashrc', '.profile', etc.
#hlp  
#hlp USAGE:
#hlp   runxtb.sh [script options] <coord_file> [xtb options]
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

#
# Display the HOWTO (manual) of xTB
#

display_howto ()
{
  local show_howto="${1:-xtb}"
  if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
    debug "Using modules."
    # Loading the modules should take care of everything except threads
    load_xtb_modules || fatal "Failed loading modules."
  else
    debug "Using path settings."
    # Assume if there is no special configuration applied which sets the install directory
    # that the scriptdirectory is also the root directory of xtb
    XTBPATH="${xtb_install_root:-$scriptpath}"
    debug "Setting XTBPATH=$XTBPATH"
    # From 6.0 on, XTBPATH must be set. Fail if the fallback is also not found
    local xtb_manpath xtbpath_munge
    # Since XTBPATH must be set, parse that first for the manpath
    if [[ -n $XTBPATH ]] ; then
      xtbpath_munge="$XTBPATH"
      while [[ ":${xtbpath_munge}:" =~ ^:([^:]+):(.*):$ ]] ; do 
        [[ -d "${BASH_REMATCH[1]}/man" ]] || { xtbpath_munge="${BASH_REMATCH[2]}" ; continue ; }
        xtb_manpath="${BASH_REMATCH[1]}/man"
        break
      done
    else
      warning "The environment variable 'XTBPATH' is unset, trying fallback 'XTBHOME'."
      warning "Please check your installation."
    fi 
    # If no man directory is found along path, fallback to XTBHOME
    if [[ -z $xtb_manpath ]] ; then
      # Assume if XTBHOME is set, it is the root directorry and contains the man directory
      if [[ -n $XTBHOME ]] ; then
        if [[ -d "$XTBHOME/man" ]] ; then
          xtb_manpath="$XTBHOME/man"
        else 
          fatal "Manual directory '$XTBHOME/man' is missing."
        fi
      else
        fatal "The fallback environment variable 'XTBHOME' is unset."
      fi
    else
      # Add the found directory to the manpath
      add_to_MANPATH "$xtb_manpath"
    fi
  fi
  debug "XTBPATH=$XTBPATH (XTBHOME=$XTBHOME)"

  message "From version 6.0 onwards there is no HOWTO included, displaying man page instead."

  debug "Showing manual for $show_howto."
  if man "$show_howto" ; then
    debug "Displaying man page was successful, exit now."
    exit 0
  else
    debug "No manpage available. Try fallback to HOWTO."
    [[ -e "$XTBHOME/HOWTO" ]] || fatal "Also cannot find 'HOWTO' of xTB."
    local less_cmd
    if less_cmd="$( command -v less 2> /dev/null )" ; then
      "$less_cmd" "$XTBHOME/HOWTO"
    else
      cat "$XTBHOME/HOWTO"
    fi
    exit 0
  fi
}

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
# Clean up routine
#

cleanup_and_quit ()
{
  # Clean temporary files
  if [[ -e "$tmpfile" && -f "$tmpfile" ]] ; then
    debug "$(rm -vf "$tmpfile")"
  fi

  # Say a nice 'Bye bye!'
  message "Runxtb ($version, $versiondate) wrapper script completed."

  # Close the messaging channel
  exec 3>&-
  
  # Leave orderly
  exit "$exit_status"
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

validate_walltime ()
{
    local check_duration="$1"
    # Split time in HH:MM:SS
    # Strips away anything up to and including the rightmost colon
    # strips nothing if no colon present
    # and tests if the value is numeric
    # this is assigned to seconds
    local trunc_duration_seconds=${check_duration##*:}
    validate_integer "$trunc_duration_seconds" "seconds"
    # If successful value is stored for later assembly
    #
    # Check if the value is given in seconds
    # "${check_duration%:*}" strips shortest match ":*" from back
    # If no colon is present, the strings are identical
    if [[ ! "$check_duration" == "${check_duration%:*}" ]]; then
        # Strip seconds and colon
        check_duration="${check_duration%:*}"
        # Strips away anything up to and including the rightmost colon
        # this is assigned as minutes
        # and tests if the value is numeric
        local trunc_duration_minutes=${check_duration##*:}
        validate_integer "$trunc_duration_minutes" "minutes"
        # If successful value is stored for later assembly
        #
        # Check if value was given as MM:SS same procedure as above
        if [[ ! "$check_duration" == "${check_duration%:*}" ]]; then
            #Strip minutes and colon
            check_duration="${check_duration%:*}"
            # # Strips away anything up to and including the rightmost colon
            # this is assigned as hours
            # and tests if the value is numeric
            local trunc_duration_hours=${check_duration##*:}
            validate_integer "$trunc_duration_hours" "hours"
            # Check if value was given as HH:MM:SS if not, then exit
            if [[ ! "$check_duration" == "${check_duration%:*}" ]]; then
                fatal "Unrecognised duration format."
            fi
        fi
    fi

    # Modify the duration to have the format HH:MM:SS
    # disregarding the format of the user input
    # keep only 0-59 seconds stored, let rest overflow to minutes
    local final_duration_seconds=$((trunc_duration_seconds % 60))
    # Add any multiple of 60 seconds to the minutes given as input
    trunc_duration_minutes=$((trunc_duration_minutes + trunc_duration_seconds / 60))
    # save as minutes what cannot overflow as hours
    local final_duration_minutes=$((trunc_duration_minutes % 60))
    # add any multiple of 60 minutes to the hours given as input
    local final_duration_hours=$((trunc_duration_hours + trunc_duration_minutes / 60))

    # Format string and save on variable
    printf "%d:%02d:%02d" $final_duration_hours $final_duration_minutes $final_duration_seconds
}

# 
# Load the modules
#

load_xtb_modules ()
{
  # Fail if there are no modules given (don't make any assumptions).
  (( ${#load_modules[*]} == 0 )) && fatal "No modules to load."
  # Fail if the module command is not available. 
  ( command -v module &>> "$tmpfile" ) || fatal "Command 'module' not available."
  # Try to load the modules, but trap the output in the temporary file.
  # Exit if that fails (On RWTH cluster the exit status of modules is always 0).
  module load "${load_modules[*]}" &>> "$tmpfile" || fatal "Failed to load modules."
  # Remove colourcodes with sed:
  # https://www.commandlinefu.com/commands/view/12043/remove-color-special-escape-ansi-codes-from-text-with-sed
  sed -i 's,\x1B\[[0-9;]*[a-zA-Z],,g' "$tmpfile"
  # Check whether then modules were loaded ok
  local check_module
  for check_module in "${load_modules[@]}" ; do
    # Cut after a slash is encountered (probably works universally), there is a check for the command anyway
    if grep -q -E "${check_module%%/*}.*[Oo][Kk]" "$tmpfile" ; then
      debug "Module '${check_module}' loaded successfully."
    else
      debug "Issues loading module '${check_module}'."
      debug "$(cat "$tmpfile")"
      return 1
    fi
  done
}

# 
# Test and add to PATH
#

check_program ()
{
    if [[ -f "$1" && -x "$1" ]] ; then
      message "Found programm '$1'."
      return 0
    else
      warning "Programm '$1' does not seem to exist or is not executable."
      warning "The script might not have been set up properly."
      return 1
    fi
}    

add_to_PATH ()
{
    [[ -d "$1" ]] || fatal "Cowardly refuse to add non-existent directory to PATH."
    [[ -x "$1" ]] || fatal "Cowardly refuse to add non-accessible directory to PATH."
    [[ :$PATH: =~ :$1: ]] || PATH="$1:$PATH"
    debug "$PATH"
}

add_to_MANPATH ()
{
    [[ -d "$1" ]] || fatal "Cowardly refuse to add non-existent directory to PATH."
    [[ -x "$1" ]] || fatal "Cowardly refuse to add non-accessible directory to PATH."
    [[ :$MANPATH: =~ :$1: ]] || PATH="$1:$MANPATH"
    debug "$PATH"
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
      local move_message
      move_message="$(mv -v "$1" "$1.$filecount")"
      message "$move_message"
    fi
}

#
# Write submission script
#

write_submit_script ()
{
    message "Remote mode selected, creating job script instead."
    # Possible values for queue are pbs-gen bsub-gen bsub-rwth
    local queue="$1" queue_short 
    local output_file_local="$2" submitscript_filename
    [[ -z $queue ]] && fatal "No queueing systen selected. Abort."
    queue_short="${queue%-*}"
    submitscript_filename="${output_file_local%.*}.${queue_short}.bash"
    debug "Selected queue: $queue; short: $queue_short"
    backup_if_exists "$submitscript_filename"
    debug "Will write submitscript to: $submitscript"

    # Open file descriptor 9 for writing
    exec 9> "$submitscript_filename"

    echo "#!/bin/bash" >&9
    echo "# Submission script automatically created with runxtb.sh" >&9

    # Add some overhead
    local corrected_memory
    corrected_memory=$(( requested_memory + 100 ))
    
    # Header is different for the queueing systems
    if [[ "$queue" =~ [Pp][Bb][Ss] ]] ; then
      cat >&9 <<-EOF
			#PBS -l nodes=1:ppn=$requested_numCPU
			#PBS -l mem=${corrected_memory}m
			#PBS -l walltime=$requested_walltime
			#PBS -N ${submitscript_filename%.*}
			#PBS -m ae
			#PBS -o $submitscript_filename.o\${PBS_JOBID%%.*}
			#PBS -e $submitscript_filename.e\${PBS_JOBID%%.*}
			EOF
    elif [[ "$queue" =~ [Bb][Ss][Uu][Bb] ]] ; then
      cat >&9 <<-EOF
			#BSUB -n $requested_numCPU
			#BSUB -a openmp
			#BSUB -M $corrected_memory
			#BSUB -W ${requested_walltime%:*}
			#BSUB -J ${submitscript_filename%.*}
			#BSUB -N
			#BSUB -o $submitscript_filename.o%J
			#BSUB -e $submitscript_filename.e%J
			EOF
      # If 'bsub_project' is empty, or '0', or 'default' (in any case, truncated after def)
      # do not write this line to the script.
      if [[ "$bsub_project" =~ ^(|0|[Dd][Ee][Ff][Aa]?[Uu]?[Ll]?[Tt]?)$ ]] ; then
        warning "No project selected."
      else
        echo "#BSUB -P $bsub_project" >&9
      fi
      #add some more specific setup for RWTH
      if [[ "$queue" =~ [Bb][Ss][Uu][Bb]-[Rr][Ww][Tt][Hh] ]] ; then
        if [[ "$PWD" =~ [Hh][Pp][Cc] ]] ; then
          echo "#BSUB -R select[hpcwork]" >&9
        fi
      fi
    elif [[ "$queue" =~ [Ss][Ll][Uu][Rr][Mm] ]] ; then
      message "WIP"
      cat >&9 <<-EOF
			#SBATCH --jobname='${submitscript_filename%.*}'
			#SBATCH --output='$submitscript_filename.o%J'
			#SBATCH --error='$submitscript_filename.e%J'
			#SBATCH --nodes=1 
			#SBATCH --ntasks=1
			#SBATCH --cpus-per-task=$requested_numCPU
      #SBATCH --mem-per-cpu=$(( corrected_memory / requested_numCPU ))
			#SBATCH --time=${requested_walltime}
			#SBATCH --mail-type=END,FAIL
			EOF
      if [[ "$bsub_project" =~ ^(|0|[Dd][Ee][Ff][Aa]?[Uu]?[Ll]?[Tt]?)$ ]] ; then
        warning "No project selected."
      else
        echo "#SBATCH --account='$bsub_project'" >&9
      fi
    else
      fatal "Unrecognised queueing system '$queue'."
    fi

    # The following part of the body is the same for all queues 
    cat >&9 <<-EOF

		echo "This is \$(uname -n)"
		echo "OS \$(uname -p) (\$(uname -p))"
		echo "Running on $requested_numCPU \$(grep 'model name' /proc/cpuinfo|uniq|cut -d ':' -f 2)."
		echo "Calculation with $xtb_callname from $PWD."
		echo "Working directry is $PWD"

		cd "$PWD" || exit 1
		
		EOF

    # Use modules or path
    if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
      (( ${#load_modules[*]} == 0 )) && fatal "No modules to load."
      cat >&9 <<-EOF
			# Loading the modules should take care of everything except threads
      # Export current (at the time of execution) MODULEPATH (to be safe, could be set in bashrc)
			export MODULEPATH="$MODULEPATH"
			module load ${load_modules[*]} 2>&1 || exit 1
			# Redirect because otherwise it would go to the error output, which might be bad
			# Exit on error, which it might not do given a specific implementation
			 
			EOF
    else
      # Use path settings
    	cat >&9 <<-EOF
			export PATH="$XTBPATH/bin:\$PATH"
			export XTBPATH="$XTBPATH"
			# Setting MANPATH is not necessary in scripted mode.
			EOF
    fi

    cat >&9 <<-EOF
		# Test the command
		command -v "$xtb_callname" || exit 1
		export OMP_NUM_THREADS="$requested_numCPU"
		export MKL_NUM_THREADS="$requested_numCPU"
		export OMP_STACKSIZE="${requested_memory}m"  
		ulimit -s unlimited || exit 1

		date
		"$xtb_callname" ${xtb_commands[@]} > "$output_file" || { date ; exit 1 ; }
		date
		[[ -e molden.input ]] && mv -v -- molden.input "${output_file%.*}.molden"
		
		EOF

echo "$submitscript_filename"
}

#
# Start main script
#

# Sent logging information to stdout
exec 3>&1

if [[ "$1" == "debug" ]] ; then
  # Secret debugging switch
  exec 4>&1
  stay_quiet=0 
  shift 
else
  exec 4> /dev/null
fi

#
# Get some information of the current platform
#
nodename=$(uname -n)
operatingsystem=$(uname -o)
architecture=$(uname -p)
processortype=$(grep 'model name' /proc/cpuinfo|uniq|cut -d ':' -f 2)

# Find temporary directory for internal logs (or use null)
if ! tmpfile="$( mktemp --tmpdir runxtb.err.XXXXXX 2> /dev/null )" ; then
  warning "Failed creating temporary file for error logging."
  tmpfile="/dev/null"
fi
debug "Writing errors to temporary file '$tmpfile'."

# Clean up in case of emergency
trap cleanup_and_quit EXIT SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

#
# Details about this script
#
version="0.2.1"
versiondate="2019-02-14"

#
# Set some Defaults
#

xtb_callname="xtb"
requested_walltime="24:00:00"
requested_numCPU=4
requested_memory=1000
run_interactive="yes"
request_qsys="pbs-gen"
bsub_project="default"
exit_status=0
use_modules="false"
declare -a load_modules
#load_modules[0]="CHEMISTRY"
#load_modules[1]="xtb"
stay_quiet=0
ignore_empty_commandline=false

scriptpath="$( get_bindir "$0" "Directory of runxtb" )"
runxtbrc_loc="$(get_rc "$scriptpath" "/home/$USER" "/home/$USER/.config/" "$PWD")"
debug "runxtbrc_loc=$runxtbrc_loc"

if [[ -n $runxtbrc_loc ]] ; then
  # shellcheck source=/home/te768755/devel/runxtb.bash/runxtb.rc
  . "$runxtbrc_loc"
  message "Configuration file '$runxtbrc_loc' applied."
else
  debug "No configuration file found."
fi

OPTIND=1

while getopts :p:m:w:o:sSQ:P:Ml:iB:C:qhHX options ; do
  case $options in
    #hlp OPTIONS:
    #hlp   Any switches used will overwrite rc settings,
    #hlp   for the same options, only the last one will have an effect.
    #hlp 
    #hlp   -p <ARG> Set number of professors
    p) 
      validate_integer "$OPTARG"
      requested_numCPU="$OPTARG"
      ;;
    #hlp   -m <ARG> Set the number of memories (in megabyte)
    m)
      validate_integer "$OPTARG"
      requested_memory="${OPTARG}"
      ;;
    #hlp   -w <ARG> Set the walltime when sent to the queue
    w)
      requested_walltime=$( validate_walltime "$OPTARG" )
      ;;
    #hlp   -o <ARG> Trap the output into a file called <ARG>.
    #hlp            For the values '', '0', 'auto' the script will guess.
    #hlp            Use 'stdout', '-' to send output to standard out.
    o) 
      output_file="$OPTARG"
      ;;
    #hlp   -s       Write submitscript (instead of interactive execution)
    #hlp            Requires '-Q' to be set. (Default: pbs-gen)
    s) 
      run_interactive="no"
      ;;
    #hlp   -S       Write submitscript and submit it to the queue.
    #hlp            Requires '-Q' to be set. (Default: pbs-gen)
    S) 
      run_interactive="sub"
      ;;
    #hlp   -Q <ARG> Select queueing system (pbs-gen, bsub-rwth)
    Q)
      request_qsys="$OPTARG"
      ;;
    #hlp   -P <ARG> Account to project <ARG>.
    #hlp            This will automatically set '-Q bsub-rwth', too.
    #hlp            (It will not trigger remote execution.)
    P) 
      bsub_project="$OPTARG"
      request_qsys="bsub-rwth"
      ;;
    #hlp   -M       Use modules instead of paths (work in progress).
    #hlp            Needs a specified modules list (set in rc).
    M)
      use_modules="true"
      ;;
    #hlp   -l <ARG> Specify a module to be used (work in progress). This will also invoke -M.
    #hlp            May be specified multiple times to create a list.
    #hlp            The modules need to be specified in the order they have to be loaded.
    #hlp            If <ARG> is '0', then reset the list.
    #hlp            (Can also be set in the rc.)
    l)
      use_modules="true"
      if [[ "$OPTARG" =~ ^[[:space:]]*([0]+)[[:space:]]?(.*)$ ]] ; then
        unset load_modules
        [[ -n "${BASH_REMATCH[2]}" ]] && load_modules+=( "${BASH_REMATCH[2]}" )
      else
        load_modules+=( "$OPTARG" )
      fi
      ;;
    #hlp   -i       Execute in interactive mode (overwrite rc settings)
    i) 
      run_interactive="yes"
      ;;
    #hlp   -B <ARG> Set absolute path to the xtb executable to <ARG>.
    #hlp            This will also set the callname and ignore an empty commandline.
    #hlp            Assumed format for <ARG>: ./relative/or/absolute/path/to/XTBHOME/bin/'callname'
    B) 
      xtb_install_root="$( get_bindir "${OPTARG%/bin/*}" "XTB root directory" )"
      xtb_callname="${OPTARG##*/}"
      ;;
    #hlp   -C <ARG> Change the callname of the script.
    #hlp            This can be useful to request a different executable from the package.
    #hlp            No warning will be issued if the command line is empty.
    C) 
      xtb_callname="$OPTARG"
      ignore_empty_commandline="true"
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
    #hlp   -H       Displays the man page of xtb of the installation.
    H) 
      display_howto "xtb"
      ;;
    #hlp   -X       Displays the man page of xcontrol of the installation.
    X) 
      display_howto "xcontrol"
      ;;
    \?) 
      fatal "Invalid option: -$OPTARG." 
      ;;
    :) 
      fatal "Option -$OPTARG requires an argument." 
      ;;

    #hlp Current settings:
    #hlp   xtb_install_root="$xtb_install_root" (will set XTBPATH)
    #hlp   xtb_callname="$xtb_callname"
    #hlp   use_modules="$use_modules" 
    #hlp   load_modules=("${load_modules[*]}")
    #hlp   requested_numCPU="$requested_numCPU"
    #hlp   requested_memory="$requested_memory"
    #hlp   requested_walltime="$requested_walltime"
    #hlp   outputfile="$output_file"
    #hlp   run_interactive="$run_interactive"
    #hlp   request_qsys="$request_qsys"
    #hlp   bsub_project="$bsub_project"
    #hlp Platform information:
    #hlp   nodename="$nodename"
    #hlp   operatingsystem="$operatingsystem"
    #hlp   architecture="$architecture"
    #hlp   processortype="$processortype"
  esac
done

shift $(( OPTIND - 1 ))

# Assume jobname from name of coordinate file, cut xyz (if exists)
if [[ -r $1 ]] ; then
  jobname="${1%.xyz}"
  debug "Guessed jobname is '$jobname'."
else
  jobname="${PWD##*/}"
fi

# Store everything that should be passed to xtb
xtb_commands=("$@")
debug "Commands for ${xtb_callname} are '${xtb_commands[*]}'."

if [[ "$ignore_empty_commandline" =~ [Ff][Aa][Ll][Ss][Ee] ]] ; then
  (( ${#xtb_commands[*]} == 0 )) && warning "There are no commands to pass on to xtb."
else
  debug "Ignore empty command line."
fi

# Before proceeding, print a warning, that this is  N O T  the real program.
message "This is not the original xtb program!"
message "This is only a wrapper to set paths and variables."

if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
  debug "Using modules."
  # Loading the modules should take care of everything except threats
  load_xtb_modules || fatal "Failed loading modules."
else
  debug "Using path settings."
  # Assume if there is no special configuration applied which sets the install directory
  # that the scriptdirectory is also the root directory of xtb
  XTBPATH="${xtb_install_root:-$scriptpath}"
  if [[ -d "${XTBPATH}/bin" ]] ; then
    add_to_PATH "${XTBPATH}/bin"
  else
    fatal "Cannot locate bin directory in '$XTBPATH'."
  fi
  # Add the manual path, even though we won't need it
  [[ -d "${XTBPATH}/man" ]] && add_to_MANPATH "${XTBPATH}/man"
  export XTBPATH PATH MANPATH
fi

# Check whether we have the right executable
debug "$xtb_callname is '$( command -v "$xtb_callname")'" || fatal "Command not found: $xtb_callname"

# Set and export other environment variables
OMP_NUM_THREADS="$requested_numCPU"
MKL_NUM_THREADS="$requested_numCPU"
OMP_STACKSIZE="$requested_memory"

export OMP_NUM_THREADS MKL_NUM_THREADS OMP_STACKSIZE
ulimit -s unlimited || fatal "Something went wrong unlimiting stacksize."
debug "Settings:    xtb_install_root=$xtb_install_root (= XTBPATH)"
debug "(current)    xtb_callname=$xtb_callname"
debug "             use_modules=$use_modules load_modules=(${load_modules[*]})"
debug "             requested_numCPU=$requested_numCPU requested_memory=$requested_memory"
debug "             requested_walltime=$requested_walltime"
debug "             outputfile=$output_file run_interactive=$run_interactive"
debug "Environment: XTBPATH=$XTBPATH OMP_STACKSIZE=$OMP_STACKSIZE"
debug "             OMP_NUM_THREADS=$OMP_NUM_THREADS MKL_NUM_THREADS=$MKL_NUM_THREADS"
debug "Platform:    nodename=$nodename; operatingsystem=$operatingsystem"
debug "(current)    architecture=$architecture"
debug "             processortype=$processortype"

# Create a filename for the output (jobname cannot be empty, output_file may not be empty)
[[ $output_file =~ ^(|0|[Aa][Uu][Tt][Oo])$ ]] && output_file="$jobname.runxtb.out"
debug "Output goes to: $output_file"

if [[ $run_interactive =~ ([Nn][Oo]|[Ss][Uu][Bb]) ]] ; then
  [[ -z $request_qsys ]] && fatal "No queueing system specified."
  backup_if_exists "$output_file"
  submitscript=$(write_submit_script "$request_qsys" "$output_file")
  debug "Created '$submitscript'."

  if [[ $run_interactive =~ [Ss][Uu][Bb] ]] ; then
    if [[ $request_qsys =~ [Pp][Bb][Ss] ]] ; then
      submit_id="Submitted as $(qsub "$submitscript")" || exit_status="$?"
    elif [[ $request_qsys =~ [Bb][Ss][Uu][Bb] ]] ; then
      submit_id="$(bsub < "$submitscript" 2>&1 )" || exit_status="$?"
      submit_id="${submit_id#Info: }"
    elif [[ "$queue" =~ [Ss][Ll][Uu][Rr][Mm] ]] ; then
      submit_id="$(sbatch "$submitscript" )" || exit_status="$?"
    else
      fatal "Unrecognised queueing system '$request_qsys'."
    fi
    if (( exit_status > 0 )) ; then
      warning "Submission went wrong."
      warning "Probable cause: $submit_id"
    else
      message "$submit_id"
    fi
  else
    message "Created $request_qsys submit script '$submitscript'."
  fi
elif [[ $run_interactive =~ [Yy][Ee][Ss] ]] ; then
  if [[ $output_file  =~ ^[[:space:]]*(-|[Ss][Tt][Dd][Oo][Uu][Tt])[[:space:]]*$ ]] ; then 
    debug "Writing to stdout, Caught ${BASH_REMATCH[1]} in '$output_file'."
    "$xtb_callname" "${xtb_commands[@]}" 
    exit_status="$?" # Carry over exit status
  else
    message "Will write xtb output to '$output_file'."
    backup_if_exists "$output_file"
    "$xtb_callname" "${xtb_commands[@]}" > "$output_file" 2> "${output_file%.*}.err"
    exit_status="$?" # Carry over exit status
    # If the error file says everything is normal, delete it
    if grep -q -E "normal termination of xtb" "${output_file%.*}.err" ; then
      debug "$( cat "${output_file%.*}.err" )"
      debug "$( rm -v -- "${output_file%.*}.err" )"
    fi
  fi
  # If a molden file is written, move it to a new filename
  [[ -e molden.input ]] && message "$(mv -v -- molden.input "${output_file%.*}.molden")"
else
  fatal "Unrecognised mode '$run_interactive'; abort."
fi

#cleanup_and_quit
#hlp ===== End of Script ===== (Martin, $version, $versiondate)

