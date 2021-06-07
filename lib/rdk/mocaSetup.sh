#!/bin/sh
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
