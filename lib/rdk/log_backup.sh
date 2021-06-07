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
