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

# override DIFW path if RFC desires downloads to sd card
SDCARD_SCRATCHPAD_ENABLE=`/usr/bin/tr181Set -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SDCARD_SCRATCHPAD.Enable 2>&1 > /dev/null`

if [ "x$SDCARD_SCRATCHPAD_ENABLE" == "xtrue" ]; then
    # make sure that we have a rw filesystem mounted on 
    # cdl mount path
    tst_file=$SD_CARD_APP_MOUNT_PATH/testfile
    touch $tst_file
    if [ -e $tst_file ]; then
        echo "secondary storage scratchpad will be used for firmware download"
        DIFW_PATH=$SD_CARD_APP_MOUNT_PATH
        rm $tst_file
    fi
fi

