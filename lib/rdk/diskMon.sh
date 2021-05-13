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

#conf filename. The file will have the path and size limit(in MB) seperated by a tab
CONF_FILE=/etc/diskMon.conf 

if [ -f /tmp/.standby ]; then
      LOG=$TEMP_LOG_PATH/diskMon.log
else
      LOG=$LOG_PATH/diskMon.log
fi

echo "$(date +"%Y-%m-%d %T") Checking Disk size.." >> $LOG

sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' $CONF_FILE | while read dir limit
do
	# if directory exists, find out it's size
	if [ -d $dir ]
	then
		size=$(du -sm $dir | cut -f1)
	else
		echo "path $dir not found!!!" >> $LOG
		continue
	fi

	#check if directory size is greater than limit
	if [ $size -ge $limit ]
	then
		echo "$dir is OVER the limit. size = $size limit = $limit"  >> $LOG
	else
		echo "$dir is within the limit size = $size limit = $limit" >> $LOG
	fi
        sleep 1
done
echo "" >> $LOG
