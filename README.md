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

The simplest way to install it is to copy it to nthe same directory as the 
program, and use a symbolic link for execution, e.g. in `~/bin`.  
You can also use it in your working directory, if you set the path to the
executable manually on the command line (see below).  
The last option is to configure the script with the `.runxtbrc` file 
(example included), setting the default parameters. 
This file needs to be in the same directory as the script.

## Usage and options

Simply call the the script as if you would call the original program:
```
runxtb.sh [script options] <coord_file> [xtb options]
```
Any switches used will overwrite rc settings, 
which take precedence over the built-in defaults.
For the same options/ modes, only the last one will have an effect.

The following script options are available:

 * `-p <ARG>` Specify the number of processors to be used.  
              This will set `OMP_NUM_THREADS=<ARG>` and `MKL_NUM_THREADS=<ARG>`.
              (Default defined within script is `4`.)
 * `-m <ARG>` Secify the memory to be used (in megabyte).
              This will set `OMP_STACKSIZE=<ARG>m`. (Default in script is `1000m`.)
 * `-o <ARG>` Trap the output (not the errors) of `xtb` into a file called `<ARG>`.
              No output will be created in interactive mode by default.
              In non-interactive mode it will be derived from the first argument given
              after the options, which should be `coord_file`.
 * `-s`       Write PBS submitscript instead of interactive execution.
              This needs to be sumbitted separately, useful if review might be necessary.
 * `-S`       Write PBS submitscript and directly submit it to the queue.
 * `-i`       Execute in interactive mode. 
              This option is useful to overwrite rc settings.
 * `-B <ARG>` Set the absolute path to the executable `xtb` to `<ARG>`.
              The name of the program needs to be included.
 * `-q`       Suppress any logging messages of the script.
              If specified twice, it will also suppress warnings,
              if specified more than twice, it will suppress also errors.
 * `-h`       Prints a small help text.

## Included files

The following files come with this script:

 * `runxtb.sh` The main wrapper.
 * `runxtb.rc` An example set-up file.
 * `.runxtbrc` A symbolic link to the above file, so that the script may find it.
 * `xtb.dummy` A tiny bash script only for testing. 
   This will only echo `<coord_file> [options]` verbatim.
 * `xtb` A symbolic link to the above dummy file, so that the script may find it.
 * `README.md` This file.

(Martin, 2018/02/13)
