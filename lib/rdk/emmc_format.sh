#!/bin/sh

mountpoints=$(mount | grep mmc | cut -d " " -f1 | sort | uniq)

for mountpoint in $mountpoints
do
    partition_name=`echo $mountpoint | cut -d "/" -f3`
    declare filesystem_$partition_name=`mount | grep $mountpoint | cut -d " " -f5`
done


unmount()
{
     mount | grep $1
     if [ $? -eq 0 ]; then
          fuser -mk $1
          umount $1
     fi
     
}

unmount /tmp/data
unmount /opt/secure
unmount /var/lib
unmount /opt/persistent
unmount /opt/www
unmount /opt/drm
unmount /opt/wifi
unmount /opt/gp
unmount /opt/CDL
unmount /opt/oem
unmount /var/lib
unmount /opt
unmount /mnt/crit_nvs
unmount /mnt/critical
unmount /var/volatile/log
unmount /media/apps

for mountpoint in $mountpoints
do
    echo "Formatting $mountpoint"
    partition_name=`echo $mountpoint | cut -d "/" -f3`
    partition_type=filesystem_$partition_name
    formatoption=""
    if [ "${!partition_type}" == "ext4" ]; then
        formatoption="-F -O^has_journal"
    elif [ "${!partition_type}" == "btrfs" ]; then
        formatoption="-f"
    fi
    mkfs.${!partition_type} $formatoption $mountpoint
    if [ $? -ne 0 ]; then
        echo "$mountpoint formatting failed with $?"
    else
        echo "$mountpoint formatting successful"
    fi

done
