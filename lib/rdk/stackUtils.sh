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

logDiskInfo()
{
     # Current Disk Usage
     echo `/bin/timestamp` ========== DISK USAGE ======== >> $TEMP_LOG_PATH/ocapri_log.txt
     du -h /opt/data | /dump >> $TEMP_LOG_PATH/ocapri_log.txt
     echo `/bin/timestamp` ========== ====== ======== >> $TEMP_LOG_PATH/ocapri_log.txt
}

setTftpLogServer()
{
    if [ -f $PERSISTENT_PATH/logger.conf ] ; then
        tftpIP=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/logger.conf`
    else
	# Assign the default log server for dev build
        tftpIP=$1
    fi
    echo $tftpIP
}
 
uploadSTBLogs()
{
    if [ ! -f $PERSISTENT_PATH/.disableLog ] ; then
         nice $RDK_PATH/uploadSTBLogs.sh $1 $2&
    fi
}

setMpeenvPath()
{
    if [ -f /mnt/nfs/env/mpeenv.ini ]; then
         mpeenvPath=/mnt/nfs/env/mpeenv.ini
    fi
    if [ -f $PERSISTENT_PATH/mpeenv.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
        mpeenvPath=$PERSISTENT_PATH/mpeenv.ini
    fi
    echo $mpeenvPath
}

setdbgenvPath()
{
    if [ -f /etc/debug.ini ]; then
         dbgenvPath=/etc/debug.ini
    fi
    if [ -f $PERSISTENT_PATH/debug.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
        dbgenvPath=$PERSISTENT_PATH/debug.ini
    fi
    echo $dbgenvPath
}
