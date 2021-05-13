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

count=0
loop=0
while [ $loop -eq 0 ]
do
   if [ -f /tmp/snmpd.conf ];then
        snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
        if [ "$snmpCommunityVal" ]; then 
               echo "$snmpCommunityVal"
               exit 0
        fi
    else
        count=`expr $count + 1`
        sleep 5
    fi
    if [ $count -eq 24 ]; then
         loop=1
    fi
done

echo ""
exit 0
