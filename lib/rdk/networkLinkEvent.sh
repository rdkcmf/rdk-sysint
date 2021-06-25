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


# Network Interface - $1
# Network Interface Status - $2 (add/delete/up/down)

if [ "$#" -eq 2 ];then
    interfaceName=$1
    interfaceStatus=$2

    # process only add/delete events
    if [ "$interfaceStatus" == "up" ] || [ "$interfaceStatus" == "down" ]; then
        exit
    fi

    if [ -f /lib/systemd/system/pni_controller.service ]; then
        . /etc/device.properties
        if [ "$interfaceName" == "$ETHERNET_INTERFACE" ]; then
            if systemctl is-active netsrvmgr.service > /dev/null || systemctl is-failed netsrvmgr.service > /dev/null; then
                echo "$(date '+%Y %b %d %H:%M:%S.%6N') [networkLinkEvent.sh#$$]: $* - systemctl restart pni_controller.service &" >> /opt/logs/netsrvmgr.log
                systemctl restart pni_controller.service &
            fi
        fi
    fi

    #Skip event received before ipremote boot scan
    sh /lib/rdk/enable_ipremote.sh $interfaceName $interfaceStatus

    #WebInspector script
    sh /lib/rdk/enableWebInspector.sh $interfaceName $interfaceStatus

    #WebAutomation script
    sh /lib/rdk/enableWebAutomation.sh $interfaceName $interfaceStatus

else
    echo "Failed due to invalid arguments ..."
    echo "Usage : $0 InterfaceName InterfaceStatus"
fi
