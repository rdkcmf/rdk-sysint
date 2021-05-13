#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
#


if [ -f /etc/device.properties ]; then
    . /etc/device.properties
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . /lib/rdk/commonUtils.sh
fi

export PATH=$PATH:/mnt/nfs/env
# waiting for mpeos-main to initialize before calling vlapicaller
wait_for_mpeos_main() {		
     proxyPath=`cat /mnt/nfs/env/final.properties | grep OCAP.persistent.root | cut -d "=" -f2`
     while [ 1 ]
     do
        if [ -f $proxyPath/usr/1112/703e/proxy-is-up ]; then
              echo "Proxy is UP"
              return 0
        else
           sleep 1
        fi
     done
}

if [ "$DEVICE_TYPE" != "hybrid" ]; then
    wait_for_mpeos_main
fi

sleep 180

## Create the device details files as part of start up
if [ "$DEVICE_TYPE" != "mediaclient" ]; then

    localCache=$(/lib/rdk/getDeviceDetails.sh read)
    echo "ESTB_IP:$(echo $localCache | tr " " "\n" | grep estb_ip | cut -d'=' -f2)" > /tmp/device_address.txt
    echo "ESTB_MAC:$(echo $localCache | tr " " "\n" | grep estb_mac | cut -d'=' -f2)" >> /tmp/device_address.txt
    echo "ECM_IP:$(echo $localCache | tr " " "\n" | grep ecm_ip | cut -d'=' -f2)" >> /tmp/device_address.txt
    echo "ECM_MAC:$(echo $localCache | tr " " "\n" | grep ecm_mac | cut -d'=' -f2)" >> /tmp/device_address.txt
    echo "MocaMAC:$(echo $localCache | tr " " "\n" | grep moca_mac | cut -d'=' -f2)" >> /tmp/device_address.txt
    echo "MocaIP:$(echo $localCache | tr " " "\n" | grep moca_ip | cut -d'=' -f2)" >> /tmp/device_address.txt

    # Updates for improving Inband-tuner table page performance
    echo "update" | sh /var/www/htmldiag/cgi-bin/inbandTuner.sh &

fi

# Code to fetch cert and dsg info for HTML diag
# Call this only after IP acquisition to generate dsg info with all values
if [ "$DEVICE_TYPE" == "hybrid" ]; then
     /usr/bin/rmfapicaller vlDsgDumpDsgStats
     /usr/bin/rmfapicaller vlMpeosDumpCertInfo
elif [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ -f /mnt/nfs/bin/vlapicaller ]; then
            /mnt/nfs/bin/vlapicaller vlDsgDumpDsgStats
            /mnt/nfs/bin/vlapicaller vlMpeosDumpCertInfo
     fi
fi
echo "update" | sh /var/www/htmldiag2/cgi-bin/cardData.sh
