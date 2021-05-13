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
##############################################################################
## Script to recover the wpa_supplicant.conf file if it is corrupted.
##
## NOTE - This script is available only for eMMC devices now
##############################################################################

file_corrupted=0
count=0
wpa_file="/opt/wifi/wpa_supplicant.conf"
secure_wpa_file="/opt/secure/wifi/wpa_supplicant.conf"
log_file="/opt/logs/mount_log.txt"

#check whether the file is corrupted or not
check_wpa_supplicant_conf()
{
    /bin/ls $wpa_file 2>&1 | grep -q "Input\/output error"
    returnVal=$?
    if [ "$returnVal" -eq 0 ]; then
        file_corrupted=1
    fi
}

while [ "$count" -lt 4 ];do

    check_wpa_supplicant_conf

    if [[ "$file_corrupted" -eq 1 ]];then
        echo "$(/bin/timestamp) The file $wpa_file is corrupted. Repairing it" >> $log_file
        partition=`/usr/bin/awk '$2 ~ "/mnt/crit" { print $1 }' /proc/mounts`
        if [ -f /sbin/debugfs ];then
            /sbin/debugfs -w -R 'sif wifi/wpa_supplicant.conf links_count 1' $partition
            returnVal=$?
            if [ "$returnVal" -eq 0 ];then
                echo "$(/bin/timestamp) Recovered the corrupted file $wpa_file" >> $log_file
                if [ -f $secure_wpa_file ];then
                    echo "$(/bin/timestamp) Copying $secure_wpa_file to $wpa_file" >> $log_file
                    cp -f $secure_wpa_file $wpa_file
                fi
                /bin/systemctl is-active wpa_supplicant_conf_backup.path
                retVal=$?
                if [ "$retVal" -ne 0 ];then
                    echo "$(/bin/timestamp) Restarting wpa_supplicant_conf_backup.path" >> $log_file
                    /bin/systemctl restart wpa_supplicant_conf_backup.path
                fi
                exit 0
            else
                echo "$(/bin/timestamp) Unable to recover the corrupted file $wpa_file" >> $log_file
                exit 1
            fi
        else
            echo "$(/bin/timestamp) debugfs utility is not present. Cannot recover the corrupted file $wpa_file" >> $log_file
            exit 0
        fi
    else
        echo "$(/bin/timestamp) $wpa_file is fine. No need to recover" >> $log_file
    fi
    sleep 5
    count=$(( count + 1 ))
done
