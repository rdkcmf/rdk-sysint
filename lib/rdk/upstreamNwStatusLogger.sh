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


. /etc/device.properties
. /etc/include.properties

NW_STATS_SNMP_INPUT_FILE="/opt/upstreamStats.txt"
NW_STATS_TEMP_FILE="/tmp/upstreamStats.txt"
NW_STATS_SENDQ_THRESHOLD_FILE="/opt/.sendQThreshold"

LOG_FW="$LOG_PATH/upstream_stats.log"
if [ "$LIGHTSLEEP_ENABLE" = "true" ]; then
     if [ -f $RDK_PATH/log_framework.sh ]; then
        sh $RDK_PATH/log_framework.sh "upstream_stats.log" "pipe_upstream_stats_log"
     fi
     LOG_FW="$TEMP_LOG_PATH/pipe_upstream_stats_log"
fi

sendQThresholdVal=0
# Logging should happen only if send threshold  is set via MIB DEV-NW-STATS-MIB::sendQThreshold
if [ -f $NW_STATS_SENDQ_THRESHOLD_FILE ]; then
    sendQThresholdVal=`cat $NW_STATS_SENDQ_THRESHOLD_FILE | tr -d ' '`
fi

if [ $sendQThresholdVal -gt 0 ]; then

    export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
    export MIBS=ALL
    export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
    export PATH=$PATH:$SNMP_BIN_DIR:
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib

    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    receiverPorts=`snmpwalk -OQv -v 2c -c $snmpCommunityVal localhost XcaliburClientMIB::xreConnURL | sed -e "s/.*://g" -e "s/\/.*/#/g" | tr -d '\n' '|'`
    receiverPorts=`echo $receiverPorts | sed -e 's/#$//' -e "s/#/\\\\\|/g"`
    netstat -ant | grep -e "\"$receiverPorts\"" | tr -s ' ' | cut -d ' ' -f3,4,5,6 > $NW_STATS_TEMP_FILE
    # Clear entries if sendQ threshold is 0
    sed -i '/^0/d' $NW_STATS_TEMP_FILE

    cat $NW_STATS_TEMP_FILE >> $NW_STATS_SNMP_INPUT_FILE

    if [ -f /etc/os-release ]; then
        cat $NW_STATS_TEMP_FILE
    else
        cat $NW_STATS_TEMP_FILE >> $LOG_FW
    fi

fi
