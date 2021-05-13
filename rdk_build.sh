#!/bin/bash
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
#
#change to test rdk_setup

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
ENABLE_GST_1=0

#Enable for PRNG & Intel XG1
if [ "$RDK_PLATFORM_DEVICE" == "rng150" ] || [ "x$RDK_PLATFORM_SOC" == "xintel" ] ;then
    ENABLE_GST_1=1
fi

if [ "x$BUILD_CONFIG" == "xhybrid-legacy" ];then
    export BUILD_CONFIG="hybrid"
    ENABLE_GST_1=0
fi


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
    #cd $RDK_SOURCE_PATH
    if [ "x$RDK_PACKAGE_TYPE" = "xDEV" ]; then
        cp $RDK_PROJECT_ROOT_PATH/sysint/generic/build/config/dcm.properties.dev $RDK_FSROOT_PATH/etc/dcm.properties
    elif [ "x$RDK_PACKAGE_TYPE" = "xCQA" ]; then
        cp $RDK_PROJECT_ROOT_PATH/sysint/generic/build/config/dcm.properties.gslb $RDK_FSROOT_PATH/etc/dcm.properties
    else
        # Common dcm.properties for VBN/PROD images
        cp $RDK_PROJECT_ROOT_PATH/sysint/generic/build/config/dcm.properties.vbn $RDK_FSROOT_PATH/etc/dcm.properties
    fi

    cd $RDK_PROJECT_ROOT_PATH/sysint/devspec
    sh build.sh 1 clean
}

function rebuild()
{
    clean
    build
}

function install()
{
   cd $RDK_PROJECT_ROOT_PATH/sysint/devspec
   sh build.sh install ${BUILD_CONFIG}

    if [[ "$ENABLE_GST_1" -eq "1" ]]; then
        # Update the etc/profile to have GStreamer-1.0 in GST_PLUGIN_PATH
        find ${RDK_FSROOT_PATH}/etc/ -iname profile -type f -exec sed -i -e "s|gstreamer-0.10|gstreamer-1.0|g" "{}" \; -print
        echo "export GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0" >>${RDK_FSROOT_PATH}/etc/profile

        # Update the run.sh to have proper exports
        find ${RDK_FSROOT_PATH}/etc/ -iname run.sh -type f -exec sed -i -e "s|gstreamer-0.10|gstreamer-1.0|g" "{}" \; -print

        # Update the rdk launch scripts to have proper exports of GStreamer version
        grep -lr "gstreamer-0.10" ${RDK_FSROOT_PATH}/lib/rdk/ | xargs sed -i -e "s|gstreamer-0.10|gstreamer-1.0|g"
    fi
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

