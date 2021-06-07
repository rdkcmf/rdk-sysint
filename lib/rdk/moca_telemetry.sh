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

if [  -f /etc/os-release ]; then
    export MIBS=ALL
else
    export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
    export MIBS=ALL
    export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
    export PATH=$PATH:$SNMP_BIN_DIR:
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
fi

# MoCA Version 1.1 is 11 and 2.0 is 20
MOCA_VERSION=$1

if [ $MOCA_VERSION -eq 20 ]; then
   MIB=MOCA20-MIB
else
   MIB=MOCA11-MIB
fi

MOCA_LOG_FILE=mocalog.txt
LOG_PATH=/opt/logs
snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
if [ ! "$snmpCommunityVal" ]; then echo "Missing the SNMP community string, existing..!"; exit 1; fi

if [  -f /etc/os-release ]; then
    echo Dumping Moca Telemetry parameters
    linkStatus=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfStatus | cut -d "=" -f2 | tr -d ' '`
    if [ "$linkStatus" == "linkUp" ]; then
        currentNcMacAddr=""
        currentNodeId=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNodeID | cut -d "=" -f2 | sed "s/ //g"`
        currentNcId=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNC | cut -d "=" -f2 | sed "s/ //g"`
        echo TELEMETRY_MOCA_STATUS:UP
        echo TELEMETRY_MOCA_NC_NODEID:$currentNcId
        echo TELEMETRY_MOCA_NODEID:$currentNodeId

        if [ "$currentNodeId" -eq  "$currentNcId" ]; then
            currentNcMacAddr=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfMacAddress | cut -d "=" -f2 | sed "s/ //g"`
            echo TELEMETRY_MOCA_NC_MAC:$currentNcMacAddr
            echo TELEMETRY_MOCA_IS_CURRENT_NODE_NC:1
        else
            currentNcMacAddr=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeMacAddress | awk -F '::' '{print $2}' | sed "s/mocaNodeMacAddress/\nTELEMETRY_MOCA_NC_MAC/g" | grep -rn ".*\.$currentNcId" | cut -d "=" -f2 | sed "s/ //g"`
            echo TELEMETRY_MOCA_NC_MAC:$currentNcMacAddr
            echo TELEMETRY_MOCA_IS_CURRENT_NODE_NC:0
        fi

        echo TELEMETRY_MOCA_TOTAL_NODE:`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNumNodes | cut -d "=" -f2 | sed "s/ //g"`
        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeTxGcdRate | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYRATE:$rate
        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeRxPower | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYRXRATE:$rate
        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeTxPowerReduction | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYTXRATE:$rate
    else
        echo TELEMETRY_MOCA_STATUS:DOWN
    fi
else
    echo $(date) Dumping Moca Telemetry parameters >> $LOG_PATH/$MOCA_LOG_FILE
    linkStatus=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfStatus | cut -d "=" -f2 | tr -d ' '`
    if [ "$linkStatus" == "linkUp" ]; then
        currentNcMacAddr=""
        currentNodeId=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNodeID | cut -d "=" -f2 | sed "s/ //g"`
        currentNcId=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNC | cut -d "=" -f2 | sed "s/ //g"`
        echo TELEMETRY_MOCA_STATUS:UP >> $LOG_PATH/$MOCA_LOG_FILE
        echo TELEMETRY_MOCA_NC_NODEID:$currentNcId  >> $LOG_PATH/$MOCA_LOG_FILE
        echo TELEMETRY_MOCA_NODEID:$currentNodeId  >> $LOG_PATH/$MOCA_LOG_FILE

        if [ "$currentNodeId" -eq  "$currentNcId" ]; then
            currentNcMacAddr=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfMacAddress | cut -d "=" -f2 | sed "s/ //g"`
            echo TELEMETRY_MOCA_NC_MAC:$currentNcMacAddr  >> $LOG_PATH/$MOCA_LOG_FILE
            echo TELEMETRY_MOCA_IS_CURRENT_NODE_NC:1  >> $LOG_PATH/$MOCA_LOG_FILE
        else
            currentNcMacAddr=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeMacAddress | awk -F '::' '{print $2}' | sed "s/mocaNodeMacAddress/\nTELEMETRY_MOCA_NC_MAC/g" | grep -rn ".*\.$currentNcId" | cut -d "=" -f2 | sed "s/ //g"`
            echo TELEMETRY_MOCA_NC_MAC:$currentNcMacAddr  >> $LOG_PATH/$MOCA_LOG_FILE
            echo TELEMETRY_MOCA_IS_CURRENT_NODE_NC:0  >> $LOG_PATH/$MOCA_LOG_FILE
        fi

        echo TELEMETRY_MOCA_TOTAL_NODE:`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaIfNumNodes | cut -d "=" -f2 | sed "s/ //g"`  >> $LOG_PATH/$MOCA_LOG_FILE

        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeTxGcdRate | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYRATE:$rate >> $LOG_PATH/$MOCA_LOG_FILE
        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeRxPower | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYRXRATE:$rate >> $LOG_PATH/$MOCA_LOG_FILE
        rate=`snmpwalk -OQ -v 2c -c $snmpCommunityVal localhost $MIB::mocaNodeTxPowerReduction | cut -d "=" -f2`
        rate=`echo $rate | sed "s/ /,/g"`
        echo TELEMETRY_MOCA_PHYTXRATE:$rate >> $LOG_PATH/$MOCA_LOG_FILE

    else
        echo TELEMETRY_MOCA_STATUS:DOWN >> $LOG_PATH/$MOCA_LOG_FILE
    fi
fi
