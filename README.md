# runxtb.bash

This script provides a wrapper for the 
extended tight-binding semi-empirical program package
[xtb](https://www.chemie.uni-bonn.de/pctc/mulliken-center/software/xtb/xtb) 
(version 6.0 or later) 
from Stefan Grimme's group at the University of Bonn
(contact: xtb{at}thch.uni-bonn.de).
It is available via [GitHub](https://github.com/grimme-lab/xtb).

It makes it unnecessary to set environment variables like 
`OMP_NUM_THREADS`, `MKL_NUM_THREADS`, `OMP_STACKSIZE`, and `XTBPATH` globally,
for example via the `.bashrc`. 
It also provides a mechanism to automatically trap the output
that would normally go to standard out (i.e. the terminal).
Additionally it can be used to create scripts to submit it to a queueing system.

## Installation

My personally preferred way to install it, is to clone the git repository 
(or download the source code) and configure the script.
There is a configure script, which will prompt for the values 
with a short description.
It will also try to recover values from a previous configuration
in the same locations as outlined below.
I recommend deleting old configuration files before updating to version > 0.2.0 of this script.

The wrapper script will first look for a file `.runxtbrc`, 
then for a file `runxtb.rc` (example included), 
in directories of the following order:
`scriptpath`, `/home/$USER`, `/home/$USER/.config`, and `$PWD`.
If a `.runxtbrc` is found, it will skip `runxtb.rc`.
The last file found will be used to set the (local) default parameters. 
This gives the possibility that every user may configure local settings,
it also gives the possibilities to overwrite settings for one directory only.
A summary of the settings to be used are given with the `-h` option.

This directory is currently set up to find `runxtb.rc` and should test 
sucessfully without any changes.

There used to be a way to install thes script alongside with the executable of xtb, 
without further need to configure it, and place a symbolic link to it
in a directory included in `PATH`, e.g. in `~/bin`.
I have not tested this set-up for a long time, so I am not sure if the recent edits have broken it.
(I would not recommend trying it.)   

## Updating

Updating should be as easy as pulling the new version of the repository. 
If the script has been configured with `.runxtbrc`, 
a file that won't be overwritten via git, 
then these settings should be reviewed.
When updating from a pre 0.2.0 version of this script, 
I reommend deleting old configuration files.
While I try to avoid renaming internal options, 
it was necessary due to the changes in the XTB distribution.
In any case, a new feature may require new settings;
hence, this should also be checked.

## Usage and options

Simply call the the script as if you would call the original program:
```
runxtb.sh [script options] <coord_file> [xtb options]
```
Any switches used will overwrite rc settings, 
which take precedence over the built-in defaults.
For the same options/ modes, only the last one will have an effect,
e.g. specifying `-sSi` will run interactively (immediately).

The following script options are available:

 * `-p <ARG>` Specify the number of processors to be used.  
              This will set `OMP_NUM_THREADS=<ARG>` and `MKL_NUM_THREADS=<ARG>`.
              (Default defined within the script is `4`.)
 * `-m <ARG>` Secify the memory to be used (in megabyte).
              This will set `OMP_STACKSIZE=<ARG>`. (Default in the script is `1000`.)
 * `-o <ARG>` Trap the output (without errors) of `xtb` into a file called `<ARG>`.
              The default behaviour in non-interactive mode is to guess the filename:
              If the first argument given after the script options is a readable file,
              i.e. a `coord_file` or `coords.xyz`, the job- and output-name will be based on that.
              If the executed program is not `xtb` (`-C` switch), it will be based on that.
              As fallback it will be derived from the parent working directory.
              If necessary, the automatic generation of the file name can be also be triggered 
              with `-o ''` (space is important), `-o0`, or `-o auto`.
              This may be useful to overwrite any previous settings.
              To send the output stream to standad output, e.g. the terminal, settings can be overwritten
              with `-c stdout`, or `-c -`.
              (configuration option `output_file='',0,auto|stdout,-`)
 * `-s`       Write a submitscript instead of interactive execution (PBS is default).
              This resulting file needs to be sumbitted separately, 
              which might be useful if review is necessary 
              (configuration option `run_interactive=no`).
 * `-S`       Write submitscript and directly submit it to the queue.
              This also requires setting a queueing system with `-Q` (see below).
              (configuration option `run_interactive=sub`).
 * `-Q <ARG>` Set a queueing system for which the submitscript should be prepared.
              Currently supported are `pbs-gen`, `slurm-gen`, `slurm-rwth`, `bsub-gen`, and `bsub-rwth` 
              (configuration option `request_qsys=<ARG>`).
              The `*rwth` suffix will test a few more options and will set some constraints according to
              the recommendations of the RWTH IT centre.
 * `-P <ARG>` Account to project `<ARG>`, which will also (currently) trigger
              `-Q bsub-rwth` to be set. It will not trigger `-s`/`-S`.
 * `-M`       Use preinstalled modules instead of paths. 
              This option also needs a specified module or a list of modules, 
              which can be set with `-l <ARG>`(see below) or in the rc
              (configuration option `use_modules=true`).
 * `-l <ARG>` Specify a module to be used. This will also invoke `-M`.
              The option may be specified multiple times to create a list (stored as an array).
              If `<ARG>` is `0`, the list will be deleted first.
              The modules (if more than one) need to be specified in the order they have to be loaded.
              This can also be set in the rc 
              (configuration option `load_modules[<N>]=<ARG>` with `<N>` being the integer load order).
 * `-i`       Execute in interactive mode. (Default without configuration.)
              This option is useful to overwrite rc settings
              (configuration option `run_interactive=yes`).
 * `-B <ARG>` Set the absolute path to the executable `xtb` to `<ARG>`.
              The name of the program needs to be included.
              In the configuration file these are separated.
 * `-C <ARG>` Set the name of the program directly.
              This may be useful to access a different executeable from the package,
              e.g. confscript (if installed, only 6.0), or crest (if installed, > 6.1).
 * `-q`       Suppress any logging messages of the script.
              If specified twice, it will also suppress warnings,
              if specified more than twice, it will suppress also errors.
 * `-h`       Prints a small help text and current configuration.
 * `-H`       Retrieve the man page of xtb of the original distribution.
 * `-X`       Retrieve the man page of xcontrol of the original distribution.

## Included files

The following files come with this script:

 * `runxtb.sh` The main wrapper.
 * `runxtb.rc` An example set-up file.
 * `xtb.dummy` A tiny bash script only for testing. 
   This will only echo `<coord_file> [options]` verbatim.
 * `crest.prepare.sh` A small script that creates a new directory 
   with a suitable `coord` file to start a `crest` run.
 * `README.md` This file.
 * `configure` A directory containing a script to configure the wrapper.
 * `guides` A directory with markup-formatted file(s), which can be used as tutorials.

## Exit status

The script `runxtb` carries over the exit statusses of its dependencies.
In interactive mode that is the exit status of `xtb`.
In submission mode it is the exit status of `qsub`, `bsub`, or `sbatch`.
In all other cases it will be `0` if everything went according to plan,
or `1` if there was a problem within the script.  
The script `crest.prepare.sh` will exit with `0` if nothing went wrong 
and a crest run can be started. If files are not present, or I/O operations
fail it will exit with `1`.  
The dummy script `xtb.dummy` always exits with `2`.

## Debug

Things go wrong.  
We need to accept that. 
To find out more, using `debug` as the very first argument gives more information.
For example:
```
runxtb.sh debug -p1 -qq -s  dummy.xyz --opt 
```
If you find anything not going as expected,
please include the debug output when submitting a bug report to the
[GitHub issue tracker](https://github.com/polyluxus/runxtb.bash/issues).

## License (GNU General Public License v3.0)

runxtb.bash - a wrapper script for xtb
Copyright (C) 2019 - 2020 Martin C Schwarzer

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

See [LICENSE](LICENSE) to see the full text.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

(Martin; 2020-03-29; wrapper version 0.4.0.rc
