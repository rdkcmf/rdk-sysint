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
   
# persistent data cleanup
if [ -d /opt/persistent ]; then
       rm -rf /opt/persistent/*
fi
if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "PERSISTENT_jffs2"
     fi
     sleep 1
fi
# opt data cleanup
if [ -d /opt/logs ]; then
     rm -rf /opt/logs/*
fi
if [ -d /var/logs ]; then
     rm -rf /var/logs/*
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "OPT_jffs2"
     fi
     sleep 1
fi

exit 0
