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

if [ ! "$LOG_PATH" ];then LOG_PATH="/opt/logs"; fi
# create log workspace if not there
if [ ! -d "$LOG_PATH" ];then 
     rm -rf $LOG_PATH
     mkdir -p "$LOG_PATH"
fi
# create intermediate log workspace if not there
if [ ! -d $LOG_PATH/PreviousLogs ];then
     rm -rf $LOG_PATH/PreviousLogs
     mkdir -p $LOG_PATH/PreviousLogs
fi
# create log backup workspace if not there
if [ ! -d $LOG_PATH/PreviousLogs_backup ];then
     rm  -rf $LOG_PATH/PreviousLogs_backup
     mkdir -p $LOG_PATH/PreviousLogs_backup
else
     rm  -rf $LOG_PATH/PreviousLogs_backup/*
fi

if [ $APP_PERSISTENT_PATH ];then 
     PERSISTENT_PATH=$APP_PERSISTENT_PATH
else
    PERSISTENT_PATH=/opt/persistent
fi
touch $PERSISTENT_PATH/logFileBackup

PREV_LOG_PATH="$LOG_PATH/PreviousLogs"

# disk size check for recovery if /opt size > 90%
if [ -f /etc/os-release ] && [ -f /lib/rdk/disk_threshold_check.sh ];then
     sh /lib/rdk/disk_threshold_check.sh 0
fi

backupAndRecoverLogs()
{
    source=$1
    destn=$2
    operation=$3
    s_extn=$4
    d_extn=$5

    for file in $(find $source -mindepth 1 -maxdepth 1 -type f -name "$s_extn*");
    do
        $operation "$file" "$destn$d_extn${file/$source$s_extn/}"
    done
}

last_bootfile=`find /opt/logs/PreviousLogs/ -name last_reboot`
if [ -f "$last_bootfile" ];then
     rm -rf $last_bootfile
fi

sysLog="messages.txt"
sysLogBAK1="bak1_messages.txt"
sysLogBAK2="bak2_messages.txt"
sysLogBAK3="bak3_messages.txt"

if [ "$HDD_ENABLED" = "false" ]; then
	BAK1="bak1_"
	BAK2="bak2_"
	BAK3="bak3_"
    if [ ! `ls $PREV_LOG_PATH/$sysLog` ]; then
        find $LOG_PATH -maxdepth 1 -mindepth 1 -type f \( -iname "*.txt*" -o -iname "*.log*" -o -name "bootlog" \) -exec mv '{}' $PREV_LOG_PATH \;
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK1` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK1
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK2` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK2
    elif [ ! `ls $PREV_LOG_PATH/$sysLogBAK3` ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK3
    else
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK1" ""
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK2" "$BAK1"
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK3" "$BAK2"
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" "$BAK3"
    fi
    if [ -f /etc/os-release ];then
           /bin/touch /opt/logs/PreviousLogs/last_reboot
    else
           touch /opt/logs/PreviousLogs/last_reboot
    fi
    # logs cleanup after backup
    rm -rf $LOG_PATH/*.*
    find $LOG_PATH -name "*-*-*-*-*M-" -exec rm -rf {} \;
else
    if [ ! `ls $PREV_LOG_PATH/$sysLog` ]; then
       find $LOG_PATH -maxdepth 1 -mindepth 1 -type f \( -iname "*.txt*" -o -iname "*.log*" -o -name "bootlog" \) -exec mv '{}' $PREV_LOG_PATH \;
       if [ -f /etc/os-release ];then
           /bin/touch /opt/logs/PreviousLogs/last_reboot
       else
           touch /opt/logs/PreviousLogs/last_reboot
       fi
    else
       find /opt/logs/PreviousLogs/ -name last_reboot | xargs rm >/dev/null
       timestamp=`date "+%m-%d-%y-%I-%M-%S%p"`
       LogFilePathPerm="$LOG_PATH/PreviousLogs/logbackup-$timestamp"
       mkdir -p $LogFilePathPerm

       find $LOG_PATH -maxdepth 1 -mindepth 1 -type f \( -iname "*.txt*" -o -iname "*.log*" -o -name "bootlog" \)  -exec mv '{}' $LogFilePathPerm \;
       if [ -f /etc/os-release ];then
            /bin/touch "$LogFilePathPerm"/last_reboot 
       else
            touch $LogFilePathPerm/last_reboot
       fi
   fi
fi
if [ -f /tmp/disk_cleanup.log ];then
        mv /tmp/disk_cleanup.log /opt/logs/
fi
if [ -f /tmp/mount_log.txt ];then
        mv /tmp/mount_log.txt /opt/logs/
fi

cp /version.txt $LOG_PATH

if [ -f /etc/os-release ];then
    /bin/systemd-notify --ready --status="Logs Backup Done..!"
fi

