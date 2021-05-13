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
##########################################################################

ZCIP_SCRIPT_PATH="/etc"

. /etc/include.properties
. $RDK_PATH/utils.sh
. /etc/device.properties

ret=`checkWiFiModule`
if [ $ret -eq 1 ]; then
#        /sbin/ifconfig $MOCA_INTERFACE down
        touch /tmp/wifi-on
        interface=$WIFI_INTERFACE
else
        interface=$MOCA_INTERFACE
fi


if [ ! -f /opt/ip.$interface ]; then
        zcip -f -q -v ${interface} $ZCIP_SCRIPT_PATH/zcip.script
else
		checkIP=$(grep "169.254" /opt/ip.$interface)
		status=$?
		if [ $status -eq 0 ]; then
				zcip -q -v -f -r `cat /opt/ip.${interface}` ${interface} $ZCIP_SCRIPT_PATH/zcip.script
		else
				rm /opt/ip.$interface
				zcip -f -q -v ${interface} $ZCIP_SCRIPT_PATH/zcip.script
		fi	
fi
