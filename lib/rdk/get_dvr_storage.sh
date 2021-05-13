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
##
# Utility script to report the storage size in bytes
##

. /etc/device.properties

export PATH=$PATH:/sbin

# Storage device default value
storageDevice="/dev/sda"
storageSize=0

convertMBtoKB() {
    mbValue=$1
    kbValue=$(($mbValue * 1024))
    echo $kbValue
}

convertBytesToKB() {
    byteValue=$1
    kbValue=$(($byteValue / 1024))
    echo $kbValue
}

reserveSpaceInBytes=`grep -i 'FEATURE.DVR.TSB.RESERVEDSPACE' /etc/rmfconfig.ini | grep -v ^[[:space:]]*# | cut -d '=' -f2 | tr -d ' '`
reserveSpaceInKB=0
if [ "$reserveSpaceInBytes" ]; then
    reserveSpaceInKB=$(convertBytesToKB $reserveSpaceInBytes)
fi

if $HDD_ENABLED ; then
   # Add logic if HDD device on different paltforms are different
   valueInMB=`hdparm -I $storageDevice | grep GB | awk '{print $7}'`
   if [ $valueInMB -eq 500107 ]; then # As per AC in RDK-13802
        # For current 500 GB HDD device below KB value needs to be hardcoded 
        echo 416912543
        exit 0
   else
        storageSize=$(convertMBtoKB $valueInMB)
   fi

else
    # Check for SD-Card storage
    isSDCardSupported=`grep -i 'PLATFORM.STORAGE.SD_CARD.SUPPORT' /etc/rmfconfig.ini \
          | cut -d '=' -f2 | tr '[A-Z]' '[a-z]'`

    if $isSDCardSupported ; then 
       sdCardMountLocation=`mount | grep 'mmcblk' | tail -1 | tr -s ' ' | cut -d ' ' -f3`
       if [ -n "$sdCardMountLocation" ] && [ -d $sdCardMountLocation ] ; then
           storageSize=`df -k $sdCardMountLocation | grep -v 'Filesystem' | tr -s ' ' | \
                 cut -d ' ' -f2`
       else
           echo 0
           exit 0
       fi
    fi
fi

if [ $storageSize -gt $reserveSpaceInKB ]; then
    storageSize=$(($storageSize - $reserveSpaceInKB))
else
    storageSize=0
fi

echo $storageSize
