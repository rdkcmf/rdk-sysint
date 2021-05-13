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

check_empty()
{
    value=$1
    if [ -z "$1" ]; then
        value=0 #set as 0 to avoid expr syntax error
    fi
    return $value
}

flash_fail_count=`[ -r /tmp/flash_mount_failure_count ] && cat /tmp/flash_mount_failure_count`
check_empty $flash_fail_count
flash_fail_count=$?
count=`[ -r /opt/flash_mount_failure_count ] && cat /opt/flash_mount_failure_count`
check_empty $count
count=$?
count=`expr $count + $flash_fail_count`
echo $count > /opt/flash_mount_failure_count

disk_fail_count=`[ -r /tmp/disk_mount_failure_count ] && cat /tmp/disk_mount_failure_count`
check_empty $disk_fail_count
disk_fail_count=$?
count=`[ -r /opt/disk_mount_failure_count ] && cat /opt/disk_mount_failure_count`
check_empty $count
count=$?
count=`expr $count + $disk_fail_count`
echo $count > /opt/disk_mount_failure_count

if [ -f /tmp/flash_mount_failure_count ]; then
        rm /tmp/flash_mount_failure_count
fi

if [ -f /tmp/disk_mount_failure_count ]; then
        rm /tmp/disk_mount_failure_count
fi
