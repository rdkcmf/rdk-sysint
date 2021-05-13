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
. /etc/env_setup.sh

log=$1
pipe=$2

if [ -f /etc/os-release ]; then 
    exit 0
fi

LOG_FILE="$LOG_PATH/$log"                                                            
if [ "$LIGHTSLEEP_ENABLE" = "true" ]; then                                                   
     LOG_PIPE="$TEMP_LOG_PATH/$pipe"                                             
     stat=`find $TEMP_LOG_PATH -name $pipe -type f`                              
     if [ "$stat" ]; then                                                            
           cat $LOG_PIPE >> $LOG_FILE                                                         
           echo "$LOG_PIPE is not a pipe" >> $LOG_PATH/lightsleep.log                        
           rm -rf $LOG_PIPE                                                                
     fi           
     mkfifo $LOG_PIPE &> /dev/null                                                         
     # Checking the logging pipe before startup                                                       
     ret=`ps | grep $LOG_PIPE | grep -v grep`                                                                   
     if [ ! "$ret" ]; then                                                                                     
           cat $LOG_PIPE >> $LOG_FILE &       
     fi                                                                                                             
fi 
