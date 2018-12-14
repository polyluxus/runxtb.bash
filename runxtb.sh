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
    if (( stay_quiet <= 2 )) ; then 
      echo "ERROR  : " "$*" >&2
    else
      debug "(error  ) " "$*"
    fi
    exit 1
}

debug ()
{
    echo "DEBUG  : " "$*" >&4
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
    if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
      debug "Using modules."
      # Loading the modules should take care of everything except threats
      load_xtb_modules || fatal "Failed loading modules."
    fi
    if [[ -z $XTBHOME ]] ; then
      fatal "XTBHOME is unset."
    else
      add_to_MANPATH "$XTBHOME/man"
    fi
    debug "XTBHOME=$XTBHOME"
    debug "$(ls -w70 -Am "$XTBHOME" 2>&1)"
    debug "XTBPATH=$XTBPATH"
#   debug "         1         2         3         4         5         6         7         8"
#   debug "12345678901234567890123456789012345678901234567890123456789012345678901234567890"

    warning "From version 6.0 onwards there is no HOWTO included."
    message "Trying to display the man page instead."

    if man xtb ; then
      debug "Displaying man page was successful, exit now."
      exit
    else
      debug "No manpage available. Try HOWTO."
    fi

    [[ -e "$XTBHOME/HOWTO" ]] || fatal "Cannot find 'HOWTO' of xTB."
    if command -v less > /dev/null ; then
      less "$XTBHOME/HOWTO"
    else
      cat "$XTBHOME/HOWTO"
    fi
    exit 0
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
  local resolve_file="$1" description="$2" link_target directory_name resolve_dir_name
  debug "Getting directory for '$resolve_file'."

  resolve_file=$(expand_tilde_path "$resolve_file")

  # Taken in part from https://stackoverflow.com/a/246128/3180795
  # resolve $resolve_file until it is no longer a symlink
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

format_walltime_or_exit ()
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
  (( ${#load_modules[*]} == 0 )) && fatal "No modules to load."
  ( command -v module &>> "$tmpfile" ) || fatal "Command 'module' not available."
  if module load "${load_modules[*]}" &>> "$tmpfile" ; then
    debug "Modules loaded successfully."
  else
    debug "Issues loading modules."
    debug "$(cat "$tmpfile")"
    return 1
  fi
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

print_info ()
{
    message "Setting OMP_NUM_THREADS=$OMP_NUM_THREADS."
    message "Setting MKL_NUM_THREADS=$MKL_NUM_THREADS."
    message "Setting OMP_STACKSIZE=$OMP_STACKSIZE."
    message "Setting XTBHOME=$XTBHOME."
    message "Setting XTBPATH=$XTBPATH."
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
    local corrected_OMP_STACKSIZE
    corrected_OMP_STACKSIZE=$(( OMP_STACKSIZE + 50 ))
    
    # Header is different for the queueing systems
    if [[ "$queue" =~ [Pp][Bb][Ss] ]] ; then
      cat >&9 <<-EOF
			#PBS -l nodes=1:ppn=$OMP_NUM_THREADS
			#PBS -l mem=${corrected_OMP_STACKSIZE}m
			#PBS -l walltime=$requested_walltime
			#PBS -N ${submitscript_filename%.*}
			#PBS -m ae
			#PBS -o $submitscript_filename.o\${PBS_JOBID%%.*}
			#PBS -e $submitscript_filename.e\${PBS_JOBID%%.*}
			EOF
    #elif [[ "$queue" =~ [Bb][Ss][Uu][Bb]-[Rr][Ww][Tt][Hh] ]] ; then
    elif [[ "$queue" =~ [Bb][Ss][Uu][Bb] ]] ; then
      cat >&9 <<-EOF
			#BSUB -n $OMP_NUM_THREADS
			#BSUB -a openmp
			#BSUB -M $corrected_OMP_STACKSIZE
			#BSUB -W ${requested_walltime%:*}
			#BSUB -J ${submitscript_filename%.*}
			#BSUB -N
			#BSUB -o $submitscript_filename.o%J
			#BSUB -e $submitscript_filename.e%J
			EOF
      # If 'bsub_project' is empty, or '0', or 'default' (in any case, truncated after def)
      # do not write this line to the script.
      if [[ "$bsub_project" =~ ^(|0|[Dd][Ee][Ff][Aa]?[Uu]?[Ll]?[Tt]?)$ ]] ; then
        message "No project selected."
      else
        echo "#BSUB -P $bsub_project" >&9
      fi
      #add some more specific setup for RWTH
      if [[ "$queue" =~ [Bb][Ss][Uu][Bb]-[Rr][Ww][Tt][Hh] ]] ; then
        if [[ "$PWD" =~ [Hh][Pp][Cc] ]] ; then
          echo "#BSUB -R select[hpcwork]" >&9
        fi
      fi
    else
      fatal "Unrecognised queueing system '$queue'."
    fi

    # The following part of the body is the same for all queues 
    cat >&9 <<-EOF

		echo "This is \$(uname -n)"
		echo "OS \$(uname -p) (\$(uname -p))"
		echo "Running on $OMP_NUM_THREADS \$(grep 'model name' /proc/cpuinfo|uniq|cut -d ':' -f 2)."
		echo "Calculation with xtb from $PWD."
		echo "Working directry is $PWD"

		cd "$PWD"
		
		EOF

    # Use modules or path
    if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
      (( ${#load_modules[*]} == 0 )) && fatal "No modules to load."
      cat >&9 <<-EOF
			# Loading the modules should take care of everything except threads
      # Export current (at the time of execution) MODULEPATH (to be safe, could be set in bashrc)
			export MODULEPATH="$MODULEPATH"
			module load ${load_modules[*]} 2>&1 || exit
			# Redirect because otherwise it would go to the error output, which might be bad
			# Exit on error
			 
			EOF
    else
    	cat >&9 <<-EOF
			export PATH="$XTBHOME:\$PATH"
      # The following should actually work, but 
      # due to an error (?) in the distribution, needs the above (Change in runxtb)
			# export PATH="$XTBHOME/bin:$XTBHOME/scripts:\$PATH"
      export XTBHOME="$XTBHOME" # Not necessary (or even used) if the above works
			export XTBPATH="$XTBPATH" 
			# Setting MANPATH is not necessary in scripted mode.
			EOF
    fi

    cat >&9 <<-EOF
		export OMP_NUM_THREADS="$OMP_NUM_THREADS"
		export MKL_NUM_THREADS="$MKL_NUM_THREADS"
		export OMP_STACKSIZE="${OMP_STACKSIZE}m"  
		ulimit -s unlimited

		date
		$xtb_callname ${xtb_commands[@]} > "$output_file"
		date
		
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
# Get some informations of the platform
#
nodename=$(uname -n)
operatingsystem=$(uname -o)
architecture=$(uname -p)
processortype=$(grep 'model name' /proc/cpuinfo|uniq|cut -d ':' -f 2)

# Find temporary directory for internal logs (or use null)
if [[ ! -z $TMP ]] ; then
  tmpfile="$TMP/runxtb.err"
elif [[ ! -z $TEMP ]] ; then
  tmpfile="$TEMP/runxtb.err"
else 
  tmpfile="/dev/null"
fi
debug "Writing errors to temporary file '$tmpfile'."

#
# Details about this script
#
version="0.2.0_devel"
versiondate="2018-11-XX"

#
# Set some Defaults
#

OMP_NUM_THREADS=4
MKL_NUM_THREADS=4
OMP_STACKSIZE=1000
xtb_callname="xtb"
requested_walltime="24:00:00"
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

scriptpath="$(get_bindir "$0" "Directory of runxtb")"
runxtbrc_loc="$(get_rc "$scriptpath" "/home/$USER" "$PWD")"
debug "runxtbrc_loc=$runxtbrc_loc"

if [[ ! -z $runxtbrc_loc ]] ; then
  # shellcheck source=/home/te768755/devel/runxtb.bash/runxtb.rc
  . "$runxtbrc_loc"
  message "Configuration file '$runxtbrc_loc' applied."
fi

OPTIND=1

while getopts :p:m:w:o:sSQ:P:Ml:iB:C:qhH options ; do
  case $options in
    #hlp OPTIONS:
    #hlp   Any switches used will overwrite rc settings,
    #hlp   for the same options, only the last one will have an effect.
    #hlp 
    #hlp   -p <ARG> Set number of professors
    p) validate_integer "$OPTARG"
       OMP_NUM_THREADS="$OPTARG"
       MKL_NUM_THREADS="$OPTARG"
       ;;
    #hlp   -m <ARG> Set the number of memories (in megabyte)
    m) validate_integer "$OPTARG"
       OMP_STACKSIZE="${OPTARG}"
       ;;
    #hlp   -w <ARG> Set the walltime when sent to the queue
    w) requested_walltime=$(format_walltime_or_exit "$OPTARG")
       ;;
    #hlp   -o <ARG> Trap the output into a file called <ARG>.
    o) output_file="$OPTARG"
       ;;
    #hlp   -s       Write submitscript (instead of interactive execution)
    #hlp            Requires '-Q' to be set. (Default: pbs-gen)
    s) run_interactive="no"
       ;;
    #hlp   -S       Write submitscript and submit it to the queue.
    #hlp            Requires '-Q' to be set. (Default: pbs-gen)
    S) run_interactive="sub"
       ;;
    #hlp   -Q <ARG> Select queueing system (pbs-gen, bsub-rwth)
    Q) request_qsys="$OPTARG"
       ;;
    #hlp   -P <ARG> Account to project <ARG>.
    #hlp            This will automatically set '-Q bsub-rwth', too.
    #hlp            (It will not trigger remote execution.)
    P) bsub_project="$OPTARG"
       request_qsys="bsub-rwth"
       ;;
    #hlp   -M       Use modules instead of paths (work in progress).
    #hlp            Needs a specified modules list (set in rc).
    M) use_modules=true
       ;;
    #hlp   -l <ARG> Specify a module to be used (work in progress). This will also invoke -M.
    #hlp            May be specified multiple times to create a list.
    #hlp            The modules need to be specified in the order they have to be loaded.
    #hlp            If <ARG> is '0', then reset the list.
    #hlp            (Can also be set in the rc.)
    l) use_modules=true
       if [[ "$OPTARG" =~ [0]+ ]] ; then
         unset load_modules
       else
         load_modules[${#load_modules[*]}]="$OPTARG"
       fi
       ;;
    #hlp   -i       Execute in interactive mode (overwrite rc settings)
    i) run_interactive="yes"
       ;;
    #hlp   -B <ARG> Set absolute path to xtb to <ARG>.
    B) XTBHOME="$(get_bindir "$OPTARG" "XTBHOME")"
       xtb_callname="${OPTARG##*/}"
       ;;
    #hlp   -C <ARG> Change the callname of the script.
    #hlp            This can be useful to request a different executable from the package.
    #hlp            No warning will be issued if the command line is empty.
    C) xtb_callname="$OPTARG"
       ignore_empty_commandline="true"
       ;;
    #hlp   -q       Stay quiet! (Only this startup script)
    #hlp            May be specified multiple times to be more forceful.
    q) (( stay_quiet++ )) 
       ;;
    #hlp   -h       Prints this help text
    h) helpme ;;

    #hlp   -H       Displays the HOWTO file from the xtb distribution
    H) display_howto ;;

   \?) fatal "Invalid option: -$OPTARG." ;;

    :) fatal "Option -$OPTARG requires an argument." ;;

    #hlp Current settings:
    #hlp   XTBHOME="$XTBHOME" 
    #hlp   xtb_callname="$xtb_callname"
    #hlp   use_modules="$use_modules" 
    #hlp   load_modules=("${load_modules[*]}")
    #hlp   OMP_NUM_THREADS="$OMP_NUM_THREADS"
    #hlp   MKL_NUM_THREADS="$MKL_NUM_THREADS"
    #hlp   OMP_STACKSIZE="$OMP_STACKSIZE"
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
jobname="${1%.xyz}"
debug "Guessed jobname is '$jobname'."

# Store everything that should be passed to xtb
xtb_commands=("$@")
debug "Commands for xtb are '${xtb_commands[*]}'."

if [[ "$ignore_empty_commandline" =~ [Ff][Aa][Ll][Ss][Ee] ]] ; then
  (( ${#xtb_commands[*]} == 0 )) && warning "There are no commands to pass on to xtb."
else
  debug "Ignore empty command line."
fi

# Before proceeding, print a warning, that this is  N O T  the real program.
warning "This is not the original xtb program!"
warning "This is only a wrapper to set paths and variables."

if [[ "$use_modules" =~ ^[Tt][Rr]?[Uu]?[Ee]? ]] ; then
  # Loading the modules should take care of everything except threats
  load_xtb_modules || fatal "Failed loading modules."
fi

# If not set explicitly, assume xtb is in same directory as script
[[ -z $XTBHOME ]] && XTBHOME="$scriptpath"
[[ -z $XTBPATH ]] && XTBPATH="$XTBHOME"

if check_program "$XTBHOME/$xtb_callname" ; then
  # Theoretically this should be completely obsolete from version 6.0 onwards
  # and instead the approach below should be used
  add_to_PATH "$XTBHOME"
  debug "Found program: $( command -v "$xtb_callname" )"
else
  message "Trying recommended approach for xtb 6.0"
  add_to_PATH "$XTBHOME/bin"
  add_to_PATH "$XTBHOME/scripts"
  add_to_MANPATH "$XTBHOME/man"
  debug "Found program: $( command -v "$xtb_callname" )"
  check_program "$XTBHOME/bin/$xtb_callname" || fatal "Cannot continue"
fi

export OMP_NUM_THREADS MKL_NUM_THREADS OMP_STACKSIZE
ulimit -s unlimited || fatal "Something went wrong unlimiting stacksize."
debug "Settings: XTBHOME=$XTBHOME xtb_callname=$xtb_callname"
debug "(current) use_modules=$use_modules load_modules=(${load_modules[*]})"
debug "          OMP_NUM_THREADS=$OMP_NUM_THREADS MKL_NUM_THREADS=$MKL_NUM_THREADS"
debug "          OMP_STACKSIZE=$OMP_STACKSIZE requested_walltime=$requested_walltime"
debug "          outputfile=$output_file run_interactive=$run_interactive"
debug "Platform: nodename=$nodename; operatingsystem=$operatingsystem"
debug "(current) architecture=$architecture"
debug "          processortype=$processortype"

print_info

if [[ $run_interactive =~ ([Nn][Oo]|[Ss][Uu][Bb]) ]] ; then
  [[ -z $request_qsys ]] && fatal "No queueing system specified."
  [[ $output_file =~ ^(|0|[Aa][Uu][Tt][Oo])$ ]] && output_file="$jobname.subxtb.out"
  backup_if_exists "$output_file"
  submitscript=$(write_submit_script "$request_qsys" "$output_file")
  if [[ $run_interactive =~ [Ss][Uu][Bb] ]] ; then
    debug "Created '$submitscript'."
    if [[ $request_qsys =~ [Pp][Bb][Ss] ]] ; then
      submit_id="Submitted as $(qsub "$submitscript")" || exit_status="$?"
    elif [[ $request_qsys =~ [Bb][Ss][Uu][Bb] ]] ; then
      submit_id="$(bsub < "$submitscript" 2>&1 )" || exit_status="$?"
      submit_id="${submit_id#Info: }"
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
  if [[ -z $output_file ]] ; then 
    $xtb_callname "${xtb_commands[@]}" 
    exit_status="$?" # Carry over exit status
  elif [[ "$output_file" =~ ^(0|[Aa][Uu][Tt][Oo])$ ]] ; then
    # Enables automatic generation of output-filename in 'interactive' mode
    output_file="$jobname.runxtb.out"
    message "Will write xtb output to '$output_file'."
    backup_if_exists "$output_file"
    $xtb_callname "${xtb_commands[@]}" > "$output_file"
    exit_status="$?" # Carry over exit status
  else
    backup_if_exists "$output_file"
    $xtb_callname "${xtb_commands[@]}" > "$output_file"
    exit_status="$?" # Carry over exit status
  fi
else
  fatal "Unrecognised mode; abort."
fi

# Clean up
if [[ -e "$tmpfile" && -f "$tmpfile" ]] ; then
  debug "$(rm -vf "$tmpfile")"
fi

message "Runxtb ($version, $versiondate) wrapper script completed."
exec 3>&-
#hlp ===== End of Script ===== (Martin, $version, $versiondate)
exit $exit_status
