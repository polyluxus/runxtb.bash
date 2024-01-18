# Using modules to control the environment

## Introduction

Running programs usually requires certain environment variables to be set to specific values.
The script provided in this repository is one way to set up the environment for xtb.
Another way is to use modules to set up these parameters, control dependencies, and possible clashes.

With environment modules it is also possible to set up different versions of an executable alongside each other.
Especially in scientific works it is important to be consistent with what versions you use throughout a project.
When multiple users work on multiple projects for long periods of time, the need arises to manage different versions.
Environment modules are a good way to maintain these versions.

However, it should be pointed out, that with modules a wrapper script like runxtb is superfluous.
Fortunately, the script provided within this repository has a few more features to offer.
For these convenience features, the script comes with an interface to access environment modules.

Unfortunately, not all environment module systems provide the capability necessary to operate within this script.
Before runxtb v0.7.0 there were workarounds for module systems, that always used the exit code 0.
Support for these system has been discontinued.

For the developement of this feature, [Lmod](https://lmod.readthedocs.io/) was used.
This choice was made as CLAIX18 (the RWTH Aachen University HPC Cluster) transitioned to this system.
For more information, visit the documentation available
[here](https://help.itc.rwth-aachen.de/service/rhr4fjjutttf/article/450d33cc19fd4e50b1dd07027e9b55bd/#user-content-toolchains).

*Disclaimer:*
I am no longer affiliated with RWTH Aachen, and I am not testing the feature in a productive manner.
I will try to support the feature in the way it is outlined in this guide.
If you find anything not going as expected,
please include detailed descriptions when submitting a bug report to the
[GitHub issue tracker](https://github.com/polyluxus/runxtb.bash/issues).

You'll find additional notes for the use of modules on CLAIX18 at the end of this document.

You can test what is expected of the `module` command with the provided script in the configure directory of this repository.

## Installation of Lmod on Ubuntu 22.04

As this is not a comprehensive guide, please see the documentation of Lmod to set it up properly.

On my laptop it was as easy as installing Lmod as a package. 
As a user with root priveleges, you can simply install it with the `apt` packet manager:
```
apt install lmod
```

Now you need to make sure that files from the `/etc/profile.d/` directory are sourced.
In many cases the default `/etc/profile` will take care of this. 
Sometimes you might want to adapt the `/etc/bash.bashrc` file, too.

If this step is completed, you may test the installation with the script provided with this repository.

## Setting up the modules

This guide assumes pretty much everything written in the [set-up guide](./set-up.md).

It should come as no surprise that running Lmod requires a properly set up environment, too.
If you'll set software up system-wide, you may want to place your module files in the default location:
`/usr/share/lmod/lmod/modulefiles`.

In other cases, where you are running software in user spaces, you may want to extend the module search path in your `~/.bashrc` 
with the following line:
```
export MODULEPATH="/home/martin/local/modulefiles/:$MODULEPATH"
```
Please adjust according to your system.

### The xtb module

Create the file `/home/martin/local/modulefiles/xtb/6.6.1.lua` with this content:
```
help([[
Description:
  xtb - An extended tight-binding semi-empirical program package. 
Homepage:
https://xtb-docs.readthedocs.io
]])

whatis("Description:  xtb - An extended tight-binding semi-empirical program package. ")
whatis("Homepage: https://xtb-docs.readthedocs.io")
whatis("URL: https://xtb-docs.readthedocs.io")
conflict("xtb")

prepend_path("LD_LIBRARY_PATH","/home/martin/local/xtb/xtb-6.6.1")
prepend_path("LIBRARY_PATH","/home/martin/local/xtb/xtb-6.6.1/lib")
prepend_path("PATH","/home/martin/local/xtb/xtb-6.6.1/bin")
prepend_path("PKG_CONFIG_PATH","/home/martin/local/xtb/xtb-6.6.1/lib/pkgconfig")
prepend_path("XDG_DATA_DIRS","/home/martin/local/xtb/xtb-6.6.1/share")
setenv("XTBHOME","/home/martin/local/xtb/xtb-6.6.1")
setenv("XTBPATH","/home/martin/local/xtb/xtb-6.6.1")
```

### The crest module
Create the file `/home/martin/local/modulefiles/crest/2.12.lua` with this content:
```
help([[
Description:
  CREST - conformer rotamer ensemble sampling tool
Homepage:
  https://crest-lab.github.io/crest-docs/
]])

whatis("Description:  CREST - conformer rotamer ensemble sampling tool")
whatis("Homepage: https://crest-lab.github.io/crest-docs/")
whatis("URL: https://crest-lab.github.io/crest-docs/")
conflict("crest")

load("xtb")
```
For this to work, crest needs to be placed alongside xtb.
If you have followed the other guide, this will be the case.
In other cases, you might need to adjust these files.

## Using modules

It is now as simple as running 
```
module load crest
```
to load the correct installation environment.

In the configuration file it is only necessary to include the module:
```
use_modules="true"
load_modules[0]="crest"
```

# Additional notes CLAIX18

As of late 2023 the following modules need to be included in the configuration file, e.g. `~/.runxtbrc`:
```
load_modules[0]="foss/2022a"
load_modules[1]="xtb/6.5.1"
load_modules[2]="CREST/2.12"
```
Unfortuantely, those modules have dependencies which have a conflict with the `intel` toolchain,
which is loaded by default. 
This is specifically the dependency on the `OpenMPI` module which is part of the `foss/2022a` toolchain.
You should therefore also use the option to purge all modules:
```
purge_modules="true"
```
This will unload all modules and allows you to include only the necessary ones.

(Martin; 2024-01-XX; wrapper version 0.6.0)
