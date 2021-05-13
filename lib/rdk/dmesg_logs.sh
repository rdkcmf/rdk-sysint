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

. /etc/include.properties
. /etc/device.properties

# Save boot log
dmesg > /opt/logs/startup_stdout_log.txt

# Start syslog server
syslogd -O /opt/logs/messages.txt

# Send dmesg to syslog (per Comcast BPV-53) 
klogd

while [ 1 ]; do
   if [ "$LIGHTSLEEP_ENABLE" = "true" ];then
         if [ -f /tmp/.power_on ];then
              dmesg -c >> /opt/logs/messages-dmesg.txt
         fi
   else
         dmesg -c >> /opt/logs/messages-dmesg.txt
   fi
   sleep 5
done

