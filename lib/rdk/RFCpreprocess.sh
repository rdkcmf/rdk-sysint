#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2018 RDK Management, LLC. All rights reserved.
# ============================================================================
#
##################################################################
## Script to execute before RFC settings with current boot and after RFC mounts
## Author:
##################################################################
. /etc/include.properties
. /etc/device.properties

if [ -z $LOG_PATH ]; then
    if [ "$DEVICE_TYPE" = "broadband" ]; then
        LOG_PATH="/rdklogs/logs"
    else
        LOG_PATH="/opt/logs"
    fi
fi

if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi

echo "[RFC]:: PREPROCESSING IS RUN NOW !!!" >> $LOG_PATH/rfcscript.log

