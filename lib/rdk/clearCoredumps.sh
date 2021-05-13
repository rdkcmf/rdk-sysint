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
. /etc/device.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

clearDumps()
{
   LOOP_COUNT=0
   loop=1
   while [ $loop -eq 1 ]
   do
	#folder size in BYTES
	COREFILES_SIZE=`du $DUMPS_DIR | awk '{print $1}'`
	COREFILES_SIZE=$(($COREFILES_SIZE * 1024))
	if [ $COREFILES_SIZE -ge $COREFILES_SIZE_THRESHOLD ]; then
      	OLDEST_FILE=`ls -t $DUMPS_DIR | tail -1`
		if [ -n $OLDEST_FILE ]; then
            OLDEST_FILE=$DUMPS_DIR/$OLDEST_FILE
		    if [ "$DEVICE_TYPE" = "hybrid" ] ; then
				if echo $OLDEST_FILE | grep -q rmfStreamer; then
 					if [ $OLDEST_FILE != `ls $DUMPS_DIR/*rmfStreamer* -tc1 | head -1` ]; then
			             echo "deleting "$OLDEST_FILE"..."
			             rm -rf $OLDEST_FILE
		            fi
                fi
             elif [ "$DEVICE_TYPE" != "mediaclient" ] ; then
       	          if echo $OLDEST_FILE | grep -q mpeos-main; then
		               if [ $OLDEST_FILE != `ls $DUMPS_DIR/*mpeos-main* -tc1 | head -1` ]; then
			                echo "deleting "$OLDEST_FILE"..."
			                rm -rf $OLDEST_FILE
		               fi
                  fi
             else
         	   echo "deleting "$OLDEST_FILE"..."
		       rm -rf $OLDEST_FILE
	         fi
	   fi
	   LOOP_COUNT=$(($LOOP_COUNT + 1))
	   if [ $LOOP_COUNT -ge $MAX_LOOPS ]; then
	         echo "exiting "$0",tried "$LOOP_COUNT" iterations.."
	         loop=0
       fi
	fi
	sleep 2
  done
}

COREFILES_BACK=$CORE_BACK_PATH
COREFILES=$CORE_PATH
if [ -z "$COREFILES_SIZE_THRESHOLD" ]; then
	#override the default value (1GB) by exporting this variable to the desired value
    if [ "$HDD_ENABLED" = "true" ]; then
	     export COREFILES_SIZE_THRESHOLD=1073741824 #1GB
    else
         export COREFILES_SIZE_THRESHOLD=1572864 #1.5MB
    fi
fi

MAX_LOOPS=10

#to limit this to only one instance at any time..
LOCK_FILE=/tmp/.clearCoredumps.lock

if [ -f $LOCK_FILE ]; then
	echo "An instance of "$0" is already running.."
else
	touch $LOCK_FILE
	for dir in $COREFILES_BACK $COREFILES
	do
		DUMPS_DIR=$dir
		clearDumps
		echo "Corefile size is below the threashold("$COREFILES_SIZE_THRESHOLD" bytes) in "$DUMPS_DIR" ..."
	done
	rm $LOCK_FILE
fi
