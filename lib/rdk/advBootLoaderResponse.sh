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

LOG_FILE="$LOG_PATH/ABLReason.txt"
RESPONSE=`cat /proc/cmdline | tr -s " " | expand | tr -s " " | awk  '{n=split($0,a," "); for (i=1; i<=n; i++) print a[i]}' | grep LAST_ABL | cut -d "="  -f2`
if [ $? -ne 0 ] 
then
  echo `/bin/timestamp` LAST_ABL parameter is not found in /proc/cmdline >> $LOG_FILE
else
  case $RESPONSE in
    0)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_NEVER  We have never been in the ABL >> $LOG_FILE 
	 ;;
    1)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_BADDB  The database was corrupt >> $LOG_FILE
	 ;;
    2)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_REVERTED We reverted but there was no good image - strike out  >> $LOG_FILE
	 ;;
    3)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_NOIMAGE Both banks were scrubbed \(cold init etc.. \) >> $LOG_FILE
	 ;;
    4)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_MANUAL  The ABL was launched by holding the buttons >> $LOG_FILE
	 ;;
    5)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_BOOTINFO We did not know what to do so we ran the ABL \(Debug redboot would run CLI\) >> $LOG_FILE
	 ;;
    6)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE ABL_RESPONSE_SCRIPT  We could not create a viable boot script \(Debug redboot would run CLI\) >> $LOG_FILE
	 ;;
    *)   echo `/bin/timestamp` ABL_RESPONSE_CODE=$RESPONSE UNKNOWN RESPONSE >> $LOG_FILE
	 ;;
  esac
fi
