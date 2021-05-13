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

. /etc/device.properties

if [ "$DEVICE_TYPE" != "hybrid" ]; then
     proxyPath=`cat /mnt/nfs/env/final.properties | grep OCAP.persistent.root | cut -d "=" -f2`
     echo --------- proxy path= $proxyPath
     #rm $proxyPath/usr/1112/703e/proxy-is-up
     #rm /tmp/stt_received

     while [ 1 ]
     do
        if [ -f $proxyPath/usr/1112/703e/proxy-is-up ] && [ -f /tmp/stt_received ] ; then
	          echo "STT received and Proxy is UP"
	          touch /tmp/.xre-startup
              exit 0
        else
           sleep 1
        fi
     done
else
     touch /tmp/.xre-startup
fi

