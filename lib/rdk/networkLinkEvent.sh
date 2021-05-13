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
