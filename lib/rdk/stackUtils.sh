#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

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
