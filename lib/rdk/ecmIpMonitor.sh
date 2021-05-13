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


. /etc/include.properties
. $RDK_PATH/utils.sh
. $RDK_PATH/commonUtils.sh

if [ -f $RAMDISK_PATH/.ecmIpFlag ] ; then
      rebootCount=`cat $RAMDISK_PATH/.ecmIpFlag`
      echo $((rebootCount+1)) > $RAMDISK_PATH/.ecmIpFlag
else
      echo 1 > $RAMDISK_PATH/.ecmIpFlag
fi

count=`cat $RAMDISK_PATH/.ecmIpFlag`

if [ $count -gt 3 ]; then
     rm -rf $RAMDISK_PATH/.ecmIpFlag
     echo "Rebooted the box 3 times for ECM IP "
     echo "Issue with ECM IP address"
     echo 10 > /opt/.reboot
     exit
else
     sleep 1800
     ret=`grep -irn "dhcp" $LOG_PATH/messages-puma.txt* | grep -irn "Set to the wan0 addr:" | wc -l`
     ret1=`grep -irn "Configuring IP stack 1:  IP Address = " $LOG_PATH/messages-ecm.txt* | wc -l`
     if [ $ret -eq 0 ] && [ $ret1 -eq 0 ]; then
          /rebootNow.sh -s "`basename $0`" -o "Rebooting the box due to not having ECM IP..."
     fi
fi

