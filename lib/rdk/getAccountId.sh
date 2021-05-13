#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2017 RDK Management, LLC. All rights reserved.
# ============================================================================
. /etc/include.properties
. /etc/device.properties

KEY_LEN="32"

ACCOUNT_ID_LOG="$LOG_PATH/servicenumber.log"
ACCOUNT_ID_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AccountInfo.AccountID'

getAccountId()
{
    accountId=`/usr/bin/tr181 -g $ACCOUNT_ID_TR181_NAME 2>&1 > /dev/null`
    accountIdLen=${#accountId}
        
    if [ "$accountId" != "" ] ; then
        if [ "$accountIdLen" -lt "$KEY_LEN" ] && [[ "$accountId"  =~ ^[a-zA-Z0-9_-]+$ ]] && [[ "$accountId" != "*['!'@'#'"$"%^&*()+]*" ]];  then
            echo "`/bin/timestamp`: accountId is valid and value retrieved from tr181 param." >> $ACCOUNT_ID_LOG
            echo "$accountId"
        else
            echo "`/bin/timestamp`: accountId is invalid as contains special characters or larger than max $KEY_LEN characters." >> $ACCOUNT_ID_LOG
            echo "Unknown"
        fi

    else
        echo "`/bin/timestamp`: accountId is empty from $ACCOUNT_ID_TR181_NAME param, sending accountid as Unknown" >> $ACCOUNT_ID_LOG
        echo "Unknown"
    fi
}
