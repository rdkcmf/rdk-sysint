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
. /etc/device.properties



eMMCMitigationDisabled=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.eMMCMitigation.Disable 2>&1 > /dev/null`
echo "eMMCMitigationDisabled:$eMMCMitigationDisabled" >> /opt/logs/emmc_debug.log
if [ "$eMMCMitigationDisabled" == "true" ]; then
      echo "eMMCMitigation is disabled.. Exiting" >> /opt/logs/emmc_debug.log
      exit 0
fi
echo "eMMCMitigation is enabled " >> /opt/logs/emmc_debug.log

COUNTER=/tmp/emmc-mit-counter
if [ ! -f $COUNTER ]; then
    touch $COUNTER
    echo 0 > $COUNTER
fi

TMP_FBCLOG=/tmp/fbc-log
TMP_FBCVAL=/tmp/fbc-val

TMP_MITFILE=/tmp/.mit_start

MAX=4
count=`cat $COUNTER`

conv_val()
{
    val=$1
    j=7
    k=8
    regval=""
    for ((i=0 ; i < 8; i++)); do
        byte=`echo $val | cut -b $j-$k`
        regval="$regval$byte"
        i=`expr $i + 1`
        j=`expr $j - 2`
        k=`expr $k - 2`   
    done 
}

report=`tr181 Device.Services.STBService.1.Components.X_RDKCENTRAL-COM_eMMCFlash.DeviceReport 2>&1 > /dev/null`
echo "$report" > $TMP_FBCLOG
if [ "$report" != "" ]; then

   # [195:192] Free Block Count
   ext=`dd skip=193 count=4 if=$TMP_FBCLOG of=$TMP_FBCVAL bs=2 2>&1 > /dev/null`
   Freemem=`cat $TMP_FBCVAL`
   conv_val "$Freemem"
   Freecount=$((0x$regval))
   if [ $Freecount -lt 2 ]; then
       # Start mitigation plan
       if [ ! -f $TMP_MITFILE ]; then
            touch $TMP_MITFILE
       fi
       echo "[`date`]: eMMC Mitigation plan started(FBC=$Freecount) " >> /opt/logs/eMMC_diag.log
       size=4
       if [ "x$1" != "x" ];then
           size=$1
       fi
       size_extn=M
       #Check whether data dump log is not desabled
       if [ ! -f /opt/.disable_data_dump ]; then
            echo "$size$size_extn"
            #Dump dummy data(4MB) to persistent location
            dd if=/dev/zero of=/opt/persistent/random.txt bs=$size$size_extn count=1
            sync
            echo "[`date`]: Created a debug File in Extended Partition /opt/persistent: `ls -lh /opt/persistent/random.txt`" >> /opt/logs/emmc_debug.log
            sleep 2
            #Remove persistent dumped data
            echo "[`date`]: Deleting /opt/persistent/random.txt" >> /opt/logs/emmc_debug.log
            rm -f /opt/persistent/random.txt
            sync
      fi
   else
      rm -rf $TMP_MITFILE
   fi
      count=`expr $count + 1`
      echo $count > $COUNTER
else
     # Report is NULL
     count=`expr $count + 1`
     echo $count > $COUNTER
fi

if [ $count -eq $MAX ]; then
     if [ -f $TMP_MITFILE ]; then
         echo "[`date`]: WARNING: eMMC is in CRITICAL Condition" >> /opt/logs/eMMC_diag.log
     fi
# Reset the counter
    count=0
    echo $count > $COUNTER
fi
