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
