#!/bin/bash
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


ipres=$(/sbin/ipaddr -4 show dev wlan0 | grep "169.254")

if [ "x$ipres" != "x" ]; then
	echo "Zero Config Ip Address already assigned"
	exit 0
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
