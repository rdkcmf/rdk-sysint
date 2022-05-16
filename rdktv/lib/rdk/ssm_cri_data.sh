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

SSM_LOG="/opt/logs/ssmdataparser.log"
CRI_LOG="/opt/logs/cridataparser.log"
THIS_SCRIPT=$(basename "$0")

log()
{
    echo "$(date '+%Y %b %d %H:%M:%S.%6N') [$THIS_SCRIPT#$$]: $*"
}
touch $SSM_LOG
touch $CRI_LOG

getSSMdata()
{
    if [ -f "/opt/panel/ssm_data" ]; then
        log "/usr/bin/ssmdataparser" > $SSM_LOG
        /usr/bin/ssmdataparser >> $SSM_LOG
    else
        #/opt/panel/ssm_data not exists.Gracefully returning zero
        return 0
    fi
}

getCRIdata()
{
    if [ -f "/opt/panel/cri_data" ]; then
        log "/usr/bin/cridataparser" > $CRI_LOG
        /usr/bin/cridataparser >> $CRI_LOG
    else
        #/opt/panel/cri_data not exists.Return zero
        return 0
    fi
}
getSSMdata
getCRIdata
