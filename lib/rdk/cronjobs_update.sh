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

. /etc/include.properties

log_file="$LOG_PATH/cronjobs_update.log"
help_strings()
{
    echo "ERROR: Argument mismatch" >> $log_file
    echo "Usage1: cronjobs_update.sh <add/update> <script-name> <new-entry>" >> $log_file
    echo "Usage2: cronjobs_update.sh <remove/check-entry> <script-name>" >> $log_file
}

#No argument check
if [ $# -eq 0 ]; then
    help_strings
    exit 1
fi
#remove/check-entry operation check
if [ $# -ne 2 ] && [ "$1" = "remove" -o "$1" = "check-entry" ]; then
    help_strings
    exit 1
fi
#add/update operation check
if [ $# -ne 3 ] && [ "$1" = "add" -o "$1" = "update" ]; then
    help_strings
    exit 1
fi

LOCK="/tmp/.cronjob.LCK"
exec 8>$LOCK
flock -x 8

remove()
{
    sed -i "/[A-Za-z0-9]*$1[A-Za-z0-9]*/d" $current_cron_file
}

add()
{
    echo "$1" >> $current_cron_file
}

check_entry()
{
    output=`grep -c "$1" $current_cron_file`
    echo "output=$output" >> $log_file
    echo $output
}


#main app
current_cron_file="/tmp/cron_list"
crontab -l -c /var/spool/cron/ > $current_cron_file

echo "`date`:Arguments - 1st:$1, 2nd:$2, 3rd:$3" >> $log_file
if [ "$1" = "remove" ]; then
    echo "REMOVE" >> $log_file
    remove "$2"
fi

if [ "$1" = "add" ]; then
    echo "ADD" >> $log_file
    add "$3"
fi

if [ "$1" = "update" ]; then
    echo "UPDATE" >> $log_file
    remove "$2"
    add "$3"
fi

if [ "$1" = "check-entry" ]; then
    echo "ENTRY_CHECK" >> $log_file
    check_entry "$2"
fi


# update the new cron entries to root cron
crontab $current_cron_file -c /var/spool/cron/

rm -rf /tmp/.cronjob.LCK
echo "Exiting cronjobs_update.sh" >> $log_file
exit 0
