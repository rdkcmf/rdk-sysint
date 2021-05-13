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

. /etc/include.properties
. /etc/env_setup.sh

#==================================================================
# SCRIPT: mocaSetup.sh
# USAGE : mocaSetup.sh <interface>
# DESCRIPTION: script to start moca based on dlna & mrdvr settings
#==================================================================

initFlag=$1
interface=$2

# moca driver configuration path
mkdir -p /opt/conf

# moca setup log file
MOCA_LOG=/var/logs/mocalog.txt
#====================================================================
#                        SUB ROUTINES
#====================================================================
# start the moca and zcip processes
startMocaProcess()
{
    # alias command
    moca start
    sleep 2
    # Starting moca initializations
    echo "invoking /etc/zcip.script..." 
    busybox zcip $interface /etc/zcip.script
    sleep 3
    touch /tmp/moca_ip_acquired
    # Adding route to allow multicast packets to use eth1 - XONE-5190
    mocaif=`ifconfig | grep $interface`
    if [ "$mocaif" != "" ]; then
          route add -net 224.0.0.0 netmask 240.0.0.0 dev $interface
    else
          echo "Interface: $interface is not ready, ulticast packets to $interface will fail.."
    fi

    if [ -f /lib/rdk/mocaFrequencyTune.sh ]; then
         sh /lib/rdk/mocaFrequencyTune.sh &
    fi
}

#====================================================================
#                        MAIN ROUTINE
#====================================================================

# start the moca process
startMocaProcess
if [ -f /opt/sysproperties/mocakillswitchenable ]; then
      echo "Disabling Moca Interface" >> $MOCA_LOG
      sh $RDK_PATH/mocaInterfaceSetup.sh $interface 0
fi 
