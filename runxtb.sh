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
    local pattern="^[[:space:]]*#hlp[[:space:]]?(.*)?$"
    while read -r line; do
      [[ "$line" =~ $pattern ]] && eval "echo \"${BASH_REMATCH[1]}\""
    done < <(grep "#hlp" "$0")
    exit 0
}

get_bindir ()
{
#  Taken from https://stackoverflow.com/a/246128/3180795
  local resolve_file="$1" description="$2" link_target directory_name resolve_dir_name
  message "Getting directory for '$resolve_file'."
  #  resolve $resolve_file until it is no longer a symlink
  while [ -h "$resolve_file" ]; do 
    link_target="$(readlink "$resolve_file")"
    if [[ $link_target == /* ]]; then
      message "File '$resolve_file' is an absolute symlink to '$link_target'"
      resolve_file="$link_target"
    else
      directory_name="$( dirname "$resolve_file" )" 
      message "File '$resolve_file' is a relative symlink to '$link_target' (relative to '$directory_name')"
      #  If $SOURCE was a relative symlink, we need to resolve 
      #+ it relative to the path where the symlink file was located
      resolve_file="$directory_name/$link_target"
    fi
  done
  message "File is '$resolve_file'" 
  resolve_dir_name="$( dirname "$resolve_file")"
  directory_name="$( cd -P "$( dirname "$resolve_file" )" && pwd )"
  if [ "$directory_name" != "$resolve_dir_name" ]; then
    message "$description '$directory_name' resolves to '$directory_name'"
  fi
  message "$description is '$directory_name'"
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
      local move_message="$(mv -v "$1" "$1.$filecount")"
      message "$move_message"
    fi
}

#
# Write submission script
#

write_submit_script ()
{
    message "Remote mode selected, creating PBS job script instead."
    local submitscript_filename="${1%.*}.sh"
    backup_if_exists "$submitscript_filename"

    cat > "$submitscript_filename" <<-EOF
#!/bin/sh
#PBS -l nodes=1:ppn=$OMP_NUM_THREADS
#PBS -l mem=$OMP_STACKSIZE
#PBS -l walltime=$requested_walltime
#PBS -N ${submitscript_filename%.*}
#PBS -m ae
#PBS -o $submitscript_filename.o\${PBS_JOBID%%.*}
#PBS -e $submitscript_filename.e\${PBS_JOBID%%.*}

echo "This is $nodename"
echo "OS $operatingsystem ($architecture)"
echo "Running on $OMP_NUM_THREADS $processortype."
echo "Calculation with xtb from $PWD."
echo "Working directry is \$PBS_O_WORKDIR"
cd "\$PBS_O_WORKDIR"

export PATH="\$PATH:$XTBHOME"
export XTBHOME="$XTBHOME" 
export OMP_NUM_THREADS="$OMP_NUM_THREADS"
export MKL_NUM_THREADS="$MKL_NUM_THREADS"
export OMP_STACKSIZE="$OMP_STACKSIZE"  

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

#
# Get some informations of the platform
#
nodename=$(uname -n)
operatingsystem=$(uname -o)
architecture=$(uname -p)
processortype=$(grep 'model name' /proc/cpuinfo|uniq|cut -d ':' -f 2)

#
# Set some Defaults
#
OMP_NUM_THREADS=4
MKL_NUM_THREADS=4
OMP_STACKSIZE=1000m
xtb_callname="xtb"
requested_walltime="24:00:00"
run_interactive="yes"

stay_quiet=1        # Suppress logging messages for finding the script path
[[ "$1" == "debug" ]] && stay_quiet=0 && shift # Secret debugging switch

scriptpath="$(get_bindir "$0" "Directory of runxtb")"
runxtbrc="$scriptpath/.runxtbrc"

stay_quiet=0        # Reset to default logging

if [[ -f "$runxtbrc" && -r "$runxtbrc" ]] ; then
  . "$runxtbrc"
  message "Applied configuration file settings."
fi

OPTIND=1

while getopts :p:m:w:o:sSiB:qh options ; do
  case $options in
    #hlp OPTIONS:
    #hlp   Any switches used will overwrite rc settings,
    #hlp   for the same options, only the last one will have an eefect.
    #hlp 
    #hlp   -p <ARG> Set number of professors
    p) validate_integer "$OPTARG"
       OMP_NUM_THREADS="$OPTARG"
       MKL_NUM_THREADS="$OPTARG"
       ;;
    #hlp   -m <ARG> Set the number of memories (in megabyte?)
    m) validate_integer "$OPTARG"
       OMP_STACKSIZE="${OPTARG}m"
       ;;
    #hlp   -w <ARG> Set the walltime when sent to the queue
    w) requested_walltime=$(format_walltime_or_exit "$OPTARG")
       ;;
    #hlp   -o <ARG> Trap the output into a file called <ARG>.
    o) output_file="$OPTARG"
       ;;
    #hlp   -s       Write PBS submitscript (instead of interactive execution)
    s) run_interactive="no"
       ;;
    #hlp   -S       Write PBS submitscript and submit it to the queue.
    S) run_interactive="sub"
       ;;
    #hlp   -i       Execute in interactive mode (overwrite rc settings)
    i) run_interactive="yes"
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

    #hlp Current settings:
    #hlp   XTBHOME="$XTBHOME" 
    #hlp   xtb_callname="$xtb_callname"
    #hlp   OMP_NUM_THREADS="$OMP_NUM_THREADS"
    #hlp   MKL_NUM_THREADS="$MKL_NUM_THREADS"
    #hlp   OMP_STACKSIZE="$OMP_STACKSIZE"
    #hlp   requested_walltime="$requested_walltime"
    #hlp   outputfile="$output_file"
    #hlp   run_interactive="$run_interactive"
  esac
done

shift $(( OPTIND - 1 ))

# Assume jobname from name of coordinate file, cut xyz (if exists)
jobname="${1%.xyz}"
# Store everything that should be passed to xtb
xtb_commands=("$@")

# Before proceeding, print a warning, that this is  N O T  the real program.
warning "This is not the original xtb program!"
warning "This is only a wrapper to set paths and variables."

# If not set explicitly, assume xtb is in same directory as script
[[ -z $XTBHOME ]] && XTBHOME="$scriptpath"

check_program_or_exit "$XTBHOME/$xtb_callname"
add_to_PATH "$XTBHOME"
export XTBHOME OMP_NUM_THREADS MKL_NUM_THREADS OMP_STACKSIZE

print_info

if [[ $run_interactive =~ ([Nn][Oo]|[Ss][Uu][Bb]) ]] ; then
  [[ -z $output_file ]] && output_file="$jobname.subxtb.out"
  backup_if_exists "$output_file"
  submitscript=$(write_submit_script "$output_file")
  if [[ $run_interactive =~ [Ss][Uu][Bb] ]] ; then
    qsub "$submitscript"
  else
    message "Created submit PBS script, to start the job:"
    message "  qsub $submitscript"
  fi
elif [[ $run_interactive == "yes" ]] ; then
  if [[ -z $output_file ]] ; then 
    $xtb_callname "${xtb_commands[@]}" 
    exit $? # Carry over exit status
  else
    backup_if_exists "$output_file"
    $xtb_callname "${xtb_commands[@]}" > "$output_file"
  fi
else
  fatal "Unrecognised mode; abort."
fi

exec 3>&-
message "Wrapper script completed."
#hlp ===== End of Script ===== (Martin, 2018/02/13)
