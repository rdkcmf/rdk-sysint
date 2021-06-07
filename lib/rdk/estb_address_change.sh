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


if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /lib/rdk/commonUtils.sh ];then
     . /lib/rdk/commonUtils.sh
fi

LOG_FILE="/opt/logs/dibbler.log"
CURRENT_IP=""

cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5

uptime=`cat /proc/uptime | awk '{print $1}'`

# Global Address Add Event
if [ "$GATEWAY_DEVICE" == "yes" ] && [ "$cmd" == "add" ] && [ "$flags" == "global" ];then
    if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" ]] && [[ "$addr" != "$ESTB_ECM_COMMN_IP" && "$addr" != "$DEFAULT_ESTB_IP" ]];then
        CURRENT_IP="$addr"
        echo "`/bin/timestamp` CURRENT IP: $CURRENT_IP" >> $LOG_FILE

        # Check Previous stored IP
        if [ -f /tmp/ipv6_address.txt ]; then
            PREVIOUS_IP=$(cat /tmp/ipv6_address.txt)
            if [ "$CURRENT_IP" != "$PREVIOUS_IP" ] && [ "$CURRENT_IP" != "" ] && [ "$PREVIOUS_IP" != "" ]; then
                echo "$CURRENT_IP" > /tmp/ipv6_address.txt
                echo "`/bin/timestamp` Identified ESTB IP Change. Previous IP : $PREVIOUS_IP Current IP : $CURRENT_IP, uptime is $uptime milliseconds" >> $LOG_FILE
               
                # Log IP Acquired Event in milestones 
                if [ -f /lib/rdk/logMilestone.sh ]; then
                    sh /lib/rdk/logMilestone.sh "IP_ACQUISTION_COMPLETED"
                fi

                #Restart dropbear
                if [ -f /etc/os-release ];then
                    echo "`/bin/timestamp` Restarting dropbear.service" >> $LOG_FILE
                   /bin/systemctl restart dropbear.service
                fi

                # Update ESTB IP Bound FireWall
                echo "`/bin/timestamp` Renewing firewal rules bound to ESTB IP " >> $LOG_FILE
                /bin/busybox sh /lib/rdk/iptables_init "Refresh"
            else
                echo "`/bin/timestamp` No ESTB IP Change occured Previous IP:$PREVIOUS_IP Current IP : $CURRENT_IP" >> $LOG_FILE
            fi
        else
            # Store received new IP
            echo "$CURRENT_IP" > /tmp/ipv6_address.txt
        fi
    fi
fi

