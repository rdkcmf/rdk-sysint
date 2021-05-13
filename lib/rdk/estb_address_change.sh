#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2018 RDK Management, LLC. All rights reserved.
# ============================================================================

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
                sh /lib/rdk/iptables_init "Refresh"
            else
                echo "`/bin/timestamp` No ESTB IP Change occured Previous IP:$PREVIOUS_IP Current IP : $CURRENT_IP" >> $LOG_FILE
            fi
        else
            # Store received new IP
            echo "$CURRENT_IP" > /tmp/ipv6_address.txt
        fi
    fi
fi

