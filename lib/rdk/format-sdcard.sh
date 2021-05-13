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

FILESYSTEM=$1

. /etc/device.properties

isSDCardMounted()
{
	# flag = 0 : unmounted, 1 : mounted, 2 : SDCard not found
	flag=0

        if [ -b $1 ] ; then
                SDCARD_MOUNT_VERIFICATION=`mount | grep "$1"`
                if [ "$SDCARD_MOUNT_VERIFICATION" != "" ] ; then
			flag=1
                fi
        else
                flag=2 
        fi

	return $flag
}


format_SDCard()
{
	if [ $1 == "FAT32" ] || [ $1 == "fat32" ] ; then
                echo "Performing FAT32 quick format of SD card"
                mkdosfs -F 32 $2
                echo "SDCard FAT32 quick format... done"
	elif [ $1 == "EXT4" ] || [ $1 == "ext4" ] ; then
                echo "Performing EXT4 format (without journal) of SD card"
                mkfs.ext4 -F -t ext4 -O ^has_journal $2
                echo "SDCard EXT4 format (without journal)... done"
	else
		echo "Error - Unknown Filesystem input for SDCard formatting : $1"
	fi
}

checkAndFormat()
{
    isSDCardMounted $1

    case $? in
	    0)
		    format_SDCard $FILESYSTEM $1
		    ;;
	    1)
		    echo " SDCard is mounted... unmounting & formatting"
                    umount $1
                    format_SDCard $FILESYSTEM $1
	            ;;
	    2)
		    echo "Error - SDCard NOT FOUND...Formatting discontinued"
		    ;;
    esac
}

if [ $# -eq 0 ] ; then
        echo "Error - No filesystem type specified for SDCard formatting"
        echo "Usage : $0 <filesystem-type>"
        exit 1
fi

if [ -b ${SD_CARD_TSB_PART} ]
then
    checkAndFormat ${SD_CARD_TSB_PART}
fi

if [ -b ${SD_CARD_APP_PART} ]
then
    checkAndFormat ${SD_CARD_APP_PART}
fi
