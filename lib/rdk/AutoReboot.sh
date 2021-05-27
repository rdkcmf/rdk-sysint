#!/bin/sh
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management,LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# Author: Livin Sunny livin_sunny@comcast.com
# ============================================================================

set -x

. /lib/rdk/RebootCondition.sh

. /etc/include.properties
. /etc/device.properties

REBOOT_WAIT="/tmp/AR/.waitingreboot"

## File containing common firmware download state variables
STATUS_FILE="/opt/fwdnldstatus.txt"

reboot_device_success=0
AutoReboot=false

#if maintaince Mgr is enabled ,don't update "AutoReboot" based on tr181 param
if [ "x$ENABLE_MAINTENANCE" != "xtrue" ]
then 
    AutoReboot=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AutoReboot.Enable 2>&1 > /dev/null)
fi

while [ $reboot_device_success -eq 0 ]; do
    if [ "$AutoReboot" == "true" ];then

        # Check the Reboot status
        # We use the sw update reboot status
	inprogress_status=$(cat $STATUS_FILE | grep "Status" | cut -d '|' -f2)
	if [ "x$inprogress_status" == "xDownload In Progress" ] || [ "x$inprogress_status" == "xFlashing In Progress" ] || [ "x$inprogress_status" == "xESTB in progress" ]; then
	        http_reboot_status=$(cat $STATUS_FILE | grep "Reboot" | cut -d '|' -f2)
		if [ "$http_reboot_status" == "true" ]; then
	            #this means Immediate reboot flag is set in deviceInitiatedFwDownload
		    #So not need to do it in AutoReboot.
	            touch $REBOOT_WAIT
		    exit
	        fi
	fi

        #Check the power state
        /QueryPowerState > /tmp/.autoreboot_pwrstate
        cat /tmp/.autoreboot_pwrstate | grep "ON" >> "$AR_LOG_FILE"
        if [ $? -eq 0 ]
        then
            echo "$(timestamp) [Auto Reboot] Sending Notification" >> "$AR_LOG_FILE"
            # power is ON so inform the User
            REQUEST='{"jsonrpc":"2.0","id":"3","method":"org.rdk.System.2.fireFirmwarePendingReboot","params":{}}'
            OPTION="--request POST --data"
            n=3
            #Retry 3 times in case we if we didnt succeed.
            until [ "$n" -le 0 ]
            do
                # notify the application we are waiting for 10 min
                # CURL_CMD="curl --header "Content-Type: application/json" --request POST --data \
                # '{"jsonrpc":"2.0","id":"3","method":"org.rdk.System.1.fireFirmwarePendingReboot","params":{}}' http://127.0.0.1:9998/jsonrpc"
                result=$( curl --header "Content-Type: application/json" $OPTION $REQUEST http://127.0.0.1:9998/jsonrpc )

                #extract the result {"jsonrpc":"2.0","id":3,"result":{"success":true}}
                status=$( echo "$result" | sed 's/.*success":\(.*\)}}.*/\1/' )

                #check if the notification was success
                if [ "x$status" = "xtrue" ]
                then
                    echo "$(timestamp) [Auto Reboot] Notification SUCCESS" >> "$AR_LOG_FILE"
                    echo "$(timestamp) [Auto Reboot] Sleeping for 10 Min." >> "$AR_LOG_FILE"
                    #wait for 10 min
                    sleep "$DEVICE_WAITING_TIME"
                    break;
                else
                    echo "$(timestamp) [Auto Reboot] CRITICAL ERROR Failed to notify the APP" >> "$AR_LOG_FILE"
                    echo "$(timestamp) [Auto Reboot] Retrying for $n times after 5 Seconds" >> "$AR_LOG_FILE"
                    n=$((n-1))
                    sleep 5
                fi
            done
            #check the status of fwDelayReboot
            fwDelayReboot=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AutoReboot.fwDelayReboot 2>&1 > /dev/null)
            # if 0 no response; go for Reboot
            if [ "$fwDelayReboot" -ne 0 ]
            then
                #we received a delay reboot value
                echo "$(timestamp) [Auto Reboot] User Delayed the reboot by $fwDelayReboot seconds" >> "$AR_LOG_FILE"
                touch "$DEFER_REBOOT"
                sleep "$fwDelayReboot"
            fi
        fi
        if [ ! -e "$ABORT_REBOOT" ]
        then
            # HERE WE REBOOT THE DEVICE
            echo "$(timestamp) [Auto Reboot] Preparing to AutoReboot the Device !! " >> "$AR_LOG_FILE"
            echo "$(timestamp) setting LastRebootReason as AutoReboot" >> "$AR_LOG_FILE"
            #setting the last reboot reason
            echo "$(timestamp) Rebooting the Deivce !! " >> "$AR_LOG_FILE"
            sh /rebootNow.sh -s "`basename $0`" -o "AutoRebooting the device after Maintenance Window"
            reboot_device_success=1
        else
            reboot_device_success=0
            echo "$(timestamp) [Auto Reboot] Aborted by user" >> "$AR_LOG_FILE"
            rm -rf "$ABORT_REBOOT"
            rm -rf "$DEFER_REBOOT"
        fi
    else
        #this means AutoRebootEnable = false.
        echo "$(timestamp) [Auto Reboot] AutoRebootEnable is set to false - not triggering reboot" >> "$AR_LOG_FILE" 
        if [ "x$ENABLE_MAINTENANCE" != "xtrue" ]
        then
            Removecron
        fi
        exit
    fi
done # While loop for reboot manager

