#!/bin/sh
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
. /etc/device.properties
. /etc/include.properties

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/lib:/usr/local/lib

DS_MGR_PATH="/usr/local/bin"
IARM_BIN_PATH="/mnt/nfs/env"
DS_PERSISTENT_PATH="$APP_PERSISTENT_PATH/ds/"

if [ ! -d /dev/shm ]; then mkdir -p /dev/shm; fi

if [ ! -d $DS_PERSISTENT_PATH ]; then
     echo "The DS Host Persistent folder is missing"
     mkdir -p $DS_PERSISTENT_PATH
fi

cd $IARM_BIN_PATH
echo "`/bin/timestamp` -------IARM Managers are coming up -----"
#/dump /version.txt
if [ -f ./IARMDaemonMain ]; then
     ./IARMDaemonMain &
fi
sleep 1
echo ----------- dsMgrMain coming up ------------
if [ -f ./dsMgrMain ]; then
     ./dsMgrMain &
fi
sleep 1
echo ----------- irMgrMain coming up ------------
if [ -f ./irMgrMain ]; then
     ./irMgrMain &
fi
sleep 1
echo ----------- pwrMgrMain coming up ------------
if [ -f ./pwrMgrMain ]; then
     ./pwrMgrMain &
fi
sleep 1
echo ----------- SysMgrMain coming up ------------
if [ -f ./sysMgrMain ]; then
     ./sysMgrMain &
fi
touch /tmp/.IarmBusMngrFlag
