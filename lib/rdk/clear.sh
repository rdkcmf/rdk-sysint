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

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

COREFILES_BACK=$CORE_BACK_PATH
if [ -z "$COREFILES_SIZE_THRESHOLD" ]; then
    #override the default value (1GB) by exporting this variable to the desired value
    export COREFILES_SIZE_THRESHOLD=1073741824 #1GB
fi

MAX_LOOPS=10

#to limit this to only one instance at any time..
LOCK_FILE=/opt/.clearCoredumps.lock

if [ -f $LOCK_FILE ]; then
    echo "An instance of "$0"is already running.."
else
    touch $LOCK_FILE
    LOOP_COUNT=0
    while
        #folder size in BYTES
        COREFILES_SIZE=`du $COREFILES_BACK | awk '{print $1}'`
        COREFILES_SIZE=$(($COREFILES_SIZE * 1024))
        [ $COREFILES_SIZE -ge $COREFILES_SIZE_THRESHOLD ]
    do
        OLDEST_FILE=`ls -t $COREFILES_BACK | tail -1`
        OLDEST_FILE=$COREFILES_BACK/$OLDEST_FILE
        echo "deleting "$OLDEST_FILE"..."
        rm -rf $OLDEST_FILE
        LOOP_COUNT=$(($LOOP_COUNT + 1))
        if [ $LOOP_COUNT -ge $MAX_LOOPS ]; then
            echo "exiting "$0",tried "$LOOP_COUNT" iterations.."
            break
        fi
        sleep 2
    done
    echo "Corefile size is below the threashold("$COREFILES_SIZE_THRESHOLD" bytes)..."
    rm $LOCK_FILE
fi
