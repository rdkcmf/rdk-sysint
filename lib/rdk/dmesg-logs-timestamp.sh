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

if [ ! -f /etc/os-release ];then
    # exit if an instance is already running
    if [ ! -f /tmp/.dmesg-logger.pid ];then
        # store the PID
        echo $$ > /tmp/.dmesg-logger.pid
    else
        pid=`cat /tmp/.dmesg-logger.pid`
        if [ -d /proc/$pid ];then
            exit 0
        fi
    fi
fi

if [ "$LIGHTSLEEP_ENABLE" = "true" ];then
     if [ -f /tmp/.power_on ];then
          date >> /opt/logs/messages-dmesg.txt
     fi
else
     date >> /opt/logs/messages-dmesg.txt
fi

# PID file cleanup
if [ ! -f /etc/os-release ] && [ -f /tmp/.dmesg-logger.pid ];then
    rm -rf /tmp/.dmesg-logger.pid
fi

exit 0

