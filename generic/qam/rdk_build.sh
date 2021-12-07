#!/bin/bash
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################
#######################################
#
# Build Framework standard script for
#
# Sysint component

# use -e to fail on any shell issue
# -e is the requirement from Build Framework
set -e


# default PATHs - use `man readlink` for more info
# the path to combined build
#export BUILD_PATH=${BUILD_PATH-`readlink -m ..`}
export BUILD_PATH=${RDK_PROJECT_ROOT_PATH}/${RDK_COMPONENT_NAME}
export COMBINED_ROOT=${BUILD_PATH}
export FSROOT=${RDK_FSROOT_PATH}
# path to build script (this script)
export SCRIPTS_PATH=${SCRIPTS_PATH-`readlink -m $0 | xargs dirname`}

# path to components sources and target
export SOURCE_PATH=${SOURCE_PATH-`readlink -m .`}
export TARGET_PATH=${TARGET_PATH-$SOURCE_PATH}

# fsroot and toolchain (valid for all devices)
export FSROOT_PATH=${FSROOT_PATH-`readlink -m $BUILD_PATH/sdk/fsroot/ramdisk`}
export TOOLCHAIN_PATH=${TOOLCHAIN_PATH-`readlink -m $BUILD_PATH/sdk/toolchain/staging_dir`}


# default component name
export COMPONENT_NAME=${COMPONENT_NAME-`basename $SOURCE_PATH`}


# parse arguments
INITIAL_ARGS=$@

function usage()
{
    set +x
    echo "Usage: `basename $0` [-h|--help] [-v|--verbose] [action]"
    echo "    -h    --help                  : this help"
    echo "    -v    --verbose               : verbose output"
    echo
    echo "Supported actions:"
    echo "      clean, install"
}

# options may be followed by one colon to indicate they have a required argument
if ! GETOPT=$(getopt -n "build.sh" -o hv -l help,verbose -- "$@")
then
    usage
    exit 1
fi

eval set -- "$GETOPT"

while true; do
  case "$1" in
    -h | --help ) usage; exit 0 ;;
    -v | --verbose ) set -x ;;
    -- ) shift; break;;
    * ) break;;
  esac
  shift
done

ARGS=$@


# component-specific vars



# functional modules

function configure()
{
    true #use this function to perform any pre-build configuration
}

function clean()
{
    true #use this function to provide instructions to clean workspace
}

function build()
{
    cd $SOURCE_PATH/sysint/generic/qam/
    sh build.sh 1 clean
}

function rebuild()
{
    clean
    build
}

function install()
{
   cd $SOURCE_PATH/sysint/generic/qam/
   sh build.sh install ${BUILD_CONFIG}
}


# run the logic

#these args are what left untouched after parse_args
HIT=false

for i in "$ARGS"; do
    case $i in
        configure)  HIT=true; configure ;;
        clean)      HIT=true; clean ;;
        build)      HIT=true; build ;;
        rebuild)    HIT=true; rebuild ;;
        install)    HIT=true; install ;;
        *)
            #skip unknown
        ;;
    esac
done

# if not HIT do build by default
if ! $HIT; then
  build
fi

