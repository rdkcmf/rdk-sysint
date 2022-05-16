#!/bin/sh
#
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

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

# input arguments
PROTO=$1
CLOUD_LOCATION=$2
DOWNLOAD_LOCATION=$3
UPGRADE_FILE=$4
REBOOT_FLAG=$5
PDRI_UPGRADE=$6

if [ ! $PROTO ];then echo "Missing the upgrade proto..!"; exit -2;fi
if [ ! $CLOUD_LOCATION ];then echo "Missing the cloud image location..!"; exit -2;fi
if [ ! $DOWNLOAD_LOCATION ];then echo "Missing the local download image location..!"; exit -2;fi
if [ ! $UPGRADE_FILE ];then echo "Missing the image file..!"; exit -2;fi
if [ ! $REBOOT_FLAG ] && [  "$DEVICE_TYPE" != "mediaclient" ];then echo "Missing the reboot flag..!"; exit -2;fi

ret=1

if [ "$DEVICE_TYPE" == "mediaclient" ]; then
    if [ -f /usr/bin/FlashApp ];then
        # Flashing the image
        echo "/usr/bin/FlashApp $DOWNLOAD_LOCATION $UPGRADE_FILE"
        /usr/bin/FlashApp $DOWNLOAD_LOCATION $UPGRADE_FILE
        ret=$?
    else
        echo "FlashApp Utility is missing"
        ret=1
    fi
    exit $ret
fi
