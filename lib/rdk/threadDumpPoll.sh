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
. /etc/device.properties
. /etc/env_setup.sh

if [ "$HDD_ENABLED" != "true" ]; then 
     rm -f /opt/logs/jvmheapdump.txt
     ln -s /dev/null /opt/logs/jvmheapdump.txt
fi

if [ -f /mnt/nvram/persistent/usr/1112/703e/thread-dump-requested ]; then
     echo "Initial bootup cleanup"
     rm -rf /mnt/nvram/persistent/usr/1112/703e/thread-dump-requested
fi

while true
do
   if [ ! -f /tmp/.standby ] ; then
       if [ -f /opt/persistent/usr/1112/703e/thread-dump-requested ]; then
         echo "Sending HUP signal to mpeos process"
         if [ -e /opt/logs/jvmheapdump.txt ]; then
              mv /opt/logs/jvmheapdump.txt /opt/logs/jvmheapdump.bak
         else
              rm -f /opt/logs/jvmheapdump.bak
         fi
         ln -s /dev/null /opt/logs/jvmheapdump.txt
         ret=`ps | grep mpeos-main | grep -v | awk '{print $1}'`
         if [ "$ret" = "root" ];then
              kill -HUP `ps -ef | awk '/awk/{next}/mpeos-main/{print $2}'`
         else
              kill -HUP `ps -ef | awk '/awk/{next}/mpeos-main/{print $1}'`
         fi
         rm /opt/persistent/usr/1112/703e/thread-dump-requested
         sleep 20 #allow time for heap dump to write to symlink; also throttles max thread dump frequency to 2/minute
         rm /opt/logs/jvmheapdump.txt
         if [ -e /opt/logs/jvmheapdump.bak ]; then
              mv /opt/logs/jvmheapdump.bak /opt/logs/jvmheapdump.txt
         fi
       fi
   fi
   sleep 10
done
