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



. /etc/default/mocaconfig
. /etc/include.properties
. /etc/device.properties

MOCA_BIN="/usr/bin/rmh"
MOCA_BIN_OEM="/usr/bin/rmh.oem_overrides"
TR181_BIN="/usr/bin/tr181"
TR181_DISABLEMOCA_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DisableMoca.Enable"

checkMocaStatus()
{
    status=0
    MocaStatus=`$MOCA_BIN RMH_Self_GetEnabled | tr A-Z a-z`
    if [ "$MocaStatus" != "false" ]; then
        status=1
    fi

    echo "MoCA service status received: $MocaStatus"
    return $status
}

if [ ! -f "$MOCA_BIN" ]; then
    echo "$MOCA_BIN file not found..!!"
else
    #####################  Set MoCA defaults #####################
    checkMocaStatus
    if [ $? -eq 1 ]; then
        echo "Checking Moca is stopped before setting defaults"
        $MOCA_BIN stop
    fi

    echo "Setting the default RMH settings for Moca"
    $MOCA_BIN RMH_Self_RestoreRDKDefaultSettings
    sleep 1
    if [ -f "$MOCA_BIN_OEM" ]; then
        echo "Setting the device specific RMH settings for moca"
        $MOCA_BIN_OEM
    else
        echo "No device specific MoCA settings"
    fi

    if [ -f "$TR181_BIN" ]; then
        disableMoca=`$TR181_BIN -g $TR181_DISABLEMOCA_NAME  2>&1 > /dev/null`
    else
        echo "$TR181_BIN file not found..!!!"
    fi

    mkdir -p /opt/conf
    ##################### Exit if MoCA disabled via RDC #####################
    if [ "$disableMoca" = "true" ] ; then
        echo "DisableMoCA set as $disableMoca in RFC. Refusing to start"
    else
        ##################### Actually start MoCA #####################
        echo "Starting the Moca using rmh"
        $MOCA_BIN start
     
    fi
    echo "Setting IP interface for Moca"
    ip link set dev ${MOCA_INTERFACE} up
    sleep 1
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ifconfig ${MOCA_INTERFACE}:0 127.0.0.2
    sh /lib/rdk/vidiPathControl.sh start_udhcpc
    sh /lib/rdk/getMocaLocalLinkIp.sh
    sh /lib/rdk/zcip.sh
fi
