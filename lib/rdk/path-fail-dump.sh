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

LOG_FILE="/opt/logs/path_fail.log"

lsof_output=$(lsof)
ps_output=$(ps -ef)

echo "`date` Path failure notifier triggered for $1" >> $LOG_FILE

echo "$lsof_output" >> $LOG_FILE
echo "$ps_output" >> $LOG_FILE

echo "Max inotify instances `cat /proc/sys/fs/inotify/max_user_instances`" >> $LOG_FILE
cur_count=`echo "$lsof_output" | grep inotify | wc -l`
echo "current open inotify instances $cur_count" >> $LOG_FILE

sleep 5
systemctl restart $1
