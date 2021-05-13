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

PREV_LOG_BACKUP="/opt/logs/PreviousLogs_backup/"
LOG_PATH="/opt/logs/PreviousLogs/"

#check if /opt is mounted to /mnt/memory
df -h | grep sda
if [[ $? -eq 0 ]] ; then
	echo "usb is mounted"
else
	BSIZE=`du -s $PREV_LOG_BACKUP | cut -f1`
	echo BSIZE : $BSIZE
	BFILES=$LOG_PATH"files"
	ls -rt1 $PREV_LOG_BACKUP/ > $BFILES
	echo "#############"
	echo BFILES : $BFILES
	cat $BFILES
	echo "#############"
	line_number=1
	total_lines=`cat $BFILES | wc -l`
	echo $total_lines
	while [ $BSIZE -gt 6000 -a $total_lines -ge $line_number ]
	do
		#Read the file name
		#awk NR==${line_number} $BFILES
		BFILE=`sed -n "${line_number}p" $BFILES`
		echo "BFILE : " $BFILE
		rm  $PREV_LOG_BACKUP"/"$BFILE
		BSIZE=`du -s $PREV_LOG_BACKUP | cut -f1`
		echo "BSIZE : " $BSIZE
		line_number=`expr $line_number + 1`
	done
fi
rm  $BFILES
