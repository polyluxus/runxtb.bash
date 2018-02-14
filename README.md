# runxtb.bash

This script provides a wrapper for the 
extended tight-binding semi-empirical program package
[xtb](https://www.chemie.uni-bonn.de/pctc/mulliken-center/software/xtb/xtb) 
from Stefan Grimme's group at the University of Bonn.

It makes it unnecessary to set environment variables like 
`OMP_NUM_THREADS`, `MKL_NUM_THREADS`, `OMP_STACKSIZE`, and `XTBHOME`. 
It also provides a mechanism to automatically trap the output
that would normally go to standard out.

## Installation

The simplest way to install it is to copy it to the same directory as the 
program, and use a symbolic link for execution, e.g. in `~/bin`.
There is - in principle - no need to configure it.  
You can also use it from any directory, if you set the path to the
executable manually on the command line (see below).  
Lastly, and my personally preferred way, is to configure the script.
It will first look for a file `.runxtbrc`, 
then for a file `runxtb.rc` (example included), 
in the directories in following order:
`scriptpath`, `\home\$USER`, and `$PWD`.
If `.runxtbrc` is found, it won't look for `runxtb.rc`.
The last one found will be used to set the (local) default parameters. 
This gives the possibility that every user may configure local settings.
A summary of the settings to be used are given with the `-h` option.

This directory is currently set up to find `runxtb.rc` and should test 
sucessfully without any changes.

## Usage and options

Simply call the the script as if you would call the original program:
```
runxtb.sh [script options] <coord_file> [xtb options]
```
Any switches used will overwrite rc settings, 
which take precedence over the built-in defaults.
For the same options/ modes, only the last one will have an effect,
e.g. specifying `-sSi` wil run interactively.

The following script options are available:

 * `-p <ARG>` Specify the number of processors to be used.  
              This will set `OMP_NUM_THREADS=<ARG>` and `MKL_NUM_THREADS=<ARG>`.
              (Default defined within the script is `4`.)
 * `-m <ARG>` Secify the memory to be used (in megabyte).
              This will set `OMP_STACKSIZE=<ARG>m`. (Default in the script is `1000m`.)
 * `-o <ARG>` Trap the output (without errors) of `xtb` into a file called `<ARG>`.
              No output file will be created in interactive mode by default.
              In non-interactive mode it will be derived from the first argument given
              after the options, which should be `coord_file`.
 * `-s`       Write PBS submitscript instead of interactive execution.
              This resulting file needs to be sumbitted separately, 
              which might be useful if review is necessary 
              (configuration option `run_interactive=no`).
 * `-S`       Write PBS submitscript and directly submit it to the queue
              (configuration option `run_interactive=sub`).
 * `-i`       Execute in interactive mode. (Default without configuration.)
              This option is useful to overwrite rc settings
              (configuration option `run_interactive=yes`).
 * `-B <ARG>` Set the absolute path to the executable `xtb` to `<ARG>`.
              The name of the program needs to be included.
              In the configuration file these are separated.
 * `-q`       Suppress any logging messages of the script.
              If specified twice, it will also suppress warnings,
              if specified more than twice, it will suppress also errors.
 * `-h`       Prints a small help text and current configuration.

## Included files

The following files come with this script:

 * `runxtb.sh` The main wrapper.
 * `runxtb.rc` An example set-up file.
 * `xtb.dummy` A tiny bash script only for testing. 
   This will only echo `<coord_file> [options]` verbatim.
 * `README.md` This file.

## Exit status

The script carries over the exit statusses of its dependencies.
In interactive mode that is the exit status of `xtb`.
In submission mode it is the exit status of `qsub`.
In all other cases it will be `0` if everything went according to plan,
or `1` if there was a problem.  
The dummy script `xtb.dummy` always exits with `2`.

## Debug

Things go wrong.  
We need to accept that. 
To find out more, using `debug` as the very first argument gives more information.
For example:
```
runxtb.sh debug -p1 -qq -s  dummy.xyz -opt -gfn
```

(Martin, 2018/02/14)
