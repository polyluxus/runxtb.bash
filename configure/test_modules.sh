#!/bin/bash

###
#
# This configuration script is part of
# runxtb.bash --
#   a repository to set the environment for the xtb program
# Copyright (C) 2019 - 2024 Martin C Schwarzer
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

# This script should be used to test the capabilities of modules

#
# Messaging functions
#

message ()
{
	local line
	while read -r line || [[ -n "$line" ]] ; do
		echo "INFO	 : $line"
	done <<< "$*"
}

fatal ()
{
	echo "ERROR  : $*" >&2
	exit 1
}

#
# Main
#

message "This helper script will test whether modules can be used."
cmd=$(command -v module &> /dev/null) || fatal "Command moule not available."
message "Modules are $cmd"

version=$(module --version 2>&1)
message "Available Version: $version"

message "Checking 'module purge'"
module purge || fatal "Check failed."
message "Ok."

message "Checking whether exit codes work by loading a module 'designed2fail'."
message "If this is actually a module on your system, then I'm sorry."
module load designed2fail &> /dev/null && fatal "Exit status was 0; modules will not work."
message "Ok."

message "Using modules with this script should work as asserted."

